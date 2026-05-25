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
  group('Plex sessions + playback', () {
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
      await plex.playback.rate(ratingKey: trackRatingKey, rating: 6);
      await plex.playback.setFavorite(
        ratingKey: trackRatingKey,
        isFavorite: true,
      );
      await plex.playback.setFavorite(
        ratingKey: trackRatingKey,
        isFavorite: false,
      );
      await plex.playback.rate(ratingKey: trackRatingKey, rating: 0);
    });

    test('scrobble -> unscrobble round trip', () async {
      await plex.playback.scrobble(trackRatingKey);
      await plex.playback.unscrobble(trackRatingKey);
    });
  }, skip: bootstrapSkipReason);
}
