// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

const _token = 'secret-token-123';

/// A server on a loopback port that hands every request to [handler].
Future<HttpServer> _serve(
  FutureOr<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen(handler);
  return server;
}

/// Upgrades [request]; the socket is closed when the test ends.
Future<WebSocket> _upgrade(HttpRequest request) async {
  final socket = await WebSocketTransformer.upgrade(request);
  addTearDown(socket.close);
  return socket;
}

PlexNotificationsApi _api(HttpServer server) => PlexNotificationsApi(
  testConnection(CapturingAdapter())
    ..baseUrl = 'http://127.0.0.1:${server.port}'
    ..token = _token,
);

Matcher _throwsPlex(PlexErrorType type) =>
    throwsA(isA<PlexException>().having((e) => e.type, 'type', type));

String _playing(String ratingKey, {bool wrapped = true}) {
  final container = {
    'type': 'playing',
    'size': 1,
    'PlaySessionStateNotification': [
      {'ratingKey': ratingKey, 'state': 'playing'},
    ],
  };
  return jsonEncode(wrapped ? {'NotificationContainer': container} : container);
}

void main() {
  group('PlexNotificationsApi.connectWebSocket', () {
    test('opens the route with the token and filter, and decodes', () async {
      final uri = Completer<Uri>();
      final server = await _serve((request) async {
        uri.complete(request.uri);
        (await _upgrade(request))
          ..add(_playing('1'))
          ..add(_playing('2', wrapped: false));
      });
      final api = _api(server);

      final stream = await api.connectWebSocket(filter: 'playing');
      expect(api.isWebSocketConnected, isTrue);
      final received = await stream.take(2).toList();

      expect((await uri.future).path, '/:/websockets/notifications');
      expect((await uri.future).queryParameters, {
        'X-Plex-Token': _token,
        'filter': 'playing',
      });
      expect(received.map((n) => n.type), ['playing', 'playing']);
      expect(
        received.expand((n) => n.events).map((e) {
          return (e as PlexPlaySessionEvent).ratingKey;
        }),
        ['1', '2'],
      );
      // `take` cancelled the only subscription, which closes the socket.
      expect(api.isWebSocketConnected, isFalse);
    });

    test('malformed and binary frames are dropped and counted', () async {
      final server = await _serve((request) async {
        (await _upgrade(request))
          ..add('{not json')
          ..add('[1, 2]')
          ..add([1, 2, 3])
          ..add(_playing('7'));
      });
      final api = _api(server);
      final errors = <Object>[];
      final got = Completer<PlexNotification>();

      final stream = await api.connectWebSocket();
      final sub = stream.listen(got.complete, onError: errors.add);
      final notification = await got.future.timeout(const Duration(seconds: 5));

      expect(notification.type, 'playing');
      expect(errors, isEmpty);
      expect(api.malformedFrameCount, 3);
      await sub.cancel();
    });

    test('without a token is a state error', () async {
      final api = PlexNotificationsApi(testConnection(CapturingAdapter()));

      await expectLater(
        api.connectWebSocket(),
        _throwsPlex(PlexErrorType.state),
      );
    });
  });

  group('PlexNotificationsApi.connectWebSocket while connecting', () {
    test('a second call is a state error and the first still opens', () async {
      final gate = Completer<void>();
      var handshakes = 0;
      final server = await _serve((request) async {
        handshakes++;
        await gate.future;
        await _upgrade(request);
      });
      final api = _api(server);

      final first = api.connectWebSocket();
      await expectLater(
        api.connectWebSocket(),
        _throwsPlex(PlexErrorType.state),
      );
      gate.complete();
      await first;

      expect(api.isWebSocketConnected, isTrue);
      expect(handshakes, 1);
      await api.closeWebSocket();
    });

    test('closeWebSocket() aborts it and the socket is not leaked', () async {
      final gate = Completer<void>();
      final asked = Completer<void>();
      final closedByClient = Completer<void>();
      final server = await _serve((request) async {
        asked.complete();
        await gate.future;
        (await _upgrade(
          request,
        )).listen((_) {}, onDone: closedByClient.complete);
      });
      final api = _api(server);

      final pending = api.connectWebSocket();
      final failed = expectLater(pending, _throwsPlex(PlexErrorType.cancelled));
      await asked.future;
      await api.closeWebSocket();
      await failed;
      expect(api.isWebSocketConnected, isFalse);

      // The handshake completes after the fact: the socket must be closed,
      // not left open with nobody holding it.
      gate.complete();
      await closedByClient.future.timeout(const Duration(seconds: 5));
    });

    test('a handshake that never answers times out', () async {
      final server = await _serve((request) {});
      final api = _api(server);
      const timeout = Duration(milliseconds: 150);

      await expectLater(
        api.connectWebSocket(connectTimeout: timeout),
        _throwsPlex(PlexErrorType.timeout),
      );
      expect(api.isWebSocketConnected, isFalse);
      // The failed attempt released the guard: this is a new timeout, not
      // "already connected".
      await expectLater(
        api.connectWebSocket(connectTimeout: timeout),
        _throwsPlex(PlexErrorType.timeout),
      );
    });
  });

  group('PlexNotificationsApi.connectWebSocket refused', () {
    test('a 401 is an auth error, the token kept out of the message', () async {
      final server = await _serve((request) async {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
      });
      final api = _api(server);

      await expectLater(
        api.connectWebSocket(),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.auth)
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', isNot(contains(_token))),
        ),
      );
      expect(api.isWebSocketConnected, isFalse);
    });

    test('a 500 stays a connection error', () async {
      final server = await _serve((request) async {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      });

      await expectLater(
        _api(server).connectWebSocket(),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.connection)
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('a closed port is a connection error', () async {
      final server = await _serve((request) {});
      final api = _api(server);
      await server.close(force: true);

      await expectLater(
        api.connectWebSocket(),
        _throwsPlex(PlexErrorType.connection),
      );
    });
  });

  group('PlexNotificationsApi WebSocket ending', () {
    test('the server closing ends the stream and leaves its code', () async {
      final server = await _serve((request) async {
        await (await _upgrade(request)).close(4001, 'server going down');
      });
      final api = _api(server);
      final done = Completer<void>();

      final stream = await api.connectWebSocket();
      stream.listen((_) {}, onDone: done.complete);
      await done.future.timeout(const Duration(seconds: 5));

      expect(api.isWebSocketConnected, isFalse);
      expect(api.webSocketCloseCode, 4001);
      expect(api.webSocketCloseReason, 'server going down');
    });

    test('closeWebSocket() ends the stream and leaves no code', () async {
      final closedByClient = Completer<void>();
      final server = await _serve((request) async {
        (await _upgrade(
          request,
        )).listen((_) {}, onDone: closedByClient.complete);
      });
      final api = _api(server);
      final done = Completer<void>();

      final stream = await api.connectWebSocket();
      stream.listen((_) {}, onDone: done.complete);
      await api.closeWebSocket();

      await done.future.timeout(const Duration(seconds: 5));
      await closedByClient.future.timeout(const Duration(seconds: 5));
      expect(api.isWebSocketConnected, isFalse);
      expect(api.webSocketCloseCode, isNull);
    });

    test('a new connection resets the close code', () async {
      var first = true;
      final server = await _serve((request) async {
        final closing = first;
        first = false;
        final socket = _upgrade(request);
        if (closing) await (await socket).close(4001);
      });
      final api = _api(server);
      final done = Completer<void>();
      (await api.connectWebSocket()).listen((_) {}, onDone: done.complete);
      await done.future.timeout(const Duration(seconds: 5));
      expect(api.webSocketCloseCode, 4001);

      await api.connectWebSocket();

      expect(api.webSocketCloseCode, isNull);
      await api.closeWebSocket();
    });

    test('only the last subscription cancelling closes the socket', () async {
      final closedByClient = Completer<void>();
      final server = await _serve((request) async {
        (await _upgrade(
          request,
        )).listen((_) {}, onDone: closedByClient.complete);
      });
      final api = _api(server);

      final stream = await api.connectWebSocket();
      final first = stream.listen((_) {});
      final second = stream.listen((_) {});
      await first.cancel();
      expect(api.isWebSocketConnected, isTrue);
      await second.cancel();

      expect(api.isWebSocketConnected, isFalse);
      await closedByClient.future.timeout(const Duration(seconds: 5));
    });

    test('closeWebSocket() does not wait on a peer that never answers the '
        'close', () async {
      final server = await _serve((request) async {
        // Upgraded but never read: the close frame is never answered.
        await _upgrade(request);
      });
      final api = _api(server);
      await api.connectWebSocket();

      final watch = Stopwatch()..start();
      await api.closeWebSocket();

      expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
      expect(api.isWebSocketConnected, isFalse);
    });

    test('PlexClient.close() closes it', () async {
      final closedByClient = Completer<void>();
      final server = await _serve((request) async {
        (await _upgrade(
          request,
        )).listen((_) {}, onDone: closedByClient.complete);
      });
      final plex = PlexClient(credentials: testCredentials)
        ..connect('http://127.0.0.1:${server.port}', accessToken: _token);
      final done = Completer<void>();
      final stream = await plex.notifications.connectWebSocket();
      stream.listen((_) {}, onDone: done.complete);

      plex.close();

      expect(plex.notifications.isWebSocketConnected, isFalse);
      await done.future.timeout(const Duration(seconds: 5));
      await closedByClient.future.timeout(const Duration(seconds: 5));
    });
  });
}
