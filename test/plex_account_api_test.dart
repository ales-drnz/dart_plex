// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The plex.tv account API on the wire. The live counterpart is
/// `test/integration/account_integration_test.dart`, which needs a real
/// plex.tv account.
library;

import 'dart:convert';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

void main() {
  late CapturingAdapter adapter;
  late PlexClient plex;

  setUp(() {
    adapter = CapturingAdapter({
      'user': {'id': 1, 'username': 'me', 'authToken': 'new-token'},
    });
    plex = PlexClient(credentials: testCredentials, httpClient: adapter);
  });

  test('signInWithPassword posts a form body, as 0.1 did', () async {
    final user = await plex.account.signInWithPassword(
      username: 'me@example.com',
      password: 'p&ss word',
    );
    final req = adapter.last!;
    expect(req.method, 'POST');
    expect(req.uri.toString(), 'https://plex.tv/users/sign_in.json');
    expect(req.headers['Content-Type'], 'application/x-www-form-urlencoded');
    expect(
      utf8.decode(req.body),
      'user%5Blogin%5D=me%40example.com&user%5Bpassword%5D=p%26ss+word',
    );
    expect(Uri.splitQueryString(utf8.decode(req.body)), {
      'user[login]': 'me@example.com',
      'user[password]': 'p&ss word',
    });
    expect(user.authToken, 'new-token');
  });

  test('signInWithPassword leaves the client token to the caller', () async {
    await plex.account.signInWithPassword(username: 'me', password: 'pw');
    expect(plex.isAuthenticated, isFalse);
    await plex.account.currentUser();
    expect(adapter.last!.headers.containsKey('X-Plex-Token'), isFalse);
  });

  test('a sign-in answer without a token is an auth error', () async {
    adapter.responseBody = {
      'user': {'id': 1},
    };
    await expectLater(
      plex.account.signInWithPassword(username: 'me', password: 'pw'),
      throwsA(
        isA<PlexException>().having((e) => e.type, 'type', PlexErrorType.auth),
      ),
    );
  });

  test('secrets in a URL are redacted from the exception', () async {
    adapter.respond = (_) => CannedResponse(500, const []);
    final pin = await plex
        .request<Object>(
          'https://clients.plex.tv/api/v2/pins/42?deviceJWT=secret.jwt.sig'
          '&X-Plex-Token=tok&pin=1234&other=kept',
          absoluteUrl: true,
        )
        .then<PlexException?>(
          (_) => null,
          onError: (Object e) => e as PlexException,
        );
    expect(pin!.path, isNot(contains('secret')));
    expect(pin.path, contains('deviceJWT=REDACTED'));
    expect(pin.path, contains('X-Plex-Token=REDACTED'));
    expect(pin.path, contains('pin=REDACTED'));
    expect(pin.path, contains('other=kept'));
    expect('$pin', isNot(contains('tok&')));
    expect('$pin', isNot(contains('1234')));
  });

  group('plex.tv account features', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    CannedResponse xml(String body) =>
        CannedResponse(200, utf8.encode(body), contentType: 'text/xml');

    test('home users (XML), managed users', () async {
      adapter.respond = (_) => xml('''
<MediaContainer size="2">
  <User id="1" uuid="u1" title="Admin" username="admin" email="a@x" admin="1" guest="0" restricted="0" protected="1"/>
  <User id="2" uuid="u2" title="Kid" admin="0" guest="0" restricted="1" restrictionProfile="little_kid" protected="0"/>
</MediaContainer>''');
      final home = await plex.account.homeUsers();
      expect(adapter.last!.path, 'https://plex.tv/api/home/users');
      expect(home.map((u) => (u.id, u.admin, u.restricted, u.protected)), [
        (1, true, false, true),
        (2, false, true, false),
      ]);
      final managed = await plex.account.managedUsers();
      expect(managed.single.restrictionProfile, 'little_kid');
    });

    test('switchHomeUser posts the pin and returns the user token', () async {
      adapter.respond = (_) => xml(
        '<user id="2" uuid="u2" title="Kid" authenticationToken="kid-token" '
        'restricted="1" home="1"/>',
      );
      final user = await plex.account.switchHomeUser(userId: 2, pin: '1234');
      final r = adapter.last!;
      expect(r.method, 'POST');
      expect(r.path, 'https://plex.tv/api/home/users/2/switch');
      expect(r.queryParameters['pin'], '1234');
      expect(user.authToken, 'kid-token');
      expect(user.restricted, isTrue);
      plex.setAccountToken(user.authToken);
      expect(plex.accountToken, 'kid-token');
    });

    test('connected users with their shares (XML)', () async {
      adapter.respond = (_) => xml('''
<MediaContainer>
  <User id="7" title="Friend" username="friend" email="f@x" home="0" allowSync="1">
    <Server id="3" serverId="9" machineIdentifier="m" name="Home" numLibraries="2" allLibraries="0" owned="1" pending="0" lastSeenAt="1700000000"/>
  </User>
</MediaContainer>''');
      final users = await plex.account.connectedUsers();
      expect(adapter.last!.path, 'https://plex.tv/api/users/');
      final share = users.single.servers.single;
      expect(users.single.allowSync, isTrue);
      expect(
        (share.machineIdentifier, share.numLibraries, share.owned),
        ('m', 2, true),
      );
      expect(share.lastSeenAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
    });

    test('friends (JSON list or the documented object)', () async {
      answer([
        {'id': 1, 'uuid': 'a', 'title': 'Ann', 'username': 'ann'},
      ]);
      // ignore: deprecated_member_use_from_same_package
      expect((await plex.account.friends()).single.username, 'ann');
      answer({
        'users': [
          {'id': 2, 'username': 'bob'},
        ],
      });
      // ignore: deprecated_member_use_from_same_package
      expect((await plex.account.friends()).single.title, 'bob');
    });

    test('watchlist via the discover provider', () async {
      answer({
        'MediaContainer': {
          'totalSize': 1,
          'Metadata': [
            {'ratingKey': '5d77', 'guid': 'plex://movie/5d77', 'type': 'movie'},
          ],
        },
      });
      final page = await plex.account.watchlist(
        filter: PlexWatchlistFilter.released,
        sort: PlexSort.watchlistedAt.desc,
        type: PlexMetadataType.movie,
      );
      final r = adapter.last!;
      expect(
        r.path,
        'https://discover.provider.plex.tv/library/sections/watchlist/released',
      );
      expect(r.queryParameters, {
        'includeCollections': '1',
        'includeExternalMedia': '1',
        'sort': 'watchlistedAt:desc',
        'type': '1',
        'X-Plex-Container-Start': '0',
        'X-Plex-Container-Size': '50',
      });
      final key = PlexAccountApi.discoverKeyOf(page.items.single.guid!);
      await plex.account.addToWatchlist(ratingKey: key);
      expect(adapter.last!.method, 'PUT');
      expect(
        adapter.last!.uri.toString(),
        'https://discover.provider.plex.tv/actions/addToWatchlist?ratingKey=5d77',
      );
    });

    test('geoip, snake_case', () async {
      answer({
        'code': 'IT',
        'continent_code': 'EU',
        'country': 'Italy',
        'city': 'Rome',
        'time_zone': 'Europe/Rome',
        'postal_code': '00100',
        'coordinates': '41.9, 12.5',
        'european_union_member': true,
        'in_privacy_restricted_country': false,
      });
      final g = await plex.account.geoip(ipAddress: '1.2.3.4');
      expect(adapter.last!.queryParameters['ip_address'], '1.2.3.4');
      expect(
        (g.code, g.continentCode, g.timeZone),
        ('IT', 'EU', 'Europe/Rome'),
      );
      expect((g.latitude, g.longitude), (41.9, 12.5));
      expect(g.europeanUnionMember, isTrue);
    });
  });
}
