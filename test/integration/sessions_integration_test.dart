// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@Tags(['integration'])
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_fixture.dart';

/// Smoke tests for sessions + playback reporting
/// ([PlexSessionsApi], [PlexPlaybackApi]) against a live PMS seeded by
/// `bootstrap.dart`.
void main() {
  group(
    'Plex sessions + playback',
    () {
      late PlexClient plex;
      late String trackRatingKey;

      setUpAll(() async {
        plex = plexFromCache();
        if (bootstrapSkipReason != null) return;
        final sections = await plex.library.sections();
        final music = sections.firstWhere((s) => s.title == 'Music');
        final page = await plex.library.allByType(
          sectionId: music.id,
          type: PlexMetadataType.track,
          size: 1,
        );
        trackRatingKey = page.items.first.ratingKey;
      });

      test('sessions.active returns a list (possibly empty)', () async {
        final active = await plex.sessions.active();
        expect(active, isA<List<PlexSession>>());
      });

      test('sessions.history returns a list (possibly empty)', () async {
        final history = await plex.sessions.history(size: 10);
        expect(history, isA<List<Map<String, dynamic>>>());
      });

      test('timeline playing -> paused -> stopped round trip', () async {
        await plex.playback.timeline(
          ratingKey: trackRatingKey,
          state: PlexPlaybackApi.statePlaying,
          timeMs: 0,
          durationMs: 30000,
        );
        await plex.playback.timeline(
          ratingKey: trackRatingKey,
          state: PlexPlaybackApi.statePlaying,
          timeMs: 5000,
          durationMs: 30000,
        );
        await plex.playback.timeline(
          ratingKey: trackRatingKey,
          state: PlexPlaybackApi.statePaused,
          timeMs: 8000,
          durationMs: 30000,
        );
        await plex.playback.timeline(
          ratingKey: trackRatingKey,
          state: PlexPlaybackApi.stateStopped,
          timeMs: 10000,
          durationMs: 30000,
        );
      });

      test('rate -> setFavorite -> clear round trip', () async {
        // rate(6) -> userRating becomes 6.0, but 6 < 10 so not a favorite.
        await plex.playback.rate(ratingKey: trackRatingKey, rating: 6);
        final afterRate = await plex.library.item(trackRatingKey);
        expect(afterRate, isNotNull);
        expect(afterRate!.userRating, 6.0);
        expect(afterRate.isFavorite, isFalse);

        // setFavorite(true) overwrites the rating to 10.0 (favorite threshold).
        await plex.playback.setFavorite(
          ratingKey: trackRatingKey,
          isFavorite: true,
        );
        final afterFav = await plex.library.item(trackRatingKey);
        expect(afterFav, isNotNull);
        expect(afterFav!.userRating, 10.0);
        expect(afterFav.isFavorite, isTrue);

        // setFavorite(false) maps to rating 0 -> no longer a favorite.
        await plex.playback.setFavorite(
          ratingKey: trackRatingKey,
          isFavorite: false,
        );
        // Final clear to 0; Plex may report a cleared rating as 0.0 or null.
        await plex.playback.rate(ratingKey: trackRatingKey, rating: 0);
        final afterClear = await plex.library.item(trackRatingKey);
        expect(afterClear, isNotNull);
        expect(afterClear!.userRating ?? 0.0, 0.0);
        expect(afterClear.isFavorite, isFalse);
      });

      test('scrobble -> unscrobble round trip', () async {
        // Plex may report viewCount as null when 0, so normalise with ?? 0.
        final before = await plex.library.item(trackRatingKey);
        expect(before, isNotNull);
        final beforeViews = before!.viewCount ?? 0;

        await plex.playback.scrobble(trackRatingKey);
        final afterScrobble = await plex.library.item(trackRatingKey);
        expect(afterScrobble, isNotNull);
        expect(afterScrobble!.viewCount ?? 0, greaterThan(beforeViews));

        await plex.playback.unscrobble(trackRatingKey);
        final afterUnscrobble = await plex.library.item(trackRatingKey);
        expect(afterUnscrobble, isNotNull);
        expect(afterUnscrobble!.viewCount ?? 0, beforeViews);
      });
    },
    skip: bootstrapSkipReason,
  );
}
