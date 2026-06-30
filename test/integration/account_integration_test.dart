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
  group(
    'Plex account',
    () {
      late PlexClient plex;
      late PlexBootstrapCache cache;

      setUpAll(() {
        cache = PlexBootstrapCache.load();
        plex = plexFromCache();
      });

      test('tokenDetails on the PMS confirms the stored token', () async {
        // /user is a PMS endpoint — it tells us which plex.tv user
        // the current access token resolves to.
        final details = await plex.account.tokenDetails();
        expect(details, isNotEmpty);
      });

      test('connectedUsers is callable (admin only)', () async {
        final users = await plex.account.connectedUsers();
        expect(users, isA<List<Map<String, dynamic>>>());
      });

      test('fetchResources includes our test server', () async {
        final list = await plex.account.fetchResources();
        expect(
          list.any((r) => r.clientIdentifier == cache.machineIdentifier),
          isTrue,
        );
      });
    },
    skip: bootstrapSkipReason,
  );
}
