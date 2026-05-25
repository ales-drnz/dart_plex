// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@Tags(['integration'])
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_fixture.dart';

/// Smoke tests for the library browsing surface
/// ([PlexLibraryApi], [PlexSearchApi]) against a live PMS seeded by
/// `bootstrap.dart`.
void main() {
  group('Plex library', () {
    late PlexClient plex;

    setUpAll(() {
      plex = plexFromCache();
    });

    test('sections includes the seeded Music library', () async {
      final sections = await plex.library.sections();
      expect(sections, isNotEmpty);
      expect(
        sections
            .any((s) => s.title == 'Music' && s.type == PlexLibraryType.music),
        isTrue,
      );
    });

    test('allByType returns the seeded tracks', () async {
      final sections = await plex.library.sections();
      final music = sections.firstWhere((s) => s.title == 'Music');
      final page = await plex.library.allByType(
        sectionId: music.id,
        type: PlexMetadataType.track,
        size: 100,
      );
      expect(page.totalSize, greaterThanOrEqualTo(3));
      expect(page.items, isNotEmpty);
      expect(
        page.items.any((m) => m.title.contains('Track')),
        isTrue,
      );
    });

    test('countByType matches allByType.totalSize', () async {
      final sections = await plex.library.sections();
      final music = sections.firstWhere((s) => s.title == 'Music');
      final count = await plex.library.countByType(
        sectionId: music.id,
        type: PlexMetadataType.track,
      );
      final page = await plex.library.allByType(
        sectionId: music.id,
        type: PlexMetadataType.track,
        size: 0,
      );
      expect(count, page.totalSize);
    });

    test('item() on a real track returns a populated DTO', () async {
      final sections = await plex.library.sections();
      final music = sections.firstWhere((s) => s.title == 'Music');
      final page = await plex.library.allByType(
        sectionId: music.id,
        type: PlexMetadataType.track,
        size: 1,
      );
      final ratingKey = page.items.first.ratingKey;
      expect(ratingKey, isNotEmpty);
      final item = await plex.library.item(ratingKey);
      expect(item, isNotNull);
      expect(item!.ratingKey, ratingKey);
    });

    test('search.hubs finds the seeded Track items', () async {
      final hubs = await plex.search.hubs(query: 'Track', limit: 10);
      // Even an empty hubs list is a valid response (no matches)
      // but our seed has "Track 1/2/3" titles so we expect at least
      // one hub with at least one item.
      expect(hubs, isA<List<PlexHub>>());
      expect(hubs.any((h) => h.items.isNotEmpty), isTrue);
    });
  }, skip: bootstrapSkipReason);
}
