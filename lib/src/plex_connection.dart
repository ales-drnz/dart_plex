// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'plex_client.dart';
import 'plex_credentials.dart';
import 'plex_error_type.dart';
import 'plex_exception.dart';
import 'transport/platform_io.dart'
    if (dart.library.js_interop) 'transport/platform_web.dart' as platform;
import 'transport/plex_cancel_token.dart';
import 'transport/plex_response.dart';
import 'transport/plex_retry_policy.dart';

/// What a connection and every scoped view of it share (see
/// [PlexConnection.scoped]): the HTTP client, the server URL and the
/// session.
final class _Shared {
  final http.Client client;
  final bool ownsClient;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final int jsonIsolateThreshold;
  final PlexRetryPolicy retryPolicy;

  /// Whether bodies arrive still gzipped, for the connection to inflate
  /// (true only for the default `dart:io` client, see
  /// `platform.createDefaultClient`).
  final bool inflates;
  String? baseUrl;
  String? token;
  bool closed = false;

  _Shared({
    required this.client,
    required this.ownsClient,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.jsonIsolateThreshold,
    required this.inflates,
    required this.retryPolicy,
  });
}

/// Internal HTTP transport shared by every sub-API. Not exported; the
/// public API is [PlexClient].
///
/// Built on `package:http`, so the app can hand in any [http.Client] — a
/// native one (`cupertino_http`, `cronet_http`) for HTTP/2 and the system
/// proxy, or a `MockClient` in tests.
final class PlexConnection {
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

