// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@Tags(['integration'])
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_fixture.dart';

/// Smoke tests for the Plex browse surface
/// ([PlexSearchApi], [PlexHubsApi], [PlexStreamingApi],
/// [PlexCollectionsApi]).
void main() {
  group('Plex browse APIs', () {
    late PlexClient plex;
    late PlexBootstrapCache cache;
    late PlexLibrarySection musicSection;
    late List<String> trackRatingKeys;

    setUpAll(() async {
      plex = plexFromCache();
      if (bootstrapSkipReason != null) return;
      cache = PlexBootstrapCache.load();
      final sections = await plex.library.sections();
      musicSection = sections.firstWhere((s) => s.title == 'Music');
      final page = await plex.library.allByType(
        sectionId: musicSection.id,
        type: PlexMetadataType.track,
        size: 3,
      );
      trackRatingKeys = [for (final m in page.items) m.ratingKey];
    });

    test('search.flat returns a metadata list (legacy endpoint, may be empty)',
        () async {
      // The legacy /search endpoint behaves differently in modern PMS
      // builds — it often returns no results even for content that's
      // present in hubs.search. We just verify the shape is right.
      final results = await plex.search.flat(query: 'Track');
      expect(results, isA<List<PlexMetadata>>());
    });

    test('search.voice accepts a natural-language query', () async {
      final results = await plex.search.voice(query: 'play test artist');
      expect(results, isA<List<PlexHub>>());
    });

    test('hubs.global returns the home hubs', () async {
      final hubs = await plex.hubs.global(count: 5);
      expect(hubs, isA<List<PlexHub>>());
    });

    test('hubs.forSection returns the section hubs', () async {
      final hubs = await plex.hubs.forSection(
        sectionId: musicSection.id,
        count: 5,
      );
      expect(hubs, isA<List<PlexHub>>());
    });

    test('hubs.continueWatching returns a (typically empty) list', () async {
      final items = await plex.hubs.continueWatching(count: 5);
      expect(items, isA<List<PlexMetadata>>());
    });

    test('streaming.universalAudioUrl builds a signed URL', () {
      final url = plex.streaming.universalAudioUrl(
        ratingKey: trackRatingKeys.first,
        session: 'dart-plex-it-stream',
      );
      expect(url, contains('/transcode/universal/start'));
      expect(url, contains('X-Plex-Token='));
      expect(url, contains('session=dart-plex-it-stream'));
    });

    test('collections create returns a ratingKey + items endpoint responds',
        () async {
      // Plex's `addItem`/`items` semantics for collections behave
      // differently than playlists (server tag model vs. linked rows);
      // we only smoke-test that the lifecycle endpoints are reachable.
      final seedUri = PlexPlayQueuesApi.seedFromItems(
        machineIdentifier: cache.machineIdentifier,
        ratingKeys: trackRatingKeys.take(2).toList(),
      );
      final created = await plex.collections.create(
        sectionId: musicSection.id.toString(),
        seedUri: seedUri,
        title: 'dart_plex smoke collection',
      );
      expect(created.ratingKey, isNotEmpty);

      // items() endpoint should respond with a list (may be empty
      // depending on server tag-propagation delay).
      final items = await plex.collections.items(created.ratingKey);
      expect(items, isA<List<PlexMetadata>>());

      // Cover image URL builder.
      final cover = plex.collections.compositeImageUrl(
        collectionId: created.ratingKey,
        updatedAt: 0,
      );
      expect(cover, contains('/library/collections/${created.ratingKey}'));
      expect(cover, contains('X-Plex-Token='));
    });
  }, skip: bootstrapSkipReason);
}
