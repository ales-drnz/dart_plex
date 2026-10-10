// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'plex_credentials.dart';
import 'plex_error_type.dart';
import 'plex_exception.dart';
import 'transport/platform_io.dart'
    if (dart.library.js_interop) 'transport/platform_web.dart' as platform;
import 'transport/plex_cancel_token.dart';
import 'transport/plex_response.dart';

/// What a connection and every scoped view of it share (see
/// [PlexConnection.scoped]): the HTTP client, the server URL and the
/// session.
class _Shared {
  final http.Client client;
  final bool ownsClient;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final int jsonIsolateThreshold;
  String? baseUrl;
  String? token;
  bool closed = false;

  _Shared({
    required this.client,
    required this.ownsClient,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.jsonIsolateThreshold,
  });
}

/// Internal HTTP transport shared by every sub-API. Not exported; the
/// public API is [PlexClient].
///
/// Built on `package:http`, so the app can hand in any [http.Client] — a
/// native one (`cupertino_http`, `cronet_http`) for HTTP/2 and the system
/// proxy, or a `MockClient` in tests.
class PlexConnection {
  final _Shared _shared;

  /// Client identity sent on every request via the auth header.
  final PlexCredentials credentials;

  /// Cancels every request issued through this connection that does not
  /// bring its own token. `null` on the root connection.
  final PlexCancelToken? scopeToken;

  /// Responses at least this large are decoded — and, for the typed calls,
  /// parsed into models — on a background isolate instead of the caller's.
  ///
  /// A playlist's full item list is hundreds of KB of JSON; decoding one
  /// measured a ~130–150 ms stall of the UI thread in Flumael. Below the
  /// threshold the isolate hop costs more than the decode it saves, which
  /// is why this is a threshold and not "always". Override per client with
  /// the `jsonIsolateThreshold` argument.
  static const int defaultJsonIsolateThreshold = 50 * 1024;

  /// The default threshold. Kept under its 0.2 name.
  static const int jsonIsolateThreshold = defaultJsonIsolateThreshold;

