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
  group(
    'Plex library',
    () {
      late PlexClient plex;

      setUpAll(() {
        plex = plexFromCache();
      });

      test('sections includes the seeded Music library', () async {
        final sections = await plex.library.sections();
        expect(sections, isNotEmpty);
        expect(
          sections.any(
            (s) => s.title == 'Music' && s.type == PlexLibraryType.music,
          ),
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

      test('a filter actually narrows the result set', () async {
        final sections = await plex.library.sections();
        final music = sections.firstWhere((s) => s.title == 'Music');
        final total = await plex.library.countByType(
          sectionId: music.id,
          type: PlexMetadataType.track,
        );
        expect(total, greaterThan(0));

        // Nothing in the seed was released after the year 9999, so a
        // server that honours the filter must answer with fewer items.
        // A server that ignored it — the 0.1.0 behaviour, and what
        // happens whenever the parameter name or its encoding is wrong
        // — would answer with all of them.
        final impossible = await plex.library.countByType(
          sectionId: music.id,
          type: PlexMetadataType.track,
          filters: [PlexFilter.yearAfter(9999)],
        );
        expect(impossible, lessThan(total));
      });

      test('played and unplayed partition the section', () async {
        final sections = await plex.library.sections();
        final music = sections.firstWhere((s) => s.title == 'Music');
        Future<int> count(List<PlexFilter> filters) => plex.library.countByType(
              sectionId: music.id,
              type: PlexMetadataType.track,
              filters: filters,
            );

        final total = await count(const []);
        final unplayed = await count([PlexFilter.unplayed()]);
        final played = await count([PlexFilter.played()]);

        // The pinned spec does not declare `unwatched` on this route,
        // so this is what holds `PlexFilter.played()` / `.unplayed()`
        // honest: if the server ever stopped honouring the flag, the
        // ignored side would run to `total` and the sum would no
        // longer add up.
        expect(unplayed + played, total);
        expect(played, lessThan(total));
      });

      test('a genre from the server filters the items it came from', () async {
        final sections = await plex.library.sections();
        final music = sections.firstWhere((s) => s.title == 'Music');
        final genres = await plex.library.genres(
          sectionId: music.id,
          type: PlexMetadataType.album,
        );
        final tagged = genres.where((g) => g.id != null).toList();
        if (tagged.isEmpty) {
          markTestSkipped('seed library has no genre tags');
          return;
        }

        final page = await plex.library.allByType(
          sectionId: music.id,
          type: PlexMetadataType.album,
          filters: [PlexFilter.of(tagged.first)],
        );
        expect(page.items, isNotEmpty);
        expect(
          page.items.every((a) => a.genres.contains(tagged.first.title)),
          isTrue,
        );
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
        final hubs = await plex.search.hubs(query: 'Track');
        // Even an empty hubs list is a valid response (no matches)
        // but our seed has "Track 1/2/3" titles so we expect at least
        // one hub with at least one item.
        expect(hubs, isA<List<PlexHub>>());
        expect(hubs.any((h) => h.items.isNotEmpty), isTrue);
      });
    },
    skip: bootstrapSkipReason,
  );
}
