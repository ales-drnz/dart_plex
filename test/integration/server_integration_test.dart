// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@Tags(['integration'])
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_fixture.dart';

/// Smoke tests for [PlexServerApi] against a live PMS.
void main() {
  group('Plex server', () {
    late PlexClient plex;
    late PlexBootstrapCache cache;

    setUpAll(() {
      cache = PlexBootstrapCache.load();
      plex = plexFromCache();
    });

    test('identity returns the machine identifier from the bootstrap',
        () async {
      final id = await plex.server.identity();
      expect(id['machineIdentifier'], cache.machineIdentifier);
      expect(id['version'], isNotEmpty);
    });

    test('info returns extended server metadata', () async {
      final info = await plex.server.info();
      expect(info['machineIdentifier'], cache.machineIdentifier);
      expect(info['platform'] ?? info['Platform'], isNotEmpty);
    });

    test('ping returns true for a reachable PMS', () async {
      expect(await plex.server.ping(), isTrue);
    });

    test('backgroundTasks is callable', () async {
      final bg = await plex.server.backgroundTasks();
      expect(bg, isNotEmpty);
    });
  }, skip: bootstrapSkipReason);
}
