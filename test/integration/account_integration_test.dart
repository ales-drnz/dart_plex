// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@Tags(['integration'])
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_fixture.dart';

/// Smoke tests for [PlexAccountApi] — these reach out to plex.tv so
/// they need network connectivity, not just Docker.
void main() {
  group('Plex account', () {
    late PlexClient plex;
    late PlexBootstrapCache cache;

    setUpAll(() {
      cache = PlexBootstrapCache.load();
      plex = plexFromCache();
    });

    test('tokenDetails says whose the server token is', () async {
      final details = await plex.account.tokenDetails();
      expect(details.id, isNonZero);
      if (cache.plexUserId != null) expect(details.id, cache.plexUserId);
    });

    test('connectedUsers reads the XML list', () async {
      final users = await plex.account.connectedUsers();
      expect(users, isA<List<PlexAccountUser>>());
    });

    test('homeUsers reads the XML list (empty without a Home)', () async {
      final users = await plex.account.homeUsers();
      expect(users, isA<List<PlexHomeUser>>());
    });

    test('geoip locates this machine', () async {
      final g = await plex.account.geoip();
      expect(g.raw, isNotEmpty);
    });

    test('watchlist answers from the discover provider', () async {
      final page = await plex.account.watchlist(size: 5);
      expect(page.items, isA<List<PlexMetadata>>());
    });

    test('connectToResource reaches the test server', () async {
      final resources = await plex.account.fetchResources();
      final server = resources.firstWhere(
        (r) => r.clientIdentifier == cache.machineIdentifier,
      );
      final probe = PlexClient(
        credentials: plex.credentials,
        connectTimeout: const Duration(seconds: 3),
      )..setToken(plex.token);
      addTearDown(probe.close);
      // The container advertises 127.0.0.1; whatever plex.tv lists, the
      // pick must answer as this server.
      final picked = await probe.connectToResource(
        server,
        timeout: const Duration(seconds: 8),
      );
      expect(picked.uri, isNotEmpty);
      final identity = await probe.server.identity();
      expect(identity.machineIdentifier, cache.machineIdentifier);
    });

    test('fetchResources includes our test server', () async {
      final list = await plex.account.fetchResources();
      expect(
        list.any((r) => r.clientIdentifier == cache.machineIdentifier),
        isTrue,
      );
    });
  }, skip: bootstrapSkipReason);
}
