// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// @docImport '../plex_client.dart';
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../notifications/sse_parser.dart';
import '../notifications/ws_connect_io.dart'
    if (dart.library.js_interop) '../notifications/ws_connect_web.dart';
import '../plex_connection.dart';
import '../plex_error_type.dart';
import '../plex_events.dart';
import '../plex_exception.dart';
import '../plex_urls.dart';
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
///
/// Both streams are broadcast streams: a frame that arrives while nobody
/// listens is dropped, and cancelling the last subscription closes the
/// connection. Neither transport reconnects: when a stream ends — the
/// server went away, the event source stayed silent — open a new one.
/// [PlexClient.close] closes both.
///
/// Only the event source notices a connection that died without a word
/// (its `idleTimeout`). The WebSocket cannot: PMS pings the client, which
/// the socket answers unseen, but answers only the first ping a client
/// sends, so there is nothing to time.
///
/// {@category Events and downloads}
class PlexNotificationsApi {
  /// How long a close waits for the peer to answer the close handshake.
  static const _closeTimeout = Duration(seconds: 2);

  static final _handshakeStatus = RegExp(r'HTTP status code: (\d{3})\b');

  final PlexConnection _http;

  WebSocketChannel? _wsChannel;
  StreamController<PlexNotification>? _wsController;
  StreamSubscription<Object?>? _wsSub;

  /// The handshake in flight; completed by [closeWebSocket] to abort it.
  Completer<void>? _wsConnecting;
  int? _wsCloseCode;
  String? _wsCloseReason;

  StreamController<PlexNotification>? _sseController;
  StreamSubscription<String>? _sseSub;
  Timer? _sseIdle;

  /// Cancels the EventSource request, including while it is still
  /// waiting for the response headers.
  PlexCancelToken? _sseCancel;

