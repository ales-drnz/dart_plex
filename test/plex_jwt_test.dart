// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:dart_plex/dart_plex.dart';
import 'package:dart_plex/src/plex_session_state.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

List<int> _hex(String h) => [
  for (var i = 0; i < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
];

String _toHex(List<int> b) =>
    b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

/// RFC 8032 §7.1, test 1 — also the key of RFC 8037 appendix A.
const _seed1 =
    '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60';
const _public1 =
    'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a';

/// A JWT with the given payload, unsigned (plex.tv's tokens are read, not
/// verified).
String _jwt(Map<String, Object?> payload) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'EdDSA'})}.${seg(payload)}.c2ln';
}

int _epoch(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

void main() {
  group('PlexDeviceKey (fixed vectors)', () {
    test('RFC 8032 test 1: the public key and the signature of ""', () async {
      final key = await PlexDeviceKey.fromSeed(_hex(_seed1));
      expect(_toHex(key.publicKey), _public1);
      expect(
        _toHex(await key.sign(const [])),
        'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8'
        '821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
      );
    });

    test('RFC 8032 test 2: a one-byte message', () async {
      final key = await PlexDeviceKey.fromSeed(
        _hex(
          '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
        ),
      );
      expect(
        _toHex(key.publicKey),
        '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
      );
      expect(
        _toHex(await key.sign(const [0x72])),
        '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085a'
        'c1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
      );
    });

    test('RFC 8037 A.3: the key id is the JWK thumbprint', () async {
      final key = await PlexDeviceKey.fromSeed(_hex(_seed1));
      expect(key.keyId, 'kPrK_qmxVWaYVA9wwBF6Iuo3vVzz7TxHCTwXBygrS4k');
    });

    test('RFC 8037 A.4: a JWS signature', () async {
      final key = await PlexDeviceKey.fromSeed(_hex(_seed1));
      final sig = await key.sign(
        utf8.encode('eyJhbGciOiJFZERTQSJ9.RXhhbXBsZSBvZiBFZDI1NTE5IHNpZ25pbmc'),
      );
      expect(
        base64Url.encode(sig).replaceAll('=', ''),
        'hgyY0il_MGCjP0JzlnLWG1PPOt7-09PGcvMg3AIbQR6dWbhijcNR4ki4iylGjg5BhVsPt9'
        'g7sVvpAr_MuM0KAg',
      );
    });

    test('the device JWT is deterministic (checked with OpenSSL)', () async {
      final key = await PlexDeviceKey.fromSeed(_hex(_seed1));
      final jwt = await key.deviceJwt(
        clientIdentifier: 'test-uuid',
        nonce: 'n-1',
        scopes: const ['username'],
        now: DateTime.utc(2026, 11, 7),
      );
      // `openssl pkeyutl -verify -rawin` accepts this signature for the
      // RFC 8032 public key.
      expect(
        jwt,
        'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCIsImtpZCI6ImtQcktfcW14VldhWVZBOXd3QkY2'
        'SXVvM3ZWeno3VHhIQ1R3WEJ5Z3JTNGsifQ.eyJub25jZSI6Im4tMSIsInNjb3BlIjoidX'
        'Nlcm5hbWUiLCJhdWQiOiJwbGV4LnR2IiwiaXNzIjoidGVzdC11dWlkIiwiaWF0IjoxNzk0'
        'MDA5NjAwLCJleHAiOjE3OTQwMDk5MDB9.5brdLn0wjboDaR_idrYnERzBB000trsWM2IJJ'
        'YLMoRqO5jJPmAwPggnYIPlimdGEzDVCHxje23E9tywkXOhXBA',
      );
      final parts = jwt.split('.');
      final header = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
      );
      expect(header, {
        'alg': 'EdDSA',
        'typ': 'JWT',
        'kid': 'kPrK_qmxVWaYVA9wwBF6Iuo3vVzz7TxHCTwXBygrS4k',
      });
      final claims = PlexJwt.parse(jwt).claims;
      expect(claims['aud'], 'plex.tv');
      expect(claims['iss'], 'test-uuid');
      expect(claims['nonce'], 'n-1');
      expect(claims['exp'], (claims['iat']! as int) + 300);
    });

    test('toJson / fromJson round-trip, and refuse a mismatched x', () async {
      final key = await PlexDeviceKey.fromSeed(_hex(_seed1));
      final json = key.toJson();
      expect(json['x'], '11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo');
      expect(json['d'], 'nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A');
      final back = await PlexDeviceKey.fromJson(json);
      expect(back.publicKey, key.publicKey);
      expect(back.keyId, key.keyId);
      expect(
        () => PlexDeviceKey.fromJson({...json, 'x': 'AAAA'}),
        throwsFormatException,
      );
      expect(key.publicJwk.containsKey('d'), isFalse);
      expect(key.publicJwk['alg'], 'EdDSA');
    });

    test('generate() makes distinct 32-byte keys', () async {
      final a = await PlexDeviceKey.generate();
      final b = await PlexDeviceKey.generate();
      expect(a.privateKey, hasLength(32));
      expect(a.publicKey, hasLength(32));
      expect(a.keyId, isNot(b.keyId));
    });

    test('privateKey and publicKey are copies', () async {
      final key = await PlexDeviceKey.fromSeed(_hex(_seed1));
      key.privateKey[0] ^= 0xff;
      key.publicKey[0] ^= 0xff;
      expect(_toHex(key.privateKey), _seed1);
      expect(_toHex(key.publicKey), _public1);
    });

    test('a seed of the wrong length is refused', () {
      expect(() => PlexDeviceKey.fromSeed([1, 2, 3]), throwsArgumentError);
    });
  });

  group('PlexJwt', () {
    final now = DateTime.utc(2026, 11, 7, 12);

    test('reads exp, iat and thumbprint', () {
      final jwt = PlexJwt.parse(
        _jwt({
          'exp': _epoch(now.add(const Duration(days: 7))),
          'iat': _epoch(now),
          'thumbprint': 'tp',
        }),
      );
      expect(jwt.isJwt, isTrue);
      expect(jwt.expiresAt, now.add(const Duration(days: 7)));
      expect(jwt.issuedAt, now);
      expect(jwt.thumbprint, 'tp');
      expect(jwt.isExpired(now), isFalse);
      expect(jwt.expiresWithin(const Duration(days: 1), now), isFalse);
      expect(
        jwt.expiresWithin(
          const Duration(days: 1),
          now.add(const Duration(days: 6, hours: 1)),
        ),
        isTrue,
      );
      expect(jwt.isExpired(now.add(const Duration(days: 8))), isTrue);
    });

    test('a claim of the wrong type is a parse error', () {
      for (final payload in [
        {'exp': 'tomorrow'},
        {'iat': 1e300},
        {'thumbprint': 42},
      ]) {
        expect(
          () => PlexJwt.parse(_jwt(payload)),
          throwsA(
            isA<PlexException>().having(
              (e) => e.type,
              't',
              PlexErrorType.parse,
            ),
          ),
          reason: '$payload',
        );
      }
    });

    test('a legacy token has no claims and never expires', () {
      final legacy = PlexJwt.parse('2ffLuB84dqLswk9skLos');
      expect(legacy.isJwt, isFalse);
      expect(legacy.expiresAt, isNull);
      expect(legacy.isExpired(), isFalse);
    });
  });

  group('the device JWTs kept for pins being polled', () {
    final t0 = DateTime.utc(2026, 11, 13, 12);
    final reuseUntil = t0.add(const Duration(minutes: 4));

    test('one is reused until its time, then dropped', () {
      final state = PlexSessionState()..keepPinJwt(1, 'jwt-1', reuseUntil);
      expect(state.pinJwt(1, t0), 'jwt-1');
      expect(state.pinJwt(2, t0), isNull);
      expect(state.pinJwt(1, reuseUntil), isNull);
      expect(state.pinJwtCount, 0);
    });

    test('touching the cache drops those of pins nobody polls any more', () {
      final state = PlexSessionState()
        ..keepPinJwt(1, 'abandoned', reuseUntil)
        ..keepPinJwt(2, 'jwt-2', reuseUntil.add(const Duration(minutes: 2)));
      expect(
        state.pinJwt(2, reuseUntil.add(const Duration(minutes: 1))),
        'jwt-2',
      );
      expect(state.pinJwtCount, 1);
      state.dropPinJwt(2);
      expect(state.pinJwtCount, 0);
    });
  });

  group('JWT sign-in against a mocked plex.tv', () {
    late CapturingAdapter adapter;
    late PlexClient plex;
    late PlexDeviceKey key;
    final fresh = _jwt({
      'exp': _epoch(DateTime.now().toUtc().add(const Duration(days: 7))),
    });

    setUp(() async {
      key = await PlexDeviceKey.fromSeed(_hex(_seed1));
      adapter = CapturingAdapter();
      adapter.respond = (r) {
        switch (r.uri.path) {
          case '/api/v2/auth/nonce':
            return CannedResponse.json({
              'nonce': 'n-${adapter.requests.length}',
            });
          case '/api/v2/auth/token':
            return CannedResponse.json({'auth_token': fresh});
          case '/api/v2/pins':
            return CannedResponse.json({
              'id': 42,
              'code': 'abcdefghijklmnopqrstuvwxy',
              'clientIdentifier': 'test-uuid',
              'createdAt': '2026-11-07T00:00:00Z',
              'expiresAt': '2099-01-01T00:00:00Z',
            });
          case '/api/v2/pins/42':
            return CannedResponse.json({
              'id': 42,
              'code': 'abcdefghijklmnopqrstuvwxy',
              'authToken': fresh,
              'createdAt': '2026-11-07T00:00:00Z',
              'expiresAt': '2099-01-01T00:00:00Z',
            });
          case '/api/v2/user':
            return CannedResponse.json({'id': 1, 'username': 'me'});
        }
        return CannedResponse.json(const <String, Object?>{});
      };
      plex = PlexClient(credentials: testCredentials, httpClient: adapter);
    });

    test('createJwtPin posts the public JWK with strong: true', () async {
      final pin = await plex.account.createJwtPin(key: key);
      final r = adapter.last!;
      expect(r.method, 'POST');
      expect(r.path, 'https://clients.plex.tv/api/v2/pins');
      expect(r.json, {'jwk': key.publicJwk, 'strong': true});
      expect(r.headers.containsKey('X-Plex-Token'), isFalse);
      expect(pin.id, 42);
      final url = plex.account.authAppUrl(pin);
      expect(url, startsWith('https://app.plex.tv/auth#?'));
      expect(url, contains('clientID=test-uuid'));
      expect(url, contains('code=abcdefghijklmnopqrstuvwxy'));
      expect(url, contains('context%5Bdevice%5D%5Bproduct%5D=TestApp'));
    });

    test(
      'pollJwtPin signs a device JWT with a nonce, reused across polls',
      () async {
        final pin = await plex.account.pollJwtPin(id: 42, key: key);
        expect(pin.authToken, fresh);
        final polls = adapter.requests.where(
          (r) => r.uri.path == '/api/v2/pins/42',
        );
        final nonces = adapter.requests.where(
          (r) => r.uri.path == '/api/v2/auth/nonce',
        );
        expect(nonces, hasLength(1));
        final deviceJwt = polls.single.queryParameters['deviceJWT']!;
        final claims = PlexJwt.parse(deviceJwt).claims;
        expect(claims['aud'], 'plex.tv');
        expect(claims['iss'], 'test-uuid');
        expect(claims['nonce'], isNotNull);
      },
    );

    group('a pin still waiting, polled through views of one client', () {
      int nonces() => adapter.requests
          .where((r) => r.uri.path == '/api/v2/auth/nonce')
          .length;

      setUp(() {
        final answer = adapter.respond!;
        adapter.respond = (r) => r.uri.path == '/api/v2/pins/42'
            ? CannedResponse.json({
                'id': 42,
                'code': 'abcdefghijklmnopqrstuvwxy',
                'createdAt': '2026-11-07T00:00:00Z',
                'expiresAt': '2099-01-01T00:00:00Z',
              })
            : answer(r);
      });

      test('asks for one nonce and sends one device JWT', () async {
        final first = plex.withCancelToken(PlexCancelToken());
        final second = plex.withCancelToken(PlexCancelToken());
        expect(identical(first.account, second.account), isFalse);
        for (final view in [first, second, plex, first]) {
          final pin = await view.account.pollJwtPin(id: 42, key: key);
          expect(pin.isAuthenticated, isFalse);
        }
        expect(nonces(), 1);
        final sent = adapter.requests
            .where((r) => r.uri.path == '/api/v2/pins/42')
            .map((r) => r.queryParameters['deviceJWT'])
            .toSet();
        expect(sent, hasLength(1));
      });

      test('another client signs its own', () async {
        await plex.account.pollJwtPin(id: 42, key: key);
        final other = PlexClient(
          credentials: testCredentials,
          httpClient: adapter,
        );
        await other.account.pollJwtPin(id: 42, key: key);
        expect(nonces(), 2);
      });
    });

    test(
      'refreshJwt: nonce, signed device JWT, exchange — no token sent',
      () async {
        plex.setToken('expired-token');
        final jwt = await plex.account.refreshJwt(key: key);
        expect(jwt.token, fresh);
        final nonce = adapter.requests[0];
        final exchange = adapter.requests[1];
        expect(nonce.path, 'https://clients.plex.tv/api/v2/auth/nonce');
        expect(nonce.headers.containsKey('X-Plex-Token'), isFalse);
        expect(exchange.method, 'POST');
        expect(exchange.path, 'https://clients.plex.tv/api/v2/auth/token');
        expect(exchange.headers.containsKey('X-Plex-Token'), isFalse);
        final deviceJwt = (exchange.json! as Map)['jwt'] as String;
        expect(PlexJwt.parse(deviceJwt).claims['nonce'], 'n-1');
        final sig = deviceJwt.split('.');
        expect(sig, hasLength(3));
      },
    );

    test(
      'the exchange also accepts the documented authToken spelling',
      () async {
        adapter.respond = (r) => r.uri.path.endsWith('nonce')
            ? CannedResponse.json({'nonce': 'n'})
            : CannedResponse.json({'authToken': 'abc'});
        expect((await plex.account.refreshJwt(key: key)).token, 'abc');
      },
    );

    test('registerJwtKey posts the public JWK with the legacy token', () async {
      await plex.account.registerJwtKey(key: key, token: 'legacy');
      final r = adapter.last!;
      expect(r.path, 'https://clients.plex.tv/api/v2/auth/jwk');
      expect(r.headers['X-Plex-Token'], 'legacy');
      expect(r.json, {'jwk': key.publicJwk});
    });

    test('useJwt refreshes a session with no token and persists it', () async {
      final saved = <String>[];
      final session = PlexJwtSession(
        key: key,
        onChanged: (s) => saved.add(jsonEncode(s.toJson())),
      );
      await plex.useJwt(session);
      expect(plex.accountToken, fresh);
      expect(plex.token, fresh);
      expect(saved, hasLength(1));
      final restored = await PlexJwtSession.fromJson(
        jsonDecode(saved.single) as Map<String, Object?>,
      );
      expect(restored.token!.token, fresh);
      expect(restored.key.keyId, key.keyId);
    });

    test('useJwt keeps a token that is still fresh', () async {
      await plex.useJwt(PlexJwtSession(key: key, token: PlexJwt.parse(fresh)));
      expect(adapter.requests, isEmpty);
      await plex.account.currentUser();
      expect(adapter.last!.headers['X-Plex-Token'], fresh);
    });

    test('an expired token is refreshed before a plex.tv call', () async {
      final old = _jwt({
        'exp': _epoch(DateTime.now().toUtc().subtract(const Duration(days: 1))),
      });
      final session = PlexJwtSession(key: key, token: PlexJwt.parse(old));
      // Not through useJwt, so that the refresh happens on the call.
      await plex.useJwt(PlexJwtSession(key: key, token: PlexJwt.parse(fresh)));
      adapter.requests.clear();
      session.updateToken(PlexJwt.parse(old));
      await plex.useJwt(session);
      expect(plex.accountToken, fresh);
      await plex.account.currentUser();
      expect(adapter.last!.headers['X-Plex-Token'], fresh);
    });

    test('a 498 from plex.tv refreshes the JWT and retries once', () async {
      final session = PlexJwtSession(key: key, token: PlexJwt.parse(fresh));
      await plex.useJwt(session);
      var refused = false;
      final renewed = _jwt({
        'exp': _epoch(DateTime.now().toUtc().add(const Duration(days: 7))),
        'n': 2,
      });
      adapter.respond = (r) {
        if (r.uri.path == '/api/v2/auth/nonce') {
          return CannedResponse.json({'nonce': 'x'});
        }
        if (r.uri.path == '/api/v2/auth/token') {
          return CannedResponse.json({'auth_token': renewed});
        }
        if (!refused) {
          refused = true;
          return CannedResponse(
            498,
            utf8.encode('Token Expired'),
            contentType: 'text/plain',
          );
        }
        return CannedResponse.json({'id': 1, 'username': 'me'});
      };
      final user = await plex.account.currentUser();
      expect(user.username, 'me');
      expect(adapter.last!.headers['X-Plex-Token'], renewed);
      expect(session.token!.token, renewed);
      expect(plex.accountToken, renewed);
    });

    test(
      'a 401 from the server renews the JWT through the token renewer',
      () async {
        final session = PlexJwtSession(key: key, token: PlexJwt.parse(fresh));
        await plex.useJwt(session);
        plex.connect('http://10.0.0.2:32400');
        final renewed = _jwt({
          'exp': _epoch(DateTime.now().toUtc().add(const Duration(days: 7))),
          'n': 3,
        });
        var calls = 0;
        adapter.respond = (r) {
          if (r.uri.path == '/api/v2/auth/nonce') {
            return CannedResponse.json({'nonce': 'x'});
          }
          if (r.uri.path == '/api/v2/auth/token') {
            return CannedResponse.json({'auth_token': renewed});
          }
          calls++;
          return r.headers['X-Plex-Token'] == renewed
              ? CannedResponse.json({
                  'MediaContainer': {'size': 0},
                })
              : CannedResponse(401, const []);
        };
        await Future.wait([plex.library.sections(), plex.library.sections()]);
        expect(calls, 4);
        expect(
          adapter.requests.where((r) => r.uri.path == '/api/v2/auth/token'),
          hasLength(1),
          reason: 'concurrent refusals share one refresh',
        );
        expect(plex.token, renewed);
      },
    );

    test('a server token that is not the JWT is not renewed', () async {
      await plex.useJwt(PlexJwtSession(key: key, token: PlexJwt.parse(fresh)));
      plex.connect('http://10.0.0.2:32400', accessToken: 'server-token');
      expect(plex.accountToken, fresh);
      adapter.respond = (_) => CannedResponse(401, const []);
      await expectLater(
        plex.library.sections(),
        throwsA(
          isA<PlexException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
      expect(
        adapter.requests.where((r) => r.uri.path == '/api/v2/auth/token'),
        isEmpty,
      );
    });
  });

  group('JWT renewal edge cases', () {
    late CapturingAdapter adapter;
    late PlexClient plex;
    late PlexDeviceKey key;
    final valid = _jwt({
      'exp': _epoch(DateTime.now().toUtc().add(const Duration(days: 7))),
    });

    int count(String path) =>
        adapter.requests.where((r) => r.uri.path == path).length;

    setUp(() async {
      key = await PlexDeviceKey.fromSeed(_hex(_seed1));
      adapter = CapturingAdapter();
      plex = PlexClient(credentials: testCredentials, httpClient: adapter);
    });

    test('a refusal while refreshing does not wait on itself', () async {
      await plex.useJwt(PlexJwtSession(key: key, token: PlexJwt.parse(valid)));
      plex.connect('http://10.0.0.2:32400');
      // Everything is refused: the server, and plex.tv's nonce too.
      adapter.respond = (_) => CannedResponse(401, const []);
      await expectLater(
        plex.library.sections().timeout(const Duration(seconds: 5)),
        throwsA(isA<PlexException>().having((e) => e.statusCode, 'st', 401)),
      );
      expect(count('/api/v2/auth/nonce'), 1);
      expect(count('/library/sections'), 1);
    });

    test('a persistent 401 from plex.tv: one retry, one refresh', () async {
      await plex.useJwt(PlexJwtSession(key: key, token: PlexJwt.parse(valid)));
      adapter.respond = (r) => switch (r.uri.path) {
        '/api/v2/auth/nonce' => CannedResponse.json({'nonce': 'n'}),
        '/api/v2/auth/token' => CannedResponse.json({
          'auth_token': _jwt({
            'exp': _epoch(DateTime.now().toUtc().add(const Duration(days: 7))),
            'n': adapter.requests.length,
          }),
        }),
        _ => CannedResponse(401, const []),
      };
      await expectLater(
        plex.account.currentUser(),
        throwsA(isA<PlexException>().having((e) => e.statusCode, 'st', 401)),
      );
      expect(count('/api/v2/user'), 2);
      expect(count('/api/v2/auth/token'), 1);
    });

    test('the same with the account token sent apart from the server '
        'token', () async {
      await plex.useJwt(PlexJwtSession(key: key, token: PlexJwt.parse(valid)));
      plex.connect('http://10.0.0.2:32400', accessToken: 'server-token');
      adapter.respond = (r) => switch (r.uri.path) {
        '/api/v2/auth/nonce' => CannedResponse.json({'nonce': 'n'}),
        '/api/v2/auth/token' => CannedResponse.json({
          'auth_token': _jwt({
            'exp': _epoch(DateTime.now().toUtc().add(const Duration(days: 7))),
            'n': adapter.requests.length,
          }),
        }),
        _ => CannedResponse(401, const []),
      };
      await expectLater(
        plex.account.currentUser(),
        throwsA(isA<PlexException>().having((e) => e.statusCode, 'st', 401)),
      );
      expect(count('/api/v2/user'), 2);
      expect(count('/api/v2/auth/token'), 1);
    });

    test('registerJwtKey with its own token never refreshes the JWT', () async {
      await plex.useJwt(PlexJwtSession(key: key, token: PlexJwt.parse(valid)));
      adapter.respond = (_) => CannedResponse(401, const []);
      await expectLater(
        plex.account.registerJwtKey(key: key, token: 'legacy'),
        throwsA(isA<PlexException>()),
      );
      expect(count('/api/v2/auth/nonce'), 0);
      expect(adapter.requests, hasLength(1));
    });

    test('a failed useJwt leaves the client as it was', () async {
      plex.setToken('legacy');
      adapter.respond = (_) => CannedResponse(500, const []);
      await expectLater(
        plex.useJwt(PlexJwtSession(key: key)),
        throwsA(isA<PlexException>()),
      );
      expect(plex.accountToken, 'legacy');
      expect(plex.tokenRenewer, isNull);
      adapter.respond = (_) => CannedResponse.json({'id': 1});
      await plex.account.currentUser();
      expect(count('/api/v2/auth/nonce'), 1, reason: 'no refresh on the call');
    });

    test('a token from a skewed clock is timed from its receipt', () {
      // plex.tv's clock is 10 days behind: by the claims the token
      // expired 3 days ago, but it was issued for 7 days just now.
      final issued = DateTime.now().toUtc().subtract(const Duration(days: 10));
      final skewed = PlexJwt.parse(
        _jwt({
          'iat': _epoch(issued),
          'exp': _epoch(issued.add(const Duration(days: 7))),
        }),
      );
      final session = PlexJwtSession(key: key);
      expect(session.needsRefresh, isTrue);
      session.updateToken(skewed);
      expect(session.needsRefresh, isFalse);
      // Restored from storage, the receipt is unknown: the claims count.
      expect(PlexJwtSession(key: key, token: skewed).needsRefresh, isTrue);
    });

    test('a short-lived token is refreshed at half its lifetime', () {
      final now = DateTime.now().toUtc();
      final short = PlexJwt.parse(
        _jwt({
          'iat': _epoch(now),
          'exp': _epoch(now.add(const Duration(hours: 1))),
        }),
      );
      final session = PlexJwtSession(key: key)..updateToken(short);
      expect(session.needsRefresh, isFalse);
    });

    test('a refreshed token bound to another key is refused', () async {
      adapter.respond = (r) => r.uri.path.endsWith('nonce')
          ? CannedResponse.json({'nonce': 'n'})
          : CannedResponse.json({
              'auth_token': _jwt({'thumbprint': 'someone-else'}),
            });
      await expectLater(
        PlexJwtSession(key: key).refresh(plex.account),
        throwsA(
          isA<PlexException>().having((e) => e.type, 't', PlexErrorType.auth),
        ),
      );
    });

    test('onChanged throwing surfaces as a PlexException', () async {
      adapter.respond = (r) => r.uri.path.endsWith('nonce')
          ? CannedResponse.json({'nonce': 'n'})
          : CannedResponse.json({
              'auth_token': _jwt({'thumbprint': key.keyId}),
            });
      final session = PlexJwtSession(
        key: key,
        onChanged: (_) => throw StateError('disk full'),
      );
      await expectLater(
        session.refresh(plex.account),
        throwsA(
          isA<PlexException>().having((e) => e.cause, 'cause', isStateError),
        ),
      );
      expect(session.token, isNotNull, reason: 'the new token is kept');
    });
  });

  group('tokenRenewer', () {
    test('retries once with the renewed token, then gives up', () async {
      final adapter = CapturingAdapter();
      adapter.respond = (r) => r.headers['X-Plex-Token'] == 'new'
          ? CannedResponse.json({
              'MediaContainer': {'size': 0},
            })
          : CannedResponse(401, const []);
      final seen = <String?>[];
      final plex = testClient(adapter)
        ..tokenRenewer = (rejected) async {
          seen.add(rejected);
          return 'new';
        };
      await plex.library.sections();
      expect(seen, ['tok']);
      expect(plex.token, 'new');

      adapter.respond = (_) => CannedResponse(401, const []);
      await expectLater(plex.library.sections(), throwsA(isA<PlexException>()));
      // 'new' was refused too and the renewer had nothing newer: no retry.
      expect(seen, ['tok', 'new']);
      expect(adapter.requests, hasLength(3));
    });

    test('a renewer returning null lets the 401 through', () async {
      final adapter = CapturingAdapter()
        ..respond = (_) => CannedResponse(401, const []);
      final plex = testClient(adapter)..tokenRenewer = (_) async => null;
      await expectLater(
        plex.library.sections(),
        throwsA(
          isA<PlexException>().having((e) => e.isAuthError, 'auth', true),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });
  });
}
