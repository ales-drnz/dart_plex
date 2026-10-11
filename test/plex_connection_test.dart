// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The transport: wire shape, error classification, timeouts, cancellation
/// and off-isolate parsing. Everything here runs against an in-process
/// `http.Client`, so a failure is the transport's and not the network's.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_plex/dart_plex.dart';
import 'package:dart_plex/src/plex_connection.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

const _credentials = testCredentials;

/// A client whose [send] is whatever the test says.
class _FnClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  bool closed = false;

  _FnClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);

  @override
  void close() => closed = true;
}

PlexConnection _connection(
  http.Client client, {
  Duration connectTimeout = const Duration(seconds: 15),
  Duration receiveTimeout = const Duration(seconds: 30),
  int jsonIsolateThreshold = PlexConnection.defaultJsonIsolateThreshold,
}) =>
    PlexConnection(
      credentials: _credentials,
      httpClient: client,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      jsonIsolateThreshold: jsonIsolateThreshold,
    )..baseUrl = 'https://pms.example.test/';

/// The [PlexException] that [call] fails with.
Future<PlexException> _caught(Future<Object?> call) async {
  try {
    await call;
  } on PlexException catch (e) {
    return e;
  }
  throw StateError('the call succeeded');
}

void main() {
  group('query encoding (as the 0.1 Dio transport sent it)', () {
    Uri build(Map<String, dynamic> qp, [String url = 'https://h/p']) =>
        PlexConnection.buildUri(url, qp);

    test('keys and string values are form-encoded', () {
      final uri = build({'searchTerm': 'Rock & Roll/2', 'year>>': '2009'});
      expect(uri.query, 'searchTerm=Rock+%26+Roll%2F2&year%3E%3E=2009');
      expect(uri.queryParameters['searchTerm'], 'Rock & Roll/2');
    });

    test('a list repeats its key once per element', () {
      final uri = build({
        'genreIds': ['a', 'b,c'],
      });
      expect(uri.query, 'genreIds=a&genreIds=b%2Cc');
      expect(uri.queryParametersAll['genreIds'], ['a', 'b,c']);
    });

    test('numbers and booleans are sent as their toString', () {
      expect(
        build({'limit': 50, 'recursive': true}).query,
        'limit=50&recursive=true',
      );
    });

    test('a null value sends the bare key', () {
      expect(build({'flag': null}).query, 'flag');
    });

    test('a map nests as key[sub]=value, every part encoded', () {
      final uri = build({
        'prefs': {'k 1': 'v&1', 'n': 2},
      });
      expect(uri.query, 'prefs%5Bk+1%5D=v%261&prefs%5Bn%5D=2');
      expect(uri.queryParameters, {'prefs[k 1]': 'v&1', 'prefs[n]': '2'});
    });

    test('a non-string value is encoded too', () {
      final uri = build({'at': DateTime.utc(2026, 1, 2, 3, 4, 5)});
      expect(uri.queryParameters['at'], '2026-01-02 03:04:05.000Z');
      expect(uri.query, isNot(contains(' ')));
      expect(build({'x': '#&='}).queryParameters, {'x': '#&='});
    });

    test('appends to a URL that already has a query', () {
      expect(
        build({'b': '2'}, 'https://h/p?a=1').toString(),
        'https://h/p?a=1&b=2',
      );
    });
  });

  group('requests', () {
    late CapturingAdapter adapter;
    late PlexConnection conn;

    setUp(() {
      adapter = CapturingAdapter();
      conn = _connection(adapter);
    });

    test('resolves against the base URL and sends the identity', () async {
      conn.token = 'tok';
      await conn.request<void>('/identity');
      expect(adapter.last!.uri.toString(), 'https://pms.example.test/identity');
      expect(adapter.last!.headers['Accept'], 'application/json');
      expect(adapter.last!.headers['X-Plex-Token'], 'tok');
      expect(adapter.last!.headers['X-Plex-Client-Identifier'], 'test-uuid');
    });

    test('no token, no X-Plex-Token header', () async {
      await conn.request<void>('/identity');
      expect(adapter.last!.headers.containsKey('X-Plex-Token'), isFalse);
    });

    test('a Map body travels as JSON', () async {
      await conn.request<void>('/x', method: 'POST', data: {'A': 1});
      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.headers['Content-Type'], 'application/json');
      expect(adapter.last!.json, {'A': 1});
    });

    test('a Map body with a form content type travels form-encoded', () async {
      await conn.request<void>(
        '/x',
        method: 'POST',
        data: {'user[login]': 'me', 'user[password]': 'p&w d'},
        extraHeaders: const {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );
      expect(
        adapter.last!.headers['Content-Type'],
        'application/x-www-form-urlencoded',
      );
      expect(
        utf8.decode(adapter.last!.body),
        'user%5Blogin%5D=me&user%5Bpassword%5D=p%26w+d',
      );
    });

    test('a byte body travels as-is and extra headers win', () async {
      await conn.request<void>(
        '/x',
        method: 'POST',
        data: [1, 2, 3],
        extraHeaders: const {'Content-Type': 'application/octet-stream'},
      );
      expect(adapter.last!.body, [1, 2, 3]);
      expect(
        adapter.last!.headers['Content-Type'],
        'application/octet-stream',
      );
    });

    test('decodes JSON, text and bytes', () async {
      adapter.respond = (r) => switch (r.uri.path) {
            '/json' => CannedResponse.json({'k': 'v'}),
            '/text' => CannedResponse(
                200,
                utf8.encode('hello'),
                contentType: 'text/css',
              ),
            _ => CannedResponse(200, [9, 8], contentType: 'image/jpeg'),
          };
      final json = await conn.request<Map<String, dynamic>>('/json');
      expect(json.data, {'k': 'v'});
      final text = await conn.request<String>('/text');
      expect(text.data, 'hello');
      final bytes = await conn.requestBytes('/img', absoluteUrl: false);
      expect(bytes.data, [9, 8]);
      expect(bytes.contentType, 'image/jpeg');
    });

    test('an empty body is null', () async {
      adapter.respond = (_) => CannedResponse(204, const []);
      final res = await conn.request<Map<String, dynamic>>('/x');
      expect(res.data, isNull);
      expect(res.statusCode, 204);
    });
  });

  group('errors', () {
    late CapturingAdapter adapter;
    late PlexConnection conn;

    setUp(() {
      adapter = CapturingAdapter();
      conn = _connection(adapter);
    });

    Future<PlexException> failure(Future<Object?> f) async {
      try {
        await f;
      } on PlexException catch (e) {
        return e;
      }
      fail('expected a PlexException');
    }

    for (final (status, type) in [
      (400, PlexErrorType.badRequest),
      (401, PlexErrorType.auth),
      (403, PlexErrorType.auth),
      (404, PlexErrorType.notFound),
      (500, PlexErrorType.serverError),
      (503, PlexErrorType.serverError),
    ]) {
      test('HTTP $status is $type', () async {
        adapter.respond = (_) => CannedResponse(status, utf8.encode('nope'));
        final e = await failure(conn.request<void>('/x'));
        expect(e.type, type);
        expect(e.statusCode, status);
        expect(e.path, 'https://pms.example.test/x');
        expect(e.message, contains('nope'));
      });
    }

    test('malformed JSON is a parse error', () async {
      adapter.respond = (_) => CannedResponse(200, utf8.encode('{nope'));
      final e = await failure(conn.request<Map<String, dynamic>>('/x'));
      expect(e.type, PlexErrorType.parse);
    });

    test('a body of the wrong shape is a parse error', () async {
      adapter.respond = (_) => CannedResponse.json([1, 2]);
      final e = await failure(conn.request<Map<String, dynamic>>('/x'));
      expect(e.type, PlexErrorType.parse);
    });

    test('a transport failure is a connection error', () async {
      final conn = _connection(
        _FnClient((r) async => throw http.ClientException('refused', r.url)),
      );
      final e = await failure(conn.request<void>('/x'));
      expect(e.type, PlexErrorType.connection);
      expect(e.isNetworkFailure, isTrue);
    });

    test('no response headers within the timeout is a timeout', () async {
      final conn = _connection(
        _FnClient((_) => Completer<http.StreamedResponse>().future),
        connectTimeout: const Duration(milliseconds: 20),
        receiveTimeout: const Duration(milliseconds: 20),
      );
      final e = await failure(conn.request<void>('/x'));
      expect(e.type, PlexErrorType.timeout);
    });

    test('a body that stalls is a timeout', () async {
      final body = StreamController<List<int>>();
      final conn = _connection(
        _FnClient((r) async {
          body.add([1]);
          return http.StreamedResponse(body.stream, 200);
        }),
        receiveTimeout: const Duration(milliseconds: 30),
      );
      final e = await failure(conn.request<void>('/x'));
      expect(e.type, PlexErrorType.timeout);
      await body.close();
    });

    test('a body that keeps flowing never times out', () async {
      final conn = _connection(
        _FnClient((r) async {
          final chunks = Stream<List<int>>.periodic(
            const Duration(milliseconds: 10),
            (i) => [i],
          ).take(8);
          return http.StreamedResponse(chunks, 200);
        }),
        receiveTimeout: const Duration(milliseconds: 40),
      );
      final res = await conn.requestBytes('/x', absoluteUrl: false);
      expect(res.data, hasLength(8));
    });

    test('use after close is a state error', () async {
      conn.close();
      final e = await failure(conn.request<void>('/x'));
      expect(e.type, PlexErrorType.state);
    });
  });

  group('cancellation', () {
    test('a token cancelled before the call fails it at once', () async {
      final adapter = CapturingAdapter();
      final conn = _connection(adapter);
      final token = PlexCancelToken()..cancel();
      await expectLater(
        conn.request<void>('/x', cancelToken: token),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.cancelled),
        ),
      );
      // The capturing client records only after reading the body: give a
      // request that did go out the time to show up.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(adapter.requests, isEmpty);
    });

    test('cancelling while waiting for headers aborts the request', () async {
      http.BaseRequest? sent;
      final conn = _connection(
        _FnClient((r) {
          sent = r;
          return Completer<http.StreamedResponse>().future;
        }),
      );
      final token = PlexCancelToken();
      final call = conn.request<void>('/x', cancelToken: token);
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      await expectLater(
        call,
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.cancelled),
        ),
      );
      // The abort trigger reached the client, so a real one closes the socket.
      final trigger = (sent! as http.Abortable).abortTrigger;
      await expectLater(trigger, completes);
    });

    test('cancelling mid-body fails the read', () async {
      final body = StreamController<List<int>>();
      final conn = _connection(
        _FnClient((r) async => http.StreamedResponse(body.stream, 200)),
      );
      final token = PlexCancelToken();
      final call =
          conn.requestBytes('/x', absoluteUrl: false, cancelToken: token);
      await Future<void>.delayed(Duration.zero);
      body.add([1, 2]);
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      await expectLater(
        call,
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.cancelled),
        ),
      );
      await body.close();
    });

    test('withCancelToken cancels every sub-API call of the view', () async {
      final pending = <Completer<http.StreamedResponse>>[];
      final client = PlexClient(
        credentials: _credentials,
        httpClient: _FnClient((_) {
          final c = Completer<http.StreamedResponse>();
          pending.add(c);
          return c.future;
        }),
      )..connect('https://pms.example.test', accessToken: 't');
      final token = PlexCancelToken();
      final view = client.withCancelToken(token);
      final calls = [
        view.library.allByType(
          sectionId: '1',
          type: PlexMetadataType.album,
        ),
        view.playlists.items(playlistId: 'p1'),
        view.hubs.global(),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(pending, hasLength(3));
      token.cancel();
      for (final call in calls) {
        await expectLater(
          call,
          throwsA(
            isA<PlexException>()
                .having((e) => e.type, 'type', PlexErrorType.cancelled),
          ),
        );
      }
    });

    test('a view shares the session and leaves the parent alone', () async {
      final adapter = CapturingAdapter();
      final client = PlexClient(credentials: _credentials, httpClient: adapter)
        ..connect('https://pms.example.test');
      final token = PlexCancelToken();
      final view = client.withCancelToken(token);
      client.setToken('late-token');
      expect(view.token, 'late-token');
      await view.request<void>('/identity');
      expect(adapter.last!.headers['X-Plex-Token'], 'late-token');
      token.cancel();
      expect(identical(view.notifications, client.notifications), isTrue);
      // The parent is not bound to the view's token.
      await client.request<void>('/identity');
      expect(adapter.requests, hasLength(2));
    });
  });

  group('off-isolate parsing', () {
    test('requestJson parses on another isolate above the threshold', () async {
      final adapter = CapturingAdapter()
        ..respond = (_) => CannedResponse.json({'n': 1});
      final conn = _connection(adapter, jsonIsolateThreshold: 0);
      final here = Isolate.current.debugName;
      final where = await conn.requestJson<String?>(
        '/x',
        (json) => Isolate.current.debugName,
      );
      expect(where, isNot(here));
    });

    test('below the threshold it parses in place', () async {
      final adapter = CapturingAdapter()
        ..respond = (_) => CannedResponse.json({'n': 1});
      final conn = _connection(adapter);
      final here = Isolate.current.debugName;
      final where = await conn.requestJson<String?>(
        '/x',
        (json) => Isolate.current.debugName,
      );
      expect(where, here);
    });

    test('a parse that throws a TypeError is a parse error', () async {
      final adapter = CapturingAdapter()
        ..respond = (_) => CannedResponse.json([1]);
      final conn = _connection(adapter, jsonIsolateThreshold: 0);
      await expectLater(
        conn.requestJson<int>('/x', (json) => (json! as Map)['n'] as int),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.parse),
        ),
      );
    });

    test('the default threshold is positive', () {
      expect(PlexConnection.defaultJsonIsolateThreshold, greaterThan(0));
      expect(
        _connection(CapturingAdapter()).effectiveJsonIsolateThreshold,
        PlexConnection.defaultJsonIsolateThreshold,
      );
    });
  });

  group('streaming', () {
    test('requestStream delivers the body chunk by chunk', () async {
      final conn = _connection(
        _FnClient(
          (r) async => http.StreamedResponse(
            Stream.fromIterable([
              [1, 2],
              [3],
            ]),
            200,
            contentLength: 3,
          ),
        ),
      );
      final res = await conn.requestStream('/dl', absoluteUrl: false);
      expect(res.contentLength, 3);
      expect(await res.stream.toList(), [
        [1, 2],
        [3],
      ]);
    });

    test('requestStream throws on a non-2xx status', () async {
      final adapter = CapturingAdapter()
        ..respond = (_) => CannedResponse(404, const []);
      final conn = _connection(adapter);
      await expectLater(
        conn.requestStream('/dl', absoluteUrl: false),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.notFound),
        ),
      );
    });
  });

  group('the default client (real sockets)', () {
    late HttpServer server;
    var gzipped = 0;
    late PlexConnection conn;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final gz =
            (req.headers.value('accept-encoding') ?? '').contains('gzip');
        final body = utf8.encode(
          jsonEncode({
            'Items': [
              for (var i = 0; i < 200; i++) {'Name': 'Track $i'},
            ],
          }),
        );
        req.response.headers.contentType = ContentType.json;
        if (gz && req.uri.path != '/plain') {
          gzipped++;
          req.response.headers.set('content-encoding', 'gzip');
          req.response.add(gzip.encode(body));
        } else {
          req.response.add(body);
        }
        await req.response.close();
      });
      conn = PlexConnection(
        credentials: _credentials,
        jsonIsolateThreshold: 1024,
      )..baseUrl = 'http://127.0.0.1:${server.port}';
    });

    tearDown(() async {
      conn.close();
      await server.close(force: true);
    });

    test('asks for gzip and inflates it off the caller', () async {
      final res = await conn.request<Map<String, dynamic>>('/gz');
      expect((res.data!['Items'] as List).length, 200);
      final here = Isolate.current.debugName;
      final where = await conn.requestJson<String?>(
        '/gz',
        (json) =>
            (json! as Map)['Items'] is List ? Isolate.current.debugName : null,
      );
      expect(where, isNot(here));
      expect(gzipped, 2, reason: 'both answers really travelled gzipped');
    });

    test('an uncompressed answer is read as-is', () async {
      final res = await conn.request<Map<String, dynamic>>('/plain');
      expect((res.data!['Items'] as List).length, 200);
    });

    test('requestStream inflates as it goes', () async {
      final res = await conn.requestStream('/gz', absoluteUrl: false);
      expect(res.contentLength, isNull);
      final text = await utf8.decodeStream(res.stream);
      expect((jsonDecode(text) as Map)['Items'], hasLength(200));
    });
  });

  group('classification getters (same in both libraries)', () {
    PlexException e(PlexErrorType type, [int? status]) =>
        PlexException('x', type: type, statusCode: status);

    test('network failure, transient, not found, cancelled', () {
      // (exception, networkFailure, transient, notFound, cancelled)
      final table = [
        (e(PlexErrorType.connection), true, true, false, false),
        (e(PlexErrorType.timeout), true, true, false, false),
        (e(PlexErrorType.serverError, 503), false, true, false, false),
        (e(PlexErrorType.badRequest, 429), false, true, false, false),
        (e(PlexErrorType.badRequest, 400), false, false, false, false),
        (e(PlexErrorType.auth, 401), false, false, false, false),
        (e(PlexErrorType.notFound, 404), false, false, true, false),
        (e(PlexErrorType.parse), false, false, false, false),
        (e(PlexErrorType.state), false, false, false, false),
        (e(PlexErrorType.cancelled), false, false, false, true),
      ];
      for (final (ex, network, transient, notFound, cancelled) in table) {
        expect(ex.isNetworkFailure, network, reason: '$ex');
        expect(ex.isTransient, transient, reason: '$ex');
        expect(ex.isNotFound, notFound, reason: '$ex');
        expect(ex.isCancelled, cancelled, reason: '$ex');
        expect(ex.isNetworkFailure, network, reason: '$ex');
      }
    });
  });

  group('retry policy', () {
    const fast = PlexRetryPolicy(
      initialDelay: Duration(milliseconds: 1),
      maxDelay: Duration(milliseconds: 20),
    );

    (PlexConnection, List<String>) flaky(
      List<int> statuses, {
      PlexRetryPolicy policy = fast,
      Map<String, String> headers = const {},
    }) {
      final seen = <String>[];
      var i = 0;
      final conn = PlexConnection(
        credentials: _credentials,
        httpClient: _FnClient((r) async {
          seen.add(r.method);
          final status =
              statuses[i < statuses.length ? i : statuses.length - 1];
          i++;
          return http.StreamedResponse(
            Stream.value(utf8.encode('{}')),
            status,
            headers: {'content-type': 'application/json', ...headers},
          );
        }),
        retryPolicy: policy,
      )..baseUrl = 'https://h.test';
      return (conn, seen);
    }

    test('off by default', () async {
      final seen = <int>[];
      final conn = _connection(
        _FnClient((r) async {
          seen.add(1);
          return http.StreamedResponse(const Stream.empty(), 503);
        }),
      );
      await expectLater(
        conn.request<void>('/x'),
        throwsA(isA<PlexException>()),
      );
      expect(seen, hasLength(1));
    });

    test('a GET is resent after 502/503/504/429 until it succeeds', () async {
      final (conn, seen) = flaky([503, 502, 200]);
      final res = await conn.request<Map<String, dynamic>>('/x');
      expect(res.statusCode, 200);
      expect(seen, ['GET', 'GET', 'GET']);
      final (conn2, seen2) = flaky([429, 504, 200]);
      await conn2.request<void>('/x');
      expect(seen2, hasLength(3));
    });

    test('it stops at maxAttempts and throws the last failure', () async {
      final (conn, seen) = flaky([503]);
      await expectLater(
        conn.request<void>('/x'),
        throwsA(
          isA<PlexException>().having((e) => e.statusCode, 'status', 503),
        ),
      );
      expect(seen, hasLength(3));
    });

    test('a 500, a 4xx and a non-idempotent request are not resent', () async {
      for (final (status, method) in [
        (500, 'GET'),
        (404, 'GET'),
        (503, 'POST'),
      ]) {
        final (conn, seen) = flaky([status, 200]);
        await expectLater(
          conn.request<void>('/x', method: method),
          throwsA(isA<PlexException>()),
        );
        expect(seen, hasLength(1), reason: '$status $method');
      }
    });

    test('network failures are resent too', () async {
      var calls = 0;
      final conn = PlexConnection(
        credentials: _credentials,
        httpClient: _FnClient((r) async {
          if (calls++ == 0) throw http.ClientException('reset', r.url);
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
        }),
        retryPolicy: fast,
      )..baseUrl = 'https://h.test';
      await conn.request<void>('/x');
      expect(calls, 2);
    });

    test('Retry-After is read and capped at maxDelay', () async {
      final (conn, _) = flaky([503], headers: {'retry-after': '7'});
      try {
        await conn.request<void>('/x');
      } on PlexException catch (e) {
        expect(e.retryAfter, const Duration(seconds: 7));
      }
      const e = PlexException(
        'x',
        type: PlexErrorType.serverError,
        statusCode: 503,
        retryAfter: Duration(seconds: 7),
      );
      expect(
        fast.delayAfter(e, attempt: 1, method: 'GET'),
        const Duration(milliseconds: 20),
      );
    });

    test('an absurd Retry-After or attempt count never goes negative', () {
      const huge = PlexException(
        'x',
        type: PlexErrorType.serverError,
        statusCode: 503,
        retryAfter: Duration(days: 1),
      );
      expect(fast.delayAfter(huge, attempt: 1, method: 'GET'), fast.maxDelay);
      const many = PlexRetryPolicy(maxAttempts: 1000);
      const net = PlexException('x', type: PlexErrorType.connection);
      for (final n in [46, 60, 64, 70, 500]) {
        final d = many.delayAfter(net, attempt: n, method: 'GET')!;
        expect(d.isNegative, isFalse, reason: 'attempt $n');
        expect(d <= many.maxDelay, isTrue, reason: 'attempt $n');
      }
    });

    test('cancelling during the wait ends the retries', () async {
      final (conn, seen) = flaky(
        [503, 200],
        policy: const PlexRetryPolicy(initialDelay: Duration(seconds: 30)),
        headers: {'retry-after': '30'},
      );
      final token = PlexCancelToken();
      final call = conn.request<void>('/x', cancelToken: token);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel();
      await expectLater(
        call,
        throwsA(
          isA<PlexException>().having((e) => e.isCancelled, 'cancelled', true),
        ),
      );
      expect(seen, hasLength(1));
    });
  });

  group('cancel token bookkeeping', () {
    test('finished requests leave no callback on a long-lived token', () async {
      final adapter = CapturingAdapter();
      final conn = _connection(adapter);
      final token = PlexCancelToken();
      for (var i = 0; i < 50; i++) {
        await conn.request<void>('/x', cancelToken: token);
      }
      await conn
          .requestStream(
            '/x',
            absoluteUrl: false,
            cancelToken: token,
          )
          .then((r) => r.stream.drain<void>());
      expect(token.listenerCount, 0);
    });

    test('a failed request unregisters too', () async {
      final conn = _connection(
        CapturingAdapter()..respond = (_) => CannedResponse(500, const []),
      );
      final token = PlexCancelToken();
      await expectLater(
        conn.request<void>('/x', cancelToken: token),
        throwsA(isA<PlexException>()),
      );
      expect(token.listenerCount, 0);
    });

    test('cancelling while the body is decoded still cancels', () async {
      final token = PlexCancelToken();
      final conn = _connection(
        BytesAdapter(utf8.encode('{"a":1}'), contentType: 'application/json'),
      );
      await expectLater(
        conn.requestJson<int>(
          '/x',
          (json) {
            token.cancel();
            return 1;
          },
          cancelToken: token,
        ),
        throwsA(
          isA<PlexException>().having((e) => e.isCancelled, 'cancelled', true),
        ),
      );
    });

    test('a cancelled stream nobody listened to is closed', () async {
      final body = StreamController<List<int>>();
      var listened = false;
      body.onListen = () => listened = true;
      final conn = _connection(
        _FnClient((r) async => http.StreamedResponse(body.stream, 200)),
      );
      final token = PlexCancelToken();
      await conn.requestStream('/x', absoluteUrl: false, cancelToken: token);
      token.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(listened, isTrue, reason: 'the body is drained to free it');
      await body.close();
    });
  });

  group('stall timeout and back-pressure', () {
    test('time the listener spends paused is not a stall', () async {
      final body = StreamController<List<int>>();
      final conn = _connection(
        _FnClient((r) async => http.StreamedResponse(body.stream, 200)),
        receiveTimeout: const Duration(milliseconds: 100),
      );
      final res = await conn.requestStream('/x', absoluteUrl: false);
      final got = <int>[];
      // ignore: cancel_subscriptions
      final sub = res.stream.listen(got.addAll);
      body.add([1]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      sub.pause();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      sub.resume();
      body.add([2]);
      await body.close();
      await sub.asFuture<void>();
      expect(got, [1, 2]);
    });

    test('a server that stalls while the listener reads still times out',
        () async {
      final body = StreamController<List<int>>();
      final conn = _connection(
        _FnClient((r) async => http.StreamedResponse(body.stream, 200)),
        receiveTimeout: const Duration(milliseconds: 50),
      );
      final res = await conn.requestStream('/x', absoluteUrl: false);
      body.add([1]);
      await expectLater(
        res.stream.drain<void>(),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.timeout),
        ),
      );
      await body.close();
    });
  });

  group('failures that used to escape untyped', () {
    test('a parser that throws anything is a parse error', () async {
      final conn = _connection(CapturingAdapter({'a': 1}));
      await expectLater(
        conn.requestJson<int>('/x', (_) => throw RangeError('x')),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.parse),
        ),
      );
    });

    test('a malformed URL is a state error', () async {
      final conn = _connection(CapturingAdapter());
      await expectLater(
        conn.request<void>('http://[bad', absoluteUrl: true),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.state),
        ),
      );
    });

    test(
        'closing the client mid-request is a state error, not a network '
        'failure', () async {
      final pending = Completer<http.StreamedResponse>();
      late PlexConnection conn;
      conn = _connection(
        _FnClient((_) {
          scheduleMicrotask(() {
            conn.close();
            pending.completeError(http.ClientException('Connection closed'));
          });
          return pending.future;
        }),
      );
      final e = await _caught(conn.request<void>('/x'));
      expect(e.type, PlexErrorType.state);
      expect(e.isNetworkFailure, isFalse);
    });

    test('a redirect loop is not a network failure', () async {
      final conn = _connection(
        _FnClient(
          (r) async => throw http.ClientException(
            'Redirect limit exceeded',
            r.url,
          ),
        ),
      );
      final e = await _caught(conn.request<void>('/x'));
      expect(e.isNetworkFailure, isFalse);
    });
  });

  group('gzip on the default client', () {
    late HttpServer server;
    late PlexConnection conn;
    final json = utf8.encode(jsonEncode({'a': List.filled(500, 'x')}));

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final res = req.response..headers.contentType = ContentType.json;
        res.headers.set('content-encoding', 'gzip');
        switch (req.uri.path) {
          case '/error-not-gzip':
            res.statusCode = 500;
            res.add(utf8.encode('plain failure'));
          case '/truncated':
            final gz = gzip.encode(json);
            res.add(gz.sublist(0, gz.length - 4));
          default:
            res.add(gzip.encode(json));
        }
        await res.close();
      });
      conn = PlexConnection(credentials: _credentials)
        ..baseUrl = 'http://127.0.0.1:${server.port}';
    });

    tearDown(() async {
      conn.close();
      await server.close(force: true);
    });

    test('an error body that is not really gzip keeps its status', () async {
      final e = await _caught(conn.request<void>('/error-not-gzip'));
      expect(e.statusCode, 500);
      expect(e.message, contains('plain failure'));
    });

    test('a gzip body cut short is a parse error, not a short answer',
        () async {
      await expectLater(
        conn.request<Object?>('/truncated'),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.parse),
        ),
      );
      final res = await conn.requestStream('/truncated', absoluteUrl: false);
      await expectLater(
        res.stream.drain<void>(),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.parse),
        ),
      );
    });
  });

  group('client ownership', () {
    test('an injected client is not closed', () {
      final client = _FnClient((_) => throw UnimplementedError());
      _connection(client).close();
      expect(client.closed, isFalse);
    });
  });
}