  int _malformed = 0;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.notifications].
  PlexNotificationsApi(this._http);

  /// True while a WebSocket is open.
  bool get isWebSocketConnected => _wsChannel != null;

  /// True while an EventSource (SSE) stream is open.
  bool get isEventSourceConnected => _sseController != null;

  /// The close code the server sent when the last WebSocket ended on its
  /// own (`1005` when its close frame carried none). `null` while
  /// connected, after [closeWebSocket], and when the connection dropped
  /// without a close frame.
  int? get webSocketCloseCode => _wsCloseCode;

  /// The close reason that came with [webSocketCloseCode], if any.
  String? get webSocketCloseReason => _wsCloseReason;

  /// Frames dropped since this object was created because they could not
  /// be read: invalid JSON, a binary WebSocket frame, an event-stream
  /// frame past the size cap. The stream stays open and reports no error
  /// for them.
  int get malformedFrameCount => _malformed;

  /// `GET /:/websockets/notifications` — open a WebSocket and emit
  /// every notification as a [PlexNotification].
  ///
  /// Awaits the socket handshake before returning, so the returned stream is
  /// live and [isWebSocketConnected] is only `true` once the connection is
  /// actually open. Throws a [PlexException] of type
  /// [PlexErrorType.connection] if the connection cannot be established,
  /// [PlexErrorType.auth] if the server refused the token,
  /// [PlexErrorType.timeout] if the handshake takes longer than
  /// [connectTimeout], [PlexErrorType.state] if a WebSocket is already
  /// open or connecting, and [PlexErrorType.cancelled] if [closeWebSocket]
  /// is called meanwhile.
  ///
  /// [filter] (optional) restricts to one notification type (e.g.
  /// `'playing'`, `'progress'`, `'activity'`, `'transcodeSession.update'`).
  ///
  /// The stream is a broadcast stream: frames that arrive before the
  /// first listener are dropped, and cancelling the last subscription
  /// closes the socket. A stream that ends is not reconnected; why it
  /// ended is in [webSocketCloseCode].
  Future<Stream<PlexNotification>> connectWebSocket({
    String? filter,
    Duration connectTimeout = const Duration(seconds: 30),
  }) async {
    if (_wsChannel != null || _wsConnecting != null) {
      throw const PlexException(
        'WebSocket already connected. Call closeWebSocket() first.',
        type: PlexErrorType.state,
      );
    }
    _http.requireConnected();
    if (_http.token == null) {
      throw const PlexException(
        'No PMS token. Call connect() / setToken() first.',
        type: PlexErrorType.state,
      );
    }
    // The token goes in the query: a browser cannot set headers on a
    // WebSocket handshake.
    final wsUrl = _toWs(
      _http.signedUrl('/:/websockets/notifications', {'filter': ?filter}),
    );

    final abort = _wsConnecting = Completer<void>();
    WebSocketChannel? opening;
    try {
      opening = connectNotificationsSocket(
        Uri.parse(wsUrl),
        connectTimeout: connectTimeout,
      );
      await Future.any([opening.ready.timeout(connectTimeout), abort.future]);
    } catch (e, st) {
      if (identical(_wsConnecting, abort)) _wsConnecting = null;
      if (opening != null) unawaited(_closeChannel(opening));
      throw _wsOpenError(e, st, connectTimeout);
    }
    final channel = opening;
    if (abort.isCompleted) {
      unawaited(_closeChannel(channel));
      throw const PlexException(
        'WebSocket closed while connecting.',
        type: PlexErrorType.cancelled,
      );
    }
    _wsConnecting = null;
    _wsCloseCode = null;
    _wsCloseReason = null;

    late final StreamController<PlexNotification> controller;
    controller = StreamController<PlexNotification>.broadcast(
      onCancel: () {
        if (identical(_wsController, controller) && !controller.hasListener) {
          unawaited(closeWebSocket());
        }
      },
    );
    _wsChannel = channel;
    _wsController = controller;
    _wsSub = channel.stream.listen(
      (message) {
        if (message is! String) {
          _malformed++;
          return;
        }
        final decoded = _json(message);
        if (decoded == null) return;
        // Plex wraps under "NotificationContainer".
        final container = decoded['NotificationContainer'];
        controller.add(
          PlexNotification.fromJson(
            container is Map<String, Object?> ? container : decoded,
          ),
        );
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
        if (!identical(_wsChannel, channel)) return;
        _wsCloseCode = channel.closeCode;
        _wsCloseReason = channel.closeReason;
        _cleanupWs();
      },
      cancelOnError: false,
    );
    return controller.stream;
  }

  /// Close the WebSocket and release resources — also while it is still
  /// connecting, which makes the pending [connectWebSocket] throw
  /// [PlexErrorType.cancelled]. Waits a couple of seconds at most for the
  /// server to answer the close.
  Future<void> closeWebSocket() async {
    final connecting = _wsConnecting;
    _wsConnecting = null;
    if (connecting != null && !connecting.isCompleted) connecting.complete();
    final channel = _wsChannel;
    _cleanupWs();
    if (channel != null) await _closeChannel(channel);
  }

  /// `GET /:/eventsource/notifications` — open a Server-Sent Events
  /// stream of notifications. SSE is a one-way (server → client)
  /// transport; use this when WebSockets are blocked.
  ///
  /// [filter] (optional) restricts to one notification type.
  ///
  /// The request is sent when the stream gets its first listener, so a
  /// failure to open reaches that listener as a [PlexException] error
  /// followed by the end of the stream. The stream is a broadcast stream:
  /// cancelling the last subscription closes the connection. A stream
  /// that ends is not reconnected.
  ///
  /// The server sends a `ping` event every 10 seconds (they are not
  /// emitted). When nothing at all arrives for [idleTimeout] the
  /// connection is taken for dead: the stream gets a [PlexException] of
  /// type [PlexErrorType.timeout] and ends. `null` waits forever.
  ///
  /// The server names the frame type in the `event:` line and sends each
  /// entry bare; frames come out in the WebSocket shape, see
  /// [PlexNotification.raw].
  Stream<PlexNotification> connectEventSource({
    String? filter,
    Duration? idleTimeout = const Duration(seconds: 60),
  }) {
    if (_sseController != null) {
      throw const PlexException(
        'EventSource already connected. Call closeEventSource() first.',
        type: PlexErrorType.state,
      );
    }
    _http.requireConnected();
    if (_http.token == null) {
      throw const PlexException(
        'No PMS token. Call connect() / setToken() first.',
        type: PlexErrorType.state,
      );
    }
    final cancel = _sseCancel = PlexCancelToken();
    var started = false;
    late final StreamController<PlexNotification> controller;
    controller = StreamController<PlexNotification>.broadcast(
      // Opening on the first listener: a broadcast stream drops an error
      // nobody listens to, and the open failure must not be one of them.
      onListen: () {
        if (started) return;
        started = true;
        unawaited(_runEventSource(controller, cancel, filter, idleTimeout));
      },
      onCancel: () {
        if (identical(_sseController, controller) && !controller.hasListener) {
          unawaited(closeEventSource());
        }
      },
    );
    _sseController = controller;
    return controller.stream;
  }

  Future<void> _runEventSource(
    StreamController<PlexNotification> controller,
    PlexCancelToken cancel,
    String? filter,
    Duration? idleTimeout,
  ) async {
    void end() {
      if (identical(_sseController, controller)) {
        _cleanupSse();
      } else if (!controller.isClosed) {
        unawaited(controller.close());
      }
    }

    void watch() {
      if (idleTimeout == null) return;
      _sseIdle?.cancel();
      _sseIdle = Timer(idleTimeout, () {
        if (!identical(_sseController, controller)) return;
        controller.addError(
          PlexException(
            'EventSource silent for ${idleTimeout.inSeconds} s: '
            'connection taken for dead.',
            type: PlexErrorType.timeout,
          ),
        );
        unawaited(closeEventSource());
      });
    }

    try {
      // The token travels in the `X-Plex-Token` header the connection
      // adds, not in the URL.
      final res = await _http.requestStream(
        '/:/eventsource/notifications',
        queryParameters: {'filter': ?filter},
        extraHeaders: const {'Accept': 'text/event-stream'},
        absoluteUrl: false,
        // An event stream can stay quiet past the receive timeout; the
        // idle watchdog is its stall detection.
        stallTimeout: false,
        cancelToken: cancel,
      );
      final parser = SseParser(onOverflow: () => _malformed++);
      watch();
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
              watch();
              for (final event in parser.add(text)) {
                final notif = _decodeSse(event.event, event.data);
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
            onDone: end,
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
      end();
    }
  }

  /// Close the EventSource stream and release resources — also while it
  /// is still connecting.
  Future<void> closeEventSource() async {
    _sseCancel?.cancel();
    final cancelled = _sseSub?.cancel();
    _cleanupSse();
    await cancelled;
  }

  /// Closes [channel], waiting [_closeTimeout] at most for the peer.
  Future<void> _closeChannel(WebSocketChannel channel) async {
    try {
      await channel.sink.close().timeout(_closeTimeout);
    } catch (_) {
      // Already gone, or the peer never answered: nothing left to release.
    }
  }

  PlexException _wsOpenError(Object error, StackTrace st, Duration timeout) {
    final cause = error is WebSocketChannelException
        ? error.inner ?? error
        : error;
    if (cause is TimeoutException) {
      return PlexException(
        'WebSocket handshake timed out after ${timeout.inSeconds} s.',
        type: PlexErrorType.timeout,
        cause: cause,
        stackTrace: st,
      );
    }
    // `dart:io` names the status of a refused upgrade in the message; a
    // browser tells a page nothing.
    final status = int.tryParse(
      _handshakeStatus.firstMatch('$cause')?.group(1) ?? '',
    );
    return PlexException(
      'WebSocket connection failed: $cause',
      type: status == 401 || status == 403
          ? PlexErrorType.auth
          : PlexErrorType.connection,
      statusCode: status,
      cause: cause,
      stackTrace: st,
    );
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
    _sseIdle?.cancel();
    _sseIdle = null;
    _sseSub = null;
    _sseCancel = null;
    if (!(_sseController?.isClosed ?? true)) {
      unawaited(_sseController?.close());
    }
    _sseController = null;
  }

  /// The JSON object in [message]; anything else counts as malformed.
  Map<String, Object?>? _json(String message) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      // Counted below.
    }
    _malformed++;
    return null;
  }

  /// One event-stream frame as a notification, or `null` for a keepalive
  /// and for a frame that cannot be read.
  ///
  /// PMS sends `event: activity` + `data: {"ActivityNotification":{…}}`:
  /// the type is the event name, there is no `NotificationContainer`,
  /// and the entry is an object where the WebSocket has a list of them.
  /// The frame is rebuilt in the WebSocket shape so both transports read
  /// the same.
  PlexNotification? _decodeSse(String? event, String data) {
    if (event == 'ping') return null;
    final decoded = _json(data);
    if (decoded == null) return null;
    final container = decoded['NotificationContainer'];
    if (container is Map<String, Object?>) {
      return PlexNotification.fromJson(container);
    }
    if (event == null || event == 'message' || decoded['type'] != null) {
      return PlexNotification.fromJson(decoded);
    }
    return PlexNotification.fromJson({
      'type': event,
      for (final MapEntry(:key, :value) in decoded.entries)
        key: value is Map<String, Object?> ? [value] : value,
    });
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
