// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@Tags(['integration'])
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_fixture.dart';

/// Smoke tests for the full playlist lifecycle
/// ([PlexPlaylistsApi]) against a live PMS seeded by `bootstrap.dart`.
void main() {
  group('Plex playlists CRUD', () {
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

    test('create -> add -> list -> rename -> remove -> delete', () async {
      final created = await plex.playlists.create(
        title: 'dart_plex smoke playlist',
        type: 'audio',
        machineIdentifier: cache.machineIdentifier,
        itemRatingKeys: trackRatingKeys.take(2).toList(),
      );
      expect(created.ratingKey, isNotEmpty);

      try {
        // Append the remaining track.
        if (trackRatingKeys.length > 2) {
          await plex.playlists.addItems(
            playlistId: created.ratingKey,
            machineIdentifier: cache.machineIdentifier,
            itemRatingKeys: [trackRatingKeys[2]],
          );
        }

        var entries = await plex.playlists.items(created.ratingKey);
        expect(entries.length, trackRatingKeys.length);

        // Rename and verify by re-reading from list().
        await plex.playlists.rename(
          playlistId: created.ratingKey,
          title: 'dart_plex smoke playlist (renamed)',
        );
        final all = await plex.playlists.list();
        final renamed = all.firstWhere((p) => p.ratingKey == created.ratingKey);
        expect(renamed.title, contains('renamed'));

        // Remove the last entry by its playlistItemID.
        entries = await plex.playlists.items(created.ratingKey);
        final lastEntry = entries.last;
        final playlistItemId =
            (lastEntry.raw['playlistItemID'] ?? lastEntry.raw['playlistItemId'])
                ?.toString();
        expect(
          playlistItemId,
          isNotNull,
          reason: 'Each entry must carry a playlistItemID',
        );
        await plex.playlists.removeItem(
          playlistId: created.ratingKey,
          playlistItemId: playlistItemId!,
        );
        entries = await plex.playlists.items(created.ratingKey);
        expect(entries.length, trackRatingKeys.length - 1);
      } finally {
        await plex.playlists.delete(created.ratingKey);
      }

      // After delete the playlist must be gone from the list().
      final after = await plex.playlists.list();
      expect(
        after.any((p) => p.ratingKey == created.ratingKey),
        isFalse,
      );
    });

    test('double-delete is idempotent (or fails cleanly with notFound)',
        () async {
      final created = await plex.playlists.create(
        title: 'dart_plex idempotency probe',
        type: 'audio',
        machineIdentifier: cache.machineIdentifier,
        itemRatingKeys: [trackRatingKeys.first],
      );
      await plex.playlists.delete(created.ratingKey);

      try {
        await plex.playlists.delete(created.ratingKey);
      } on PlexException catch (e) {
        expect(
          e.type,
          anyOf(PlexErrorType.notFound, PlexErrorType.badRequest),
        );
      }
    });
  }, skip: bootstrapSkipReason);
}
