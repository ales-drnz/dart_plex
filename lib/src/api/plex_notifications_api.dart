// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_error_type.dart';
import '../plex_events.dart';
import '../plex_exception.dart';
import '../transport/plex_cancel_token.dart';

/// `/:/websockets/notifications` and `/:/eventsource/notifications`
/// — server-push notifications.
///
/// Plex exposes the same notification stream over two transports.
/// Use [connectWebSocket] for full-duplex (no extra polling
/// overhead) or [connectEventSource] when WebSockets are blocked by
/// an intermediate proxy.
///
/// The notification frames carry server state changes: playback
/// progress, library scan progress, transcoder sessions, settings
/// updates, etc. Each frame is exposed as a [PlexNotification] with a
/// `type` discriminator; [PlexNotification.events] and the
/// [PlexNotificationEvents.events] stream extension decode them into
/// typed [PlexEvent]s.
class PlexNotificationsApi {
  final PlexConnection _http;

  WebSocketChannel? _wsChannel;
  StreamController<PlexNotification>? _wsController;
  StreamSubscription<Object?>? _wsSub;

  StreamController<PlexNotification>? _sseController;
  StreamSubscription<String>? _sseSub;

  /// Cancels the EventSource request, including while it is still
  /// waiting for the response headers.
  PlexCancelToken? _sseCancel;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.notifications].
  PlexNotificationsApi(this._http);

  /// True while a WebSocket is open.
  bool get isWebSocketConnected => _wsChannel != null;

  /// True while an EventSource (SSE) stream is open.
  bool get isEventSourceConnected => _sseController != null;

  /// `GET /:/websockets/notifications` — open a WebSocket and emit
  /// every notification as a [PlexNotification].
  ///
  /// Awaits the socket handshake before returning, so the returned stream is
  /// live and [isWebSocketConnected] is only `true` once the connection is
  /// actually open. Throws a [PlexException] of type
  /// [PlexErrorType.connection] if the connection cannot be established.
  ///
  /// [filter] (optional) restricts to one notification type (e.g.
  /// `'playing'`, `'progress'`, `'activity'`, `'transcodeSession.update'`).
  Future<Stream<PlexNotification>> connectWebSocket({String? filter}) async {
    if (_wsChannel != null) {
      throw const PlexException(
        'WebSocket already connected. Call closeWebSocket() first.',
        type: PlexErrorType.state,
      );
    }
    _http.requireConnected();
    final base = _http.baseUrl;
    final token = _http.token;
    if (token == null) {
      throw const PlexException(
        'No PMS token. Call connect() / setToken() first.',
        type: PlexErrorType.state,
      );
    }
    final qp = <String, String>{'X-Plex-Token': token};
    if (filter != null) qp['filter'] = filter;
    final query = qp.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final wsUrl = _toWs('$base/:/websockets/notifications?$query');

    final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await channel.ready;
    } catch (e, st) {
      throw PlexException(
        'WebSocket connection failed: $e',
        type: PlexErrorType.connection,
        cause: e,
        stackTrace: st,
      );
    }
    final controller = StreamController<PlexNotification>.broadcast(
      onCancel: () {
        if (!(_wsController?.hasListener ?? false)) {
          unawaited(closeWebSocket());
        }
      },
    );
    _wsChannel = channel;
    _wsController = controller;
    _wsSub = channel.stream.listen(
      (message) {
        if (message is String) {
          final notif = _decode(message);
          if (notif != null) controller.add(notif);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        controller.addError(
          PlexException(
            'WebSocket error: $error',
            type: PlexErrorType.connection,
          ),
          stackTrace,
        );
      },
      onDone: () {
        unawaited(controller.close());
        _cleanupWs();
      },
      cancelOnError: false,
    );
    return controller.stream;
  }

  /// Close the WebSocket and release resources.
  Future<void> closeWebSocket() async {
    await _wsChannel?.sink.close();
    _cleanupWs();
  }

  /// `GET /:/eventsource/notifications` — open a Server-Sent Events
  /// stream of notifications. SSE is a one-way (server → client)
  /// transport; use this when WebSockets are blocked.
  ///
  /// [filter] (optional) restricts to one notification type.
  Stream<PlexNotification> connectEventSource({String? filter}) {
    if (_sseController != null) {
      throw const PlexException(
        'EventSource already connected. Call closeEventSource() first.',
        type: PlexErrorType.state,
      );
    }
    _http.requireConnected();
    final token = _http.token;
    if (token == null) {
      throw const PlexException(
        'No PMS token. Call connect() / setToken() first.',
        type: PlexErrorType.state,
      );
    }
    final qp = <String, String>{'X-Plex-Token': token};
    if (filter != null) qp['filter'] = filter;

    final controller = StreamController<PlexNotification>.broadcast(
      onCancel: () {
        if (!(_sseController?.hasListener ?? false)) {
          unawaited(closeEventSource());
        }
      },
    );
    _sseController = controller;
    final cancel = _sseCancel = PlexCancelToken();

    // Use the connection's streaming GET to consume the SSE body.
    unawaited(() async {
      try {
        final res = await _http.requestStream(
          '/:/eventsource/notifications',
          queryParameters: qp,
          extraHeaders: const {'Accept': 'text/event-stream'},
          absoluteUrl: false,
          // An event stream can stay quiet for minutes; that is not a stall.
          stallTimeout: false,
          cancelToken: cancel,
        );
        final buffer = StringBuffer();
        // Decode the body as one continuous stream, not chunk by chunk: a
        // multi-byte character can straddle a network chunk boundary, and
        // decoding each chunk on its own turns both of its halves into
        // U+FFFD. The chunked converter holds the incomplete sequence back
        // until the bytes that finish it arrive. `allowMalformed` still
        // covers bytes that are invalid however they are joined, so one
        // corrupt frame degrades instead of erroring the subscription and
        // taking every later notification with it.
        _sseSub = res.stream
            .transform(const Utf8Decoder(allowMalformed: true))
            .listen(
          (text) {
            buffer.write(text);
            // SSE frames are separated by a blank line.
            while (true) {
              final raw = buffer.toString();
              final idx = raw.indexOf('\n\n');
              if (idx < 0) break;
              final frame = raw.substring(0, idx);
              buffer
                ..clear()
                ..write(raw.substring(idx + 2));
              final payload = _extractSseData(frame);
              if (payload == null) continue;
              final notif = _decode(payload);
              if (notif != null) controller.add(notif);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (cancel.isCancelled) return;
            controller.addError(
              error is PlexException
                  ? error
                  : PlexException(
                      'EventSource error: $error',
                      type: PlexErrorType.connection,
                      cause: error,
                    ),
              stackTrace,
            );
          },
          onDone: () {
            unawaited(controller.close());
            if (identical(_sseController, controller)) _cleanupSse();
          },
          cancelOnError: false,
        );
      } catch (e, stackTrace) {
        // Closed before the headers arrived: nothing to report.
        if (cancel.isCancelled) return;
        controller.addError(
          e is PlexException
              ? e
              : PlexException(
                  'EventSource open failed: $e',
                  type: PlexErrorType.connection,
                  cause: e,
                ),
          stackTrace,
        );
        unawaited(controller.close());
        if (identical(_sseController, controller)) _cleanupSse();
      }
    }());

    return controller.stream;
  }

  /// Close the EventSource stream and release resources — also while it
  /// is still connecting.
  Future<void> closeEventSource() async {
    _sseCancel?.cancel();
    await _sseSub?.cancel();
    _cleanupSse();
  }

  void _cleanupWs() {
    unawaited(_wsSub?.cancel());
    _wsSub = null;
    _wsChannel = null;
    if (!(_wsController?.isClosed ?? true)) {
      unawaited(_wsController?.close());
    }
    _wsController = null;
  }

  void _cleanupSse() {
    _sseSub = null;
    _sseCancel = null;
    if (!(_sseController?.isClosed ?? true)) {
      unawaited(_sseController?.close());
    }
    _sseController = null;
  }

  PlexNotification? _decode(String message) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map<String, Object?>) {
        // Plex wraps under "NotificationContainer".
        final container = decoded['NotificationContainer'];
        if (container is Map<String, Object?>) {
          return PlexNotification.fromJson(container);
        }
        return PlexNotification.fromJson(decoded);
      }
    } catch (_) {
      // Skip malformed frames.
    }
    return null;
  }

  String? _extractSseData(String frame) {
    final lines = frame.split('\n');
    final buf = StringBuffer();
    for (final line in lines) {
      if (line.startsWith('data:')) {
        if (buf.isNotEmpty) buf.write('\n');
        buf.write(line.substring(5).trimLeft());
      }
    }
    final result = buf.toString();
    return result.isEmpty ? null : result;
  }

  String _toWs(String httpUrl) {
    if (httpUrl.startsWith('https://')) {
      return 'wss://${httpUrl.substring(8)}';
    }
    if (httpUrl.startsWith('http://')) {
      return 'ws://${httpUrl.substring(7)}';
    }
    return httpUrl;
  }
}