  /// Creates a connection bound to [credentials].
  ///
  /// Without an [httpClient], one is created (and closed by [close]) with
  /// [connectTimeout] applied to the handshake. An injected client is never
  /// closed by this connection.
  ///
  /// [receiveTimeout] bounds every pause between two chunks of the body —
  /// not the whole transfer, so a long download that keeps flowing never
  /// times out. The wait for the response headers is bounded by
  /// [connectTimeout] + [receiveTimeout] together: `package:http` does not
  /// say when the connection is up, so the two cannot be told apart there.
  /// An injected [httpClient] brings its own connect timeout, if any.
  PlexConnection({
    required this.credentials,
    http.Client? httpClient,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 30),
    int jsonIsolateThreshold = defaultJsonIsolateThreshold,
    PlexRetryPolicy retryPolicy = PlexRetryPolicy.none,
  })  : _shared = _Shared(
          client: httpClient ?? platform.createDefaultClient(connectTimeout),
          ownsClient: httpClient == null,
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
          jsonIsolateThreshold: jsonIsolateThreshold,
          inflates: httpClient == null && platform.defaultClientLeavesGzip,
          retryPolicy: retryPolicy,
        ),
        scopeToken = null;

  /// A view of [parent] whose requests are cancelled by [cancelToken].
  ///
  /// The view shares [parent]'s client, credentials, base URL and token:
  /// a later `setToken` or `connect` on either is seen by both. A token
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
    Map<String, Object?>? queryParameters,
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
        exchange,
        responseType ?? PlexResponseType.json,
      );
    } on FormatException catch (e, st) {
      throw _parseError(e, st, exchange.uri);
    }
    _throwIfCancelled(cancelToken, exchange.uri);
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
    Map<String, Object?>? queryParameters,
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
    final gzipped = exchange.gzipped;
    final R result;
    try {
      result = _offIsolate(exchange)
          ? await platform.runOffIsolate(
              () => parse(_jsonOf(gzipped ? platform.gunzip(bytes) : bytes)),
            )
          : parse(_jsonOf(gzipped ? platform.gunzip(bytes) : bytes));
    } on PlexException {
      rethrow;
      // Whatever else a parser throws — a FormatException, a TypeError from
      // `as Map` on a list, a RangeError — means the body was not what the
      // parser expects: a malformed response, reported as one.
      // ignore: avoid_catching_errors
    } catch (e, st) {
      throw _parseError(e, st, exchange.uri);
    }
    _throwIfCancelled(cancelToken, exchange.uri);
    return result;
  }

  /// Convenience for byte GETs (artwork, small files). The whole body is
  /// held in memory; use [requestStream] for media.
  Future<PlexResponse<Uint8List>> requestBytes(
    String url, {
    Map<String, Object?>? queryParameters,
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
  /// streams that may stay quiet for minutes. Time the listener spends
  /// paused does not count as a stall.
  ///
  /// The connection stays open until the stream is listened to and
  /// drained or cancelled: listen to it, or cancel the subscription, even
  /// when the body is not wanted. A cancellation through the token closes
  /// it either way.
  Future<PlexStreamedResponse> requestStream(
    String url, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? extraHeaders,
    bool absoluteUrl = true,
    bool stallTimeout = true,
    PlexCancelToken? cancelToken,
  }) async {
    const method = 'GET';
    final opened = await _retrying(method, cancelToken, () async {
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
      final gzipped = _isGzipped(res.headers);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final body = await _readAll(opened);
        throw _statusError(
          res.statusCode,
          res.reasonPhrase,
          opened.uri,
          gzipped ? _tryGunzip(body) : body,
          res.headers,
        );
      }
      return opened;
    });
    final res = opened.response;
    final gzipped = _isGzipped(res.headers);
    final body = _guard(opened);
    return PlexStreamedResponse(
      stream: gzipped
          ? platform.gunzipStream(body).handleError(
                (Object e, StackTrace st) =>
                    throw _parseError(e, st, opened.uri),
                test: (e) => e is FormatException,
              )
          : body,
      statusCode: res.statusCode,
      headers: res.headers,
      contentLength: gzipped ? null : res.contentLength,
      uri: opened.uri,
    );
  }

  // ─── Internals ─────────────────────────────────────────────────────

  Future<_Exchange> _exchange(
    String path, {
    required String method,
    required Map<String, Object?>? queryParameters,
    required Object? data,
    required Map<String, String>? extraHeaders,
    required bool absoluteUrl,
    required PlexCancelToken? cancelToken,
  }) =>
      _retrying(
        method,
        cancelToken,
        () => _exchangeOnce(
          path,
          method: method,
          queryParameters: queryParameters,
          data: data,
          extraHeaders: extraHeaders,
          absoluteUrl: absoluteUrl,
          cancelToken: cancelToken,
        ),
      );

  /// Runs [attempt] under the client's [PlexRetryPolicy].
  Future<T> _retrying<T>(
    String method,
    PlexCancelToken? cancelToken,
    Future<T> Function() attempt,
  ) async {
    final token = cancelToken ?? scopeToken;
    for (var n = 1;; n++) {
      try {
        return await attempt();
      } on PlexException catch (e) {
        final wait = _shared.retryPolicy.delayAfter(
          e,
          attempt: n,
          method: method,
        );
        if (wait == null) rethrow;
        if (token != null && token.isCancelled) rethrow;
        final waited = Completer<void>();
        final timer = Timer(wait, waited.complete);
        final unregister = token?.register(() {
          timer.cancel();
          if (!waited.isCompleted) waited.complete();
        });
        await waited.future;
        unregister?.call();
        if (token != null && token.isCancelled) {
          throw _cancelled(Uri.tryParse(e.path ?? '') ?? Uri());
        }
      }
    }
  }

  Future<_Exchange> _exchangeOnce(
    String path, {
    required String method,
    required Map<String, Object?>? queryParameters,
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
    final gzipped = _isGzipped(res.headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _statusError(
        res.statusCode,
        res.reasonPhrase,
        opened.uri,
        gzipped ? _tryGunzip(bytes) : bytes,
        res.headers,
      );
    }
    return _Exchange(opened.uri, res.statusCode, res.headers, bytes, gzipped);
  }

  /// Sends the request and waits for the response headers.
  Future<_Opened> _open(
    String path, {
    required String method,
    required Map<String, Object?>? queryParameters,
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
    final Uri uri;
    try {
      uri = buildUri(absoluteUrl ? path : _resolve(path), queryParameters);
    } on FormatException catch (e, st) {
      throw PlexException(
        'Invalid request URL: ${e.message}',
        type: PlexErrorType.state,
        path: path,
        cause: e,
        stackTrace: st,
      );
    }
    final token = cancelToken ?? scopeToken;
    if (token != null && token.isCancelled) throw _cancelled(uri);

    final abort = Completer<void>();
    final request = http.AbortableRequest(
      method,
      uri,
      abortTrigger: abort.future,
    );
    request.headers.addAll(_baseHeaders);
    if (_shared.inflates) request.headers['Accept-Encoding'] = 'gzip';
    if (extraHeaders != null) request.headers.addAll(extraHeaders);
    _encodeBody(request, data);

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
    final unregister = token?.register(() => lose(_cancelled(uri)));
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
      unregister?.call();
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
    void Function()? unregister;
    var done = false;
    // One timer per body, not one per chunk: a chunk only stamps the time,
    // and the timer checks the stamp when it fires. The clock stops while
    // the listener is paused — a slow consumer is not a stalled server.
    final sinceChunk = Stopwatch();

    void finish() {
      done = true;
      stall?.cancel();
      unregister?.call();
    }

    void fail(PlexException e) {
      if (done) return;
      finish();
      opened.abort();
      // An aborted `IOClient` response closes its socket only once it is
      // listened to: drain it here when nobody has yet.
      unawaited(sub?.cancel() ?? opened.response.stream.listen(null).cancel());
      if (!out.isClosed) {
        out.addError(e, e.stackTrace);
        unawaited(out.close());
      }
    }

    void arm() {
      final timeout = opened.receiveTimeout;
      if (timeout == null || done) return;
      sinceChunk.start();
      void check() {
        final idle = timeout - sinceChunk.elapsed;
        if (idle <= Duration.zero) {
          fail(_timeout('The body stalled', uri));
        } else {
          stall = Timer(idle, check);
        }
      }

      stall = Timer(timeout - sinceChunk.elapsed, check);
    }

    out = StreamController<List<int>>(
      onListen: () {
        if (done) return;
        arm();
        sub = opened.response.stream.listen(
          (chunk) {
            sinceChunk.reset();
            out.add(chunk);
          },
          onError: (Object e, StackTrace st) =>
              fail(_transportError(e, st, uri, token)),
          onDone: () {
            finish();
            unawaited(out.close());
          },
        );
      },
      onPause: () {
        stall?.cancel();
        sinceChunk.stop();
        sub?.pause();
      },
      onResume: () {
        sub?.resume();
        arm();
      },
      onCancel: () {
        finish();
        opened.abort();
        return sub?.cancel();
      },
    );
    // Wired now, not on listen: a cancellation must also close a body that
    // nobody has listened to yet.
    if (token != null) {
      if (token.isCancelled) {
        fail(_cancelled(uri));
      } else {
        unregister = token.register(() => fail(_cancelled(uri)));
      }
    }
    return out.stream;
  }

  /// Encodes [data] into [request]: raw bytes for a `List<int>`, a form
  /// body for a `Map` when the caller set a form `Content-Type`, JSON
  /// otherwise.
  void _encodeBody(http.Request request, Object? data) {
    if (data == null) return;
    if (data is List<int>) {
      request.bodyBytes = data;
      return;
    }
    final contentType = request.headers.entries
        .where((h) => h.key.toLowerCase() == 'content-type')
        .map((h) => h.value.toLowerCase())
        .firstOrNull;
    if (data is Map &&
        contentType != null &&
        contentType.startsWith('application/x-www-form-urlencoded')) {
      request.bodyBytes = utf8.encode(_formEncode(data));
      return;
    }
    if (data is Map || data is List || data is String) {
      if (contentType == null) {
        request.headers['Content-Type'] = 'application/json';
      }
      request.bodyBytes = utf8.encode(data is String ? data : jsonEncode(data));
      return;
    }
    throw PlexException(
      'Cannot send a ${data.runtimeType} body',
      type: PlexErrorType.state,
    );
  }

  Future<Object?> _decode(_Exchange exchange, PlexResponseType type) async {
    final gzipped = exchange.gzipped;
    final raw = exchange.bytes;
    if (type == PlexResponseType.json &&
        raw.isNotEmpty &&
        _isJson(exchange.headers['content-type']) &&
        _offIsolate(exchange)) {
      // Inflate and decode together, away from the caller.
      return platform.runOffIsolate(
        () => _jsonOf(gzipped ? platform.gunzip(raw) : raw),
      );
    }
    final bytes = gzipped ? platform.gunzip(raw) : raw;
    switch (type) {
      case PlexResponseType.bytes:
        return bytes;
      case PlexResponseType.plain:
        return utf8.decode(bytes, allowMalformed: true);
      case PlexResponseType.json:
        if (bytes.isEmpty) return null;
        if (!_isJson(exchange.headers['content-type'])) {
          return utf8.decode(bytes, allowMalformed: true);
        }
        return _jsonOf(bytes);
    }
  }

  /// Whether [exchange] is big enough to decode on another isolate. A gzip
  /// body is judged by a conservative guess at its inflated size: JSON
  /// lists compress about 15:1, so ×8 errs towards the isolate.
  bool _offIsolate(_Exchange exchange) {
    if (!platform.canUseIsolates) return false;
    final size = exchange.bytes.length * (exchange.gzipped ? 8 : 1);
    return size >= _shared.jsonIsolateThreshold;
  }

  /// Whether the body is still gzipped — only ever true on the default
  /// client, which leaves bodies compressed for this connection to inflate.
  bool _isGzipped(Map<String, String> headers) =>
      _shared.inflates &&
      (headers['content-encoding']?.toLowerCase().contains('gzip') ?? false);

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

  /// Appends [queryParameters] to [url] the way the 0.1 transport (Dio)
  /// did: keys and values are form-encoded (`encodeQueryComponent`, so a
  /// space is `+`), a list repeats its key once per element, a `null`
  /// value sends the bare key, and a map nests as `key[sub]=value` —
  /// Plex's own form for `prefs`, `hints` and `params`.
  @visibleForTesting
  static Uri buildUri(String url, Map<String, Object?>? queryParameters) {
    final qp = queryParameters;
    if (qp == null || qp.isEmpty) return Uri.parse(url).normalizePath();
    final query = _encodePairs(qp, repeatLists: true);
    if (query.isEmpty) return Uri.parse(url).normalizePath();
    final sep = url.contains('?') ? '&' : '?';
    return Uri.parse('$url$sep$query').normalizePath();
  }

  /// A form body (`application/x-www-form-urlencoded`) for [data], with
  /// the same rules as the query string.
  static String _formEncode(Map<Object?, Object?> data) =>
      _encodePairs(data, repeatLists: true);

  /// `k=v&k2=v2`, every key and value form-encoded. A top-level list
  /// repeats its key when [repeatLists]; a nested map or list is written
  /// `key[sub]` / `key[index]`.
  static String _encodePairs(
    Map<Object?, Object?> map, {
    required bool repeatLists,
  }) {
    final parts = <String>[];
    void add(String key, Object? value, {required bool top}) {
      if (value is Map) {
        value.forEach((k, v) => add('$key[$k]', v, top: false));
      } else if (value is Iterable) {
        var i = 0;
        for (final e in value) {
          add(top && repeatLists ? key : '$key[${i++}]', e, top: false);
        }
      } else if (value == null) {
        parts.add(Uri.encodeQueryComponent(key));
      } else {
        parts.add(
          '${Uri.encodeQueryComponent(key)}='
          '${Uri.encodeQueryComponent('$value')}',
        );
      }
    }

    map.forEach((k, v) => add('$k', v, top: true));
    return parts.join('&');
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
    Map<String, String> headers,
  ) {
    final text = body.isEmpty
        ? ''
        : ': ${utf8.decode(body.length > 512 ? body.sublist(0, 512) : body, allowMalformed: true)}';
    return PlexException(
      'HTTP $status${reason == null || reason.isEmpty ? '' : ' $reason'}$text',
      type: PlexErrorType.fromHttpStatus(status),
      statusCode: status,
      path: uri.toString(),
      retryAfter: _retryAfter(headers['retry-after']),
    );
  }

  /// `Retry-After` in seconds; `null` when absent or not a number (the
  /// HTTP-date form is not read — neither server sends it). Clamped to
  /// `[0, 1 day]` so an absurd value cannot overflow [Duration].
  static Duration? _retryAfter(String? value) {
    final seconds = value == null ? null : int.tryParse(value.trim());
    if (seconds == null) return null;
    return Duration(seconds: seconds.clamp(0, _maxRetryAfterSeconds));
  }

  static const int _maxRetryAfterSeconds = 24 * 60 * 60;

  /// Inflates an error body for its message; the raw bytes when it is not
  /// really gzip, so a lying header cannot hide the status.
  static Uint8List _tryGunzip(Uint8List bytes) {
    try {
      return platform.gunzip(bytes);
    } on FormatException {
      return bytes;
    }
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
    if (_shared.closed) {
      return PlexException(
        'PlexClient.close() was called while the request was in flight.',
        type: PlexErrorType.state,
        path: uri.toString(),
        cause: e,
        stackTrace: st,
      );
    }
    if (e is TimeoutException) return _timeout('$e', uri, e, st);
    final text = '$e';
    // A redirect loop is an answer, not a lost connection: not retried.
    final type = text.contains('timed out')
        ? PlexErrorType.timeout
        : e is http.ClientException && text.contains('Redirect')
            ? PlexErrorType.unknown
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

  /// Throws a cancellation when the token for this request was cancelled
  /// while its body was being decoded.
  void _throwIfCancelled(PlexCancelToken? cancelToken, Uri uri) {
    final token = cancelToken ?? scopeToken;
    if (token != null && token.isCancelled) throw _cancelled(uri);
  }

  static PlexException _cancelled(Uri uri) => PlexException(
        'Request cancelled',
        type: PlexErrorType.cancelled,
        path: uri.toString(),
      );
}

/// Decodes a JSON body; `null` when empty. Top-level so it can run on
/// another isolate.
///
/// The fused UTF-8 + JSON decoder parses straight from the bytes, without
/// first building the whole body as a `String`: about half the time of
/// `jsonDecode(utf8.decode(bytes))` on a 1.5 MB Jellyfin page.
Object? _jsonOf(Uint8List bytes) =>
    bytes.isEmpty ? null : _utf8Json.convert(bytes);

final Converter<List<int>, Object?> _utf8Json =
    const Utf8Decoder().fuse(const JsonDecoder());

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

  /// The body as received: still gzipped when [gzipped].
  final Uint8List bytes;
  final bool gzipped;

  _Exchange(this.uri, this.statusCode, this.headers, this.bytes, this.gzipped);
}
