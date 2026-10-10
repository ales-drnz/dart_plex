// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The transport: wire shape, error classification, timeouts, cancellation
/// and off-isolate parsing. Everything here runs against an in-process
/// `http.Client`, so a failure is the transport's and not the network's.
library;

import 'dart:async';
import 'dart:convert';
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

void main() {
  group('query encoding (unchanged from the Dio transport)', () {
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
      expect(e.isRetriable, isTrue);
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
        view.playlists.items('p1'),
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
      expect(PlexConnection.jsonIsolateThreshold, greaterThan(0));
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

  group('client ownership', () {
    test('an injected client is not closed', () {
      final client = _FnClient((_) => throw UnimplementedError());
      _connection(client).close();
      expect(client.closed, isFalse);
    });
  });
}