/// One frame received from the Plex notifications stream.
final class PlexNotification {
  /// Upstream `type` discriminator (e.g. `'playing'`, `'progress'`,
  /// `'activity'`, `'transcodeSession.update'`,
  /// `'transcodeSession.end'`, `'preference'`, `'reachability'`).
  final String type;

  /// The size of the payload as the server reported it.
  final int? size;

  /// The raw frame, useful when the notification type's payload is
  /// not yet promoted to a typed accessor.
  final Map<String, Object?> raw;

  /// Wraps a notification frame with its [type] discriminator and [raw] payload.
  const PlexNotification({
    required this.type,
    required this.size,
    required this.raw,
  });

  /// Parse a single notification frame from its server-side JSON representation.
  factory PlexNotification.fromJson(Map<String, Object?> json) {
    final t = json['type']?.toString() ?? 'unknown';
    final sz = json['size'];
    return PlexNotification(
      type: t,
      size: sz is int ? sz : (sz is String ? int.tryParse(sz) : null),
      raw: json,
    );
  }

  /// The frame's entries as typed events — usually one, sometimes
  /// several. Frame types without a typed event give one
  /// [PlexUnknownEvent].
  List<PlexEvent> get events => PlexEvent.fromFrame(type, raw);

  @override
  String toString() => 'PlexNotification($type)';
}

/// Typed events from a notification stream.
extension PlexNotificationEvents on Stream<PlexNotification> {
  /// Every entry of every frame as a [PlexEvent]: play state changes
  /// ([PlexPlaySessionEvent]), library item changes
  /// ([PlexLibraryItemEvent]), activities such as scans
  /// ([PlexActivityEvent]) and status messages ([PlexStatusEvent]).
  Stream<PlexEvent> events() => expand((n) => n.events);
}
