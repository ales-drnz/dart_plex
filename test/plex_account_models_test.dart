// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The plex.tv account models against real, anonymised plex.tv answers
/// (`account_devices`, `geoip`) where the test account has them, and the
/// account calls no other test drives: the device list and the server
/// token read from it, the JWT nonce and the JWT exchange.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/fixtures.dart';
import '_helpers/wire_calls.dart';

const _serverId = '0000000000000000000000000000000000000000';

/// plex.tv answers `/api/v2/devices` with a bare list.
List<Object?> _devices() =>
    jsonDecode(
          File('test/fixtures/real/account_devices.json').readAsStringSync(),
        )
        as List<Object?>;

/// An unsigned JWT with [payload]: plex.tv's tokens are read, not verified.
String _jwt(Map<String, Object?> payload) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'EdDSA'})}.${seg(payload)}.c2ln';
}

void main() {
  late CapturingAdapter adapter;
  late PlexClient plex;

  setUp(() {
    adapter = CapturingAdapter();
    plex = PlexClient(credentials: testCredentials, httpClient: adapter)
      ..setAccountToken('account-token');
  });

  void answer(Object? json) => adapter.responseBody = json;

  group('devices', () {
    test('devices asks plex.tv with the account token', () async {
      answer(_devices());
      await plex.account.devices();
      final request = adapter.last!;
      expect(request.method, 'GET');
      expect(request.path, 'https://plex.tv/api/v2/devices');
      expect(request.uri.query, isEmpty);
      expect(request.headers['X-Plex-Token'], 'account-token');
    });

    test('PlexDevice reads a player and a server (plex.tv answer)', () async {
      answer(_devices());
      final devices = await plex.account.devices();
      expect(devices, hasLength(2));
      final player = devices.first;
      expect(
        (player.name, player.product, player.platform),
        ('Test player', 'dart_plex bootstrap', 'Test'),
      );
      expect(player.clientIdentifier, 'player-client-identifier');
      // plex.tv sends `provides: null` for a device that serves nothing.
      expect(player.provides, isEmpty);
      expect(player.productVersion, isNull);
      expect(player.token, 'device-token-player');
      final server = devices.last;
      expect(
        (server.name, server.product, server.platform),
        ('Test server', 'Plex Media Server', 'Linux'),
      );
      expect(server.clientIdentifier, _serverId);
      expect(server.provides, ['server']);
      expect(server.token, 'device-token-server');
      // plex.tv v2 sends ISO dates here, not epoch seconds.
      expect(server.lastSeenAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
      expect(server.raw['publicAddress'], '203.0.113.7');
    });

    test('PlexDevice: the older shapes — accessToken, epoch seconds, a '
        'provides list with spaces', () {
      final device = PlexDevice.fromJson(const {
        'name': 'Old',
        'clientIdentifier': 'c',
        'product': 'Plexamp',
        'productVersion': '4.10.1',
        'platform': 'iOS',
        'provides': 'client, player ,',
        'accessToken': 'legacy-token',
        'lastSeenAt': '1700000000',
      });
      expect(device.provides, ['client', 'player']);
      expect(device.productVersion, '4.10.1');
      expect(device.token, 'legacy-token');
      expect(device.lastSeenAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
      final bare = PlexDevice.fromJson(const {});
      expect((bare.name, bare.clientIdentifier, bare.product), ('', '', ''));
      expect((bare.token, bare.lastSeenAt), (null, null));
      expect(bare.provides, isEmpty);
    });

    test('devices reads the documented container and the XML too', () async {
      answer({
        'MediaContainer': {
          'Device': [
            {'name': 'A', 'clientIdentifier': 'a', 'product': 'P'},
          ],
        },
      });
      expect((await plex.account.devices()).single.name, 'A');
      adapter.respond = (_) => CannedResponse(
        200,
        utf8.encode(
          '<MediaContainer><Device name="B" clientIdentifier="b" '
          'product="P" token="t" provides="server"/></MediaContainer>',
        ),
        contentType: 'application/xml',
      );
      final b = (await plex.account.devices()).single;
      expect((b.name, b.token), ('B', 't'));
      expect(b.provides, ['server']);
    });

    test('devices: an empty body lists none; a body of the wrong shape is '
        'a parse error', () async {
      adapter.respond = (_) => CannedResponse(200, const []);
      expect(await plex.account.devices(), isEmpty);
      adapter.respond = (_) => CannedResponse(200, utf8.encode('{not json'));
      await expectLater(plex.account.devices(), throwsParseError);
    });

    test('serverTokenFromDevices finds the token of that server', () async {
      answer(_devices());
      expect(
        await plex.account.serverTokenFromDevices(_serverId),
        'device-token-server',
      );
      expect(adapter.last!.path, 'https://plex.tv/api/v2/devices');
    });

    test('serverTokenFromDevices is null for a server plex.tv does not '
        'list, or lists without a token', () async {
      answer(_devices());
      expect(await plex.account.serverTokenFromDevices('unknown'), isNull);
      answer([
        {'clientIdentifier': _serverId, 'token': ''},
        {'clientIdentifier': _serverId},
      ]);
      expect(await plex.account.serverTokenFromDevices(_serverId), isNull);
    });

    test('serverTokenFromDevices skips an entry without a token for one '
        'that has it', () async {
      answer([
        {'clientIdentifier': _serverId, 'token': ''},
        {'clientIdentifier': 'other', 'token': 'wrong'},
        {'clientIdentifier': _serverId, 'token': 'right'},
      ]);
      expect(await plex.account.serverTokenFromDevices(_serverId), 'right');
    });
  });

  group('geoip', () {
    test('PlexGeoLocation reads the plex.tv answer (snake_case, '
        'coordinates as "lat, lon")', () async {
      answer(realFixture('geoip'));
      final g = await plex.account.geoip();
      expect(adapter.last!.path, 'https://plex.tv/api/v2/geoip');
      expect(adapter.last!.uri.query, isEmpty);
      expect((g.code, g.country, g.city), ('IT', 'Italy', 'Rome'));
      expect(
        (g.continentCode, g.subdivisions, g.postalCode),
        ('EU', 'Lazio', '00100'),
      );
      expect(g.timeZone, 'Europe/Rome');
      expect((g.latitude, g.longitude), (41.9, 12.5));
      expect(g.europeanUnionMember, isTrue);
      expect(g.inPrivacyRestrictedCountry, isTrue);
      expect(g.raw['in_privacy_restricted_region'], isTrue);
    });

    test('PlexGeoLocation: camelCase, the XML wrapper, and coordinates '
        'that are not a pair', () {
      final camel = PlexGeoLocation.fromJson(const {
        'location': {
          'country_code': 'US',
          'continentCode': 'NA',
          'postalCode': '96779',
          'timeZone': 'Pacific/Honolulu',
          'europeanUnionMember': false,
          'inPrivacyRestrictedCountry': '0',
          'coordinates': 'nowhere',
        },
      });
      expect(
        (camel.code, camel.continentCode, camel.postalCode),
        ('US', 'NA', '96779'),
      );
      expect(camel.timeZone, 'Pacific/Honolulu');
      expect((camel.latitude, camel.longitude), (null, null));
      expect(camel.europeanUnionMember, isFalse);
      expect(camel.inPrivacyRestrictedCountry, isFalse);
      final empty = PlexGeoLocation.fromJson(const {});
      expect((empty.city, empty.code, empty.country), (null, null, null));
    });
  });

  group('friends and shares', () {
    test('PlexFriend: title falls back to the username; email and thumb '
        'are optional', () {
      final full = PlexFriend.fromJson(const {
        'id': '12',
        'uuid': 'u-12',
        'title': 'Ann',
        'username': 'ann',
        'email': 'ann@example.com',
        'thumb': 'https://example.com/a.png',
      });
      expect(
        (full.id, full.uuid, full.title, full.username),
        (12, 'u-12', 'Ann', 'ann'),
      );
      expect(
        (full.email, full.thumb),
        ('ann@example.com', 'https://example.com/a.png'),
      );
      final sparse = PlexFriend.fromJson(const {'username': 'bob'});
      expect((sparse.id, sparse.uuid, sparse.title), (0, '', 'bob'));
      expect((sparse.email, sparse.thumb), (null, null));
      expect(sparse.raw, {'username': 'bob'});
    });

    test('friends: the gone endpoint is an error, not an empty list '
        '(plex.tv answers 410 to /api/v2/friends)', () async {
      adapter.respond = (_) =>
          CannedResponse(410, const [], contentType: 'text/plain');
      await expectLater(
        plex.account.friends(),
        throwsA(
          isA<PlexException>().having((e) => e.statusCode, 'statusCode', 410),
        ),
      );
      expect(adapter.last!.path, 'https://plex.tv/api/v2/friends');
    });

    test('PlexServerShare reads a share, as attributes or as JSON', () {
      final share = PlexServerShare.fromJson(const {
        'id': '3',
        'serverId': '9',
        'machineIdentifier': _serverId,
        'name': 'Home',
        'lastSeenAt': '1700000000',
        'numLibraries': '2',
        'allLibraries': '0',
        'owned': '1',
        'pending': '0',
      });
      expect((share.id, share.serverId, share.name), (3, 9, 'Home'));
      expect(share.machineIdentifier, _serverId);
      expect(share.lastSeenAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect((share.numLibraries, share.allLibraries), (2, false));
      expect((share.owned, share.pending), (true, false));
      final bare = PlexServerShare.fromJson(const {'pending': true});
      expect(
        (bare.id, bare.serverId, bare.machineIdentifier),
        (null, null, ''),
      );
      expect((bare.name, bare.lastSeenAt, bare.pending), ('', null, true));
    });

    test('connectedUsers of an account that shares nothing is empty '
        '(plex.tv answers a bare MediaContainer element)', () async {
      adapter.respond = (_) => CannedResponse(
        200,
        utf8.encode(
          '<?xml version="1.0" encoding="UTF-8"?>\n'
          '<MediaContainer friendlyName="myPlex" identifier="com.plexapp.'
          'plugins.myplex" machineIdentifier="$_serverId" totalSize="0" '
          'size="0">\n</MediaContainer>\n',
        ),
        contentType: 'application/xml',
      );
      expect(await plex.account.connectedUsers(), isEmpty);
    });
  });

  group('JWT nonce and exchange', () {
    test('authNonce asks clients.plex.tv without a token', () async {
      answer({'nonce': 'n-1'});
      expect(await plex.account.authNonce(), 'n-1');
      final request = adapter.last!;
      expect(request.method, 'GET');
      expect(request.path, 'https://clients.plex.tv/api/v2/auth/nonce');
      expect(request.headers.containsKey('X-Plex-Token'), isFalse);
      expect(request.headers['X-Plex-Client-Identifier'], 'test-uuid');
    });

    test('authNonce: an answer without a nonce is a parse error', () async {
      answer({'nonce': 42});
      await expectLater(plex.account.authNonce(), throwsParseError);
      answer(<String, Object?>{});
      await expectLater(plex.account.authNonce(), throwsParseError);
    });

    test('exchangeDeviceJwt posts the device JWT as JSON, without a token, '
        'and reads the plex.tv JWT', () async {
      final issued = _jwt({'exp': 4102444800, 'iat': 1700000000, 'user': 1});
      answer({'auth_token': issued});
      final jwt = await plex.account.exchangeDeviceJwt('device.jwt.sig');
      final request = adapter.last!;
      expect(request.method, 'POST');
      expect(request.path, 'https://clients.plex.tv/api/v2/auth/token');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(request.json, {'jwt': 'device.jwt.sig'});
      expect(request.headers.containsKey('X-Plex-Token'), isFalse);
      expect(jwt.token, issued);
      expect(jwt.claims['user'], 1);
    });

    test('exchangeDeviceJwt reads authToken too', () async {
      final issued = _jwt({'exp': 4102444800});
      answer({'authToken': issued});
      expect((await plex.account.exchangeDeviceJwt('d')).token, issued);
    });

    test('exchangeDeviceJwt: an answer without a token is a parse '
        'error', () async {
      answer({'auth_token': ''});
      await expectLater(plex.account.exchangeDeviceJwt('d'), throwsParseError);
      answer({'error': 'nope'});
      await expectLater(plex.account.exchangeDeviceJwt('d'), throwsParseError);
    });

    test('exchangeDeviceJwt: an unknown key is the 422 plex.tv '
        'answers', () async {
      adapter.respond = (_) => CannedResponse.json({
        'errors': [
          {'code': 1097, 'message': 'Invalid signature', 'status': 422},
        ],
      }, status: 422);
      await expectLater(
        plex.account.exchangeDeviceJwt('d'),
        throwsA(
          isA<PlexException>().having((e) => e.statusCode, 'statusCode', 422),
        ),
      );
    });
  });
}
