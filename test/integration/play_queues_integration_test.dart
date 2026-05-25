// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@Tags(['integration'])
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_fixture.dart';

/// Smoke tests for the play queue lifecycle ([PlexPlayQueuesApi])
/// against a live PMS seeded by `bootstrap.dart`.
void main() {
  group('Plex playQueues', () {
    late PlexClient plex;
    late PlexBootstrapCache cache;
    late List<String> trackRatingKeys;

    setUpAll(() async {
      plex = plexFromCache();
      if (bootstrapSkipReason != null) return;
      cache = PlexBootstrapCache.load();
      final sections = await plex.library.sections();
      final music = sections.firstWhere((s) => s.title == 'Music');
      final page = await plex.library.allByType(
        sectionId: music.id,
        type: PlexMetadataType.track,
        size: 3,
      );
      trackRatingKeys = [for (final m in page.items) m.ratingKey];
    });

    test('continuous queue: create -> items -> addItems -> reset -> clear',
        () async {
      final seedUri = PlexPlayQueuesApi.seedFromItems(
        machineIdentifier: cache.machineIdentifier,
        ratingKeys: trackRatingKeys.take(2).toList(),
      );
      final queue = await plex.playQueues.create(
        type: 'audio',
        uri: seedUri,
      );
      expect(queue.id, greaterThan(0));
      expect(queue.items.length, greaterThanOrEqualTo(2));
      final queueId = queue.id;

      // Initial items via the items() endpoint.
      var entries = await plex.playQueues.items(playQueueId: queueId);
      expect(entries.length, greaterThanOrEqualTo(2));

      // Append the remaining track.
      if (trackRatingKeys.length > 2) {
        final addUri = PlexPlayQueuesApi.seedFromItems(
          machineIdentifier: cache.machineIdentifier,
          ratingKeys: [trackRatingKeys[2]],
        );
        await plex.playQueues.addItems(playQueueId: queueId, uri: addUri);
        entries = await plex.playQueues.items(playQueueId: queueId);
        expect(entries.length, trackRatingKeys.length);
      }

      // Reset is allowed on continuous queues.
      await plex.playQueues.reset(queueId);

      // Clear strips everything except the currently-selected item;
      // the queue stays alive with that single entry.
      await plex.playQueues.clear(queueId);
      entries = await plex.playQueues.items(playQueueId: queueId);
      expect(entries.length, lessThan(trackRatingKeys.length));
    });

    test('non-continuous queue: shuffle + unshuffle round trip', () async {
      // Plex restricts shuffle/unshuffle to queues without an Up Next
      // area, so we create with `continuous: false` for this test.
      final seedUri = PlexPlayQueuesApi.seedFromItems(
        machineIdentifier: cache.machineIdentifier,
        ratingKeys: trackRatingKeys.take(2).toList(),
      );
      final queue = await plex.playQueues.create(
        type: 'audio',
        uri: seedUri,
        continuous: false,
      );
      expect(queue.id, greaterThan(0));

      await plex.playQueues.shuffle(queue.id);
      await plex.playQueues.unshuffle(queue.id);
    });
  }, skip: bootstrapSkipReason);
}