  /// Creates a connection bound to [credentials].
  ///
  /// Without an [httpClient], one is created (and closed by [close]) with
  /// [connectTimeout] applied to the handshake. An injected client is never
  /// closed by this connection.
  ///
  /// [receiveTimeout] bounds the wait for the response headers and every
  /// pause between two chunks of the body — not the whole transfer, so a
  /// long download that keeps flowing never times out.
  PlexConnection({
    required this.credentials,
    http.Client? httpClient,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 30),
    int jsonIsolateThreshold = defaultJsonIsolateThreshold,
  })  : _shared = _Shared(
          client: httpClient ?? platform.createDefaultClient(connectTimeout),
          ownsClient: httpClient == null,
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
          jsonIsolateThreshold: jsonIsolateThreshold,
        ),
        scopeToken = null;

  /// A view of [parent] whose requests are cancelled by [cancelToken].
  ///
  /// The view shares [parent]'s client, credentials, base URL and session:
  /// a later `setSession` or `connect` on either is seen by both. A token
  /// passed to an individual [request] still wins.
  PlexConnection.scoped(
    PlexConnection parent,
    PlexCancelToken cancelToken,
  )   : _shared = parent._shared,
        credentials = parent.credentials,
        scopeToken = cancelToken;

  /// Effective isolate threshold for this connection. For tests.
  @visibleForTesting
  int get effectiveJsonIsolateThreshold => _shared.jsonIsolateThreshold;

  /// PMS base URL without a trailing slash, or `null` if not connected.
  String? get baseUrl => _shared.baseUrl;

  /// Sets the server root URL, stripping a trailing `/` if present.
  set baseUrl(String? value) {
    _shared.baseUrl = value != null && value.endsWith('/')
        ? value.substring(0, value.length - 1)
        : value;
  }

  /// Current `X-Plex-Token`, or `null` if not authenticated.
  String? get token => _shared.token;

  /// Sets or clears the `X-Plex-Token` sent on every request.
  set token(String? value) => _shared.token = value;

  /// Whether a PMS base URL and a token are both set.
  bool get isAuthenticated => baseUrl != null && token != null;

  /// Throw a [PlexErrorType.state] [PlexException] if no PMS base URL has
  /// been configured yet.
  void requireConnected() {
    if (baseUrl == null) {
      throw const PlexException(
        'No PMS connection — call PlexClient.connect() first.',
        type: PlexErrorType.state,
      );
    }
  }

  /// Closes the HTTP client if this connection created it. Requests made
  /// afterwards fail with [PlexErrorType.state].
  void close() {
    if (_shared.closed) return;
    _shared.closed = true;
    if (_shared.ownsClient) _shared.client.close();
  }

  /// Headers sent on every request: the `X-Plex-*` identity, `Accept:
  /// application/json` (PMS answers XML otherwise) and the token.
  Map<String, String> get _baseHeaders => {
        ...credentials.toHeaders(),
        if (token != null) 'X-Plex-Token': token!,
      };

  /// Issues an HTTP request relative to [baseUrl] (or absolute when
  /// `absoluteUrl` is `true`) and decodes the body per [responseType].
  ///
  /// Throws a [PlexException] on any failure: transport, timeout,
  /// cancellation, a non-2xx status, or a body that is not a [T].
  ///
  /// Pass [absoluteUrl] = true and a full URL in [path] to target a host
  /// other than the connected server — used by the plex.tv account API.
  ///
  /// A `List` value in [queryParameters] repeats its key once per element.
  ///
  /// [data] is sent as JSON when it is a `Map`, a `List` of maps or a
  /// `String`, and as raw bytes when it is a `List<int>`.
  Future<PlexResponse<T>> request<T>(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? queryParameters,
    Object? data,
    Map<String, String>? extraHeaders,
    bool absoluteUrl = false,
    PlexResponseType? responseType,
    PlexCancelToken? cancelToken,
  }) async {
    final exchange = await _exchange(
      path,
      method: method,
      queryParameters: queryParameters,
      data: data,
      extraHeaders: extraHeaders,
      absoluteUrl: absoluteUrl,
      cancelToken: cancelToken,
    );
    final Object? decoded;
    try {
      decoded = await _decode(
        exchange.bytes,
        responseType ?? PlexResponseType.json,
        exchange.headers['content-type'],
      );
    } on FormatException catch (e, st) {
      throw _parseError(e, st, exchange.uri);
    }
    if (decoded != null && decoded is! T) {
      throw PlexException(
        'Expected a $T body, got ${decoded.runtimeType}',
        type: PlexErrorType.parse,
        statusCode: exchange.statusCode,
        path: exchange.uri.toString(),
      );
    }
    return PlexResponse<T>(
      data: decoded as T?,
      statusCode: exchange.statusCode,
      headers: exchange.headers,
      uri: exchange.uri,
    );
  }

  /// Like [request], but decodes the JSON body *and* runs [parse] over it —
  /// both on a background isolate when the body is at least
  /// [effectiveJsonIsolateThreshold] bytes.
  ///
  /// [parse] receives the decoded JSON (`null` for an empty body). It runs
  /// on another isolate, so it must not capture anything that cannot be
  /// sent there — pass a static `fromJson` tear-off or a closure over plain
  /// values, never one that reaches the connection or a sub-API.
  Future<R> requestJson<R>(
    String path,
    R Function(Object? json) parse, {
    String method = 'GET',
    Map<String, dynamic>? queryParameters,
    Object? data,
    Map<String, String>? extraHeaders,
    bool absoluteUrl = false,
    PlexCancelToken? cancelToken,
  }) async {
    final exchange = await _exchange(
      path,
      method: method,
      queryParameters: queryParameters,
      data: data,
      extraHeaders: extraHeaders,
      absoluteUrl: absoluteUrl,
      cancelToken: cancelToken,
    );
    final bytes = exchange.bytes;
    try {
      if (platform.canUseIsolates &&
          bytes.length >= _shared.jsonIsolateThreshold) {
        return await platform.runOffIsolate(() => parse(_jsonOf(bytes)));
      }
      return parse(_jsonOf(bytes));
    } on PlexException {
      rethrow;
    } on FormatException catch (e, st) {
      throw _parseError(e, st, exchange.uri);
    } on TypeError catch (e, st) {
      throw _parseError(e, st, exchange.uri);
    }
  }

  /// Convenience for byte GETs (artwork, small files). The whole body is
  /// held in memory; use [requestStream] for media.
  Future<PlexResponse<Uint8List>> requestBytes(
    String url, {
    Map<String, dynamic>? queryParameters,
    bool absoluteUrl = true,
    PlexCancelToken? cancelToken,
  }) =>
      request<Uint8List>(
        url,
        queryParameters: queryParameters,
        absoluteUrl: absoluteUrl,
        responseType: PlexResponseType.bytes,
        cancelToken: cancelToken,
      );

  /// Opens a GET whose body is delivered as it arrives, for downloads.
  ///
  /// The status is checked before this returns: a non-2xx answer throws
  /// like [request]. The returned stream fails with a [PlexException]
  /// on cancellation and, unless [stallTimeout] is `false`, on a pause in
  /// the body longer than the receive timeout. Turn it off for event
  /// streams that may stay quiet for minutes.
  Future<PlexStreamedResponse> requestStream(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? extraHeaders,
    bool absoluteUrl = true,
    bool stallTimeout = true,
    PlexCancelToken? cancelToken,
  }) async {
    final opened = await _open(
      url,
      method: 'GET',
      queryParameters: queryParameters,
      data: null,
      extraHeaders: extraHeaders,
      absoluteUrl: absoluteUrl,
      cancelToken: cancelToken,
    );
    if (!stallTimeout) opened.receiveTimeout = null;
    final res = opened.response;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = await _readAll(opened);
      throw _statusError(res.statusCode, res.reasonPhrase, opened.uri, body);
    }
    return PlexStreamedResponse(
      stream: _guard(opened),
      statusCode: res.statusCode,
      headers: res.headers,
      contentLength: res.contentLength,
      uri: opened.uri,
    );
  }

  // ─── Internals ─────────────────────────────────────────────────────

  Future<_Exchange> _exchange(
    String path, {
    required String method,
    required Map<String, dynamic>? queryParameters,
    required Object? data,
    required Map<String, String>? extraHeaders,
    required bool absoluteUrl,
    required PlexCancelToken? cancelToken,
  }) async {
    final opened = await _open(
      path,
      method: method,
      queryParameters: queryParameters,
      data: data,
      extraHeaders: extraHeaders,
      absoluteUrl: absoluteUrl,
      cancelToken: cancelToken,
    );
    final res = opened.response;
    final bytes = await _readAll(opened);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _statusError(res.statusCode, res.reasonPhrase, opened.uri, bytes);
    }
    return _Exchange(opened.uri, res.statusCode, res.headers, bytes);
  }

  /// Sends the request and waits for the response headers.
  Future<_Opened> _open(
    String path, {
    required String method,
    required Map<String, dynamic>? queryParameters,
    required Object? data,
    required Map<String, String>? extraHeaders,
    required bool absoluteUrl,
    required PlexCancelToken? cancelToken,
  }) async {
    if (_shared.closed) {
      throw const PlexException(
        'PlexClient.close() has been called.',
        type: PlexErrorType.state,
      );
    }
    final uri = buildUri(
      absoluteUrl ? path : _resolve(path),
      queryParameters,
    );
    final token = cancelToken ?? scopeToken;
    if (token != null && token.isCancelled) throw _cancelled(uri);

    final abort = Completer<void>();
    final request = http.AbortableRequest(
      method,
      uri,
      abortTrigger: abort.future,
    );
    request.headers.addAll(_baseHeaders);
    _encodeBody(request, data);
    if (extraHeaders != null) request.headers.addAll(extraHeaders);

    final opened = _Opened(uri, abort, token, _shared.receiveTimeout);
    final headers = Completer<http.StreamedResponse>();
    void lose(PlexException e) {
      if (headers.isCompleted) return;
      opened.abort();
      headers.completeError(e, e.stackTrace);
    }

    final timer = Timer(
      _shared.connectTimeout + _shared.receiveTimeout,
      () => lose(_timeout('No response within the timeout', uri)),
    );
    if (token != null) {
      unawaited(token.whenCancelled.then((_) => lose(_cancelled(uri))));
    }
    try {
      final sent = _shared.client.send(request).then(
        (res) {
          if (headers.isCompleted) {
            // Lost the race to a timeout or a cancellation: drop the body.
            unawaited(res.stream.listen(null).cancel());
          } else {
            headers.complete(res);
          }
        },
        onError: (Object e, StackTrace st) =>
            lose(_transportError(e, st, uri, token)),
      );
      unawaited(sent);
    } catch (e, st) {
      lose(_transportError(e, st, uri, token));
    }
    try {
      opened.response = await headers.future;
      return opened;
    } finally {
      timer.cancel();
    }
  }

  /// Reads the whole body of [opened], honouring the inactivity timeout and
  /// the cancel token.
  Future<Uint8List> _readAll(_Opened opened) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in _guard(opened)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// The body of [opened] as a stream that fails with a [PlexException]
  /// on a stall, a cancellation or a transport error.
  Stream<List<int>> _guard(_Opened opened) {
    final uri = opened.uri;
    final token = opened.token;
    late final StreamController<List<int>> out;
    StreamSubscription<List<int>>? sub;
    Timer? stall;

    void fail(PlexException e) {
      stall?.cancel();
      opened.abort();
      unawaited(sub?.cancel());
      if (!out.isClosed) {
        out.addError(e, e.stackTrace);
        unawaited(out.close());
      }
    }

    void arm() {
      stall?.cancel();
      final timeout = opened.receiveTimeout;
      if (timeout == null) return;
      stall = Timer(
        timeout,
        () => fail(_timeout('The body stalled', uri)),
      );
    }

    out = StreamController<List<int>>(
      onListen: () {
        if (token != null) {
          if (token.isCancelled) return fail(_cancelled(uri));
          token.whenCancelled.then((_) => fail(_cancelled(uri)));
        }
        arm();
        sub = opened.response.stream.listen(
          (chunk) {
            arm();
            out.add(chunk);
          },
          onError: (Object e, StackTrace st) =>
              fail(_transportError(e, st, uri, token)),
          onDone: () {
            stall?.cancel();
            unawaited(out.close());
          },
        );
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () {
        stall?.cancel();
        opened.abort();
        return sub?.cancel();
      },
    );
    return out.stream;
  }

  void _encodeBody(http.Request request, Object? data) {
    if (data == null) return;
    if (data is List<int>) {
      request.bodyBytes = data;
      return;
    }
    if (data is Map || data is List || data is String) {
      request.headers['Content-Type'] = 'application/json';
      request.bodyBytes = utf8.encode(data is String ? data : jsonEncode(data));
      return;
    }
    throw PlexException(
      'Cannot send a ${data.runtimeType} body',
      type: PlexErrorType.state,
    );
  }

  Future<Object?> _decode(
    Uint8List bytes,
    PlexResponseType type,
    String? contentType,
  ) async {
    switch (type) {
      case PlexResponseType.bytes:
        return bytes;
      case PlexResponseType.plain:
        return utf8.decode(bytes, allowMalformed: true);
      case PlexResponseType.json:
        if (bytes.isEmpty) return null;
        if (!_isJson(contentType)) {
          return utf8.decode(bytes, allowMalformed: true);
        }
        if (platform.canUseIsolates &&
            bytes.length >= _shared.jsonIsolateThreshold) {
          return platform.runOffIsolate(() => _jsonOf(bytes));
        }
        return _jsonOf(bytes);
    }
  }

  String _resolve(String path) {
    final base = baseUrl;
    if (base == null) {
      throw const PlexException(
        'PlexClient.connect() has not been called — no PMS base URL is set.',
        type: PlexErrorType.state,
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (!path.startsWith('/')) return '$base/$path';
    return '$base$path';
  }

  /// Appends [queryParameters] to [url] the way the 0.2 transport did, so
  /// the wire shape is unchanged: keys and string values are
  /// form-encoded (`encodeQueryComponent`), a list repeats its key once per
  /// element, and a `null` value sends the bare key.
  @visibleForTesting
  static Uri buildUri(String url, Map<String, dynamic>? queryParameters) {
    final qp = queryParameters;
    if (qp == null || qp.isEmpty) return Uri.parse(url).normalizePath();
    final parts = <String>[];
    void add(String key, Object? value) {
      if (value == null) {
        parts.add(key);
      } else if (value is String) {
        parts.add('$key=${Uri.encodeQueryComponent(value)}');
      } else {
        parts.add('$key=$value');
      }
    }

    qp.forEach((k, v) {
      final key = Uri.encodeQueryComponent(k);
      if (v is Iterable) {
        for (final e in v) {
          add(key, e);
        }
      } else {
        add(key, v);
      }
    });
    final sep = url.contains('?') ? '&' : '?';
    return Uri.parse('$url$sep${parts.join('&')}').normalizePath();
  }

  static bool _isJson(String? contentType) {
    if (contentType == null) return false;
    final mime = contentType.split(';').first.trim().toLowerCase();
    return mime == 'application/json' ||
        mime == 'text/json' ||
        mime.endsWith('+json');
  }

  PlexException _statusError(
    int status,
    String? reason,
    Uri uri,
    Uint8List body,
  ) {
    final text = body.isEmpty
        ? ''
        : ': ${utf8.decode(body.length > 512 ? body.sublist(0, 512) : body, allowMalformed: true)}';
    return PlexException(
      'HTTP $status${reason == null || reason.isEmpty ? '' : ' $reason'}$text',
      type: PlexErrorType.fromHttpStatus(status),
      statusCode: status,
      path: uri.toString(),
    );
  }

  PlexException _transportError(
    Object e,
    StackTrace st,
    Uri uri,
    PlexCancelToken? token,
  ) {
    if (e is PlexException) return e;
    if (e is http.RequestAbortedException || (token?.isCancelled ?? false)) {
      return _cancelled(uri);
    }
    if (e is TimeoutException) return _timeout('$e', uri, e, st);
    final text = '$e';
    final type = text.contains('timed out')
        ? PlexErrorType.timeout
        : e is http.ClientException
            ? PlexErrorType.connection
            : PlexErrorType.unknown;
    return PlexException(
      text,
      type: type,
      path: uri.toString(),
      cause: e,
      stackTrace: st,
    );
  }

  PlexException _parseError(Object e, StackTrace st, Uri uri) => PlexException(
        'Could not decode the response: $e',
        type: PlexErrorType.parse,
        path: uri.toString(),
        cause: e,
        stackTrace: st,
      );

  static PlexException _timeout(
    String message,
    Uri uri, [
    Object? cause,
    StackTrace? st,
  ]) =>
      PlexException(
        message,
        type: PlexErrorType.timeout,
        path: uri.toString(),
        cause: cause,
        stackTrace: st ?? StackTrace.current,
      );

  static PlexException _cancelled(Uri uri) => PlexException(
        'Request cancelled',
        type: PlexErrorType.cancelled,
        path: uri.toString(),
      );
}

/// Decodes a JSON body; `null` when empty. Top-level so it can run on
/// another isolate.
Object? _jsonOf(Uint8List bytes) =>
    bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));

/// A request whose headers have arrived.
final class _Opened {
  final Uri uri;
  final Completer<void> _abort;
  final PlexCancelToken? token;
  Duration? receiveTimeout;
  late http.StreamedResponse response;

  _Opened(this.uri, this._abort, this.token, this.receiveTimeout);

  void abort() {
    if (!_abort.isCompleted) _abort.complete();
  }
}

/// A finished request with its whole body.
final class _Exchange {
  final Uri uri;
  final int statusCode;
  final Map<String, String> headers;
  final Uint8List bytes;

  _Exchange(this.uri, this.statusCode, this.headers, this.bytes);
}
