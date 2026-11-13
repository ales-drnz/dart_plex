// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The library-wide reads and housekeeping calls on the wire: every
/// section and every item, the photo buckets, matching, transient items,
/// and the maintenance verbs.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/wire_calls.dart';

const _tracks = {
  'MediaContainer': {
    'size': 2,
    'Metadata': [
      {'ratingKey': '3', 'type': 'track', 'title': 'Track 1', 'index': 1},
      {'ratingKey': '4', 'type': 'track', 'title': 'Track 2', 'index': 2},
    ],
  },
};

const _buckets = {
  'MediaContainer': {
    'size': 1,
    'Directory': [
      {'key': '/library/sections/5/cluster/1', 'title': 'Rome', 'size': 12},
    ],
  },
};

void main() {
  group('housekeeping', () {
    testWireCalls([
      (
        'refreshAllSections (default)',
        (p) => p.library.refreshAllSections(),
        'POST',
        '/library/sections/refresh',
        {'force': '0'},
      ),
      (
        'refreshAllSections (forced)',
        (p) => p.library.refreshAllSections(force: true),
        'POST',
        '/library/sections/refresh',
        {'force': '1'},
      ),
      (
        'stopAllRefreshes',
        (p) => p.library.stopAllRefreshes(),
        'DELETE',
        '/library/sections/all/refresh',
        {},
      ),
      (
        'deleteCaches',
        (p) => p.library.deleteCaches(),
        'DELETE',
        '/library/caches',
        {},
      ),
      (
        'cleanBundles',
        (p) => p.library.cleanBundles(),
        'PUT',
        '/library/clean/bundles',
        {},
      ),
      (
        'optimizeDatabase (default)',
        (p) => p.library.optimizeDatabase(),
        'PUT',
        '/library/optimize',
        {'async': '0'},
      ),
      (
        'optimizeDatabase (async)',
        (p) => p.library.optimizeDatabase(asyncMode: true),
        'PUT',
        '/library/optimize',
        {'async': '1'},
      ),
      ('all', (p) => p.library.all(), 'GET', '/library/all', {}),
      (
        'sectionsAll',
        (p) => p.library.sectionsAll(),
        'GET',
        '/library/sections/all',
        {},
      ),
      (
        'sectionAllLeaves',
        (p) => p.library.sectionAllLeaves(sectionId: '1'),
        'GET',
        '/library/sections/1/allLeaves',
        {},
      ),
      (
        'sectionArts',
        (p) => p.library.sectionArts(sectionId: '1'),
        'GET',
        '/library/sections/1/arts',
        {},
      ),
      (
        'sectionClusters',
        (p) => p.library.sectionClusters(sectionId: '5'),
        'GET',
        '/library/sections/5/cluster',
        {},
      ),
      (
        'sectionMoments',
        (p) => p.library.sectionMoments(sectionId: '5'),
        'GET',
        '/library/sections/5/moment',
        {},
      ),
      (
        'categories',
        (p) => p.library.categories(sectionId: '1'),
        'GET',
        '/library/sections/1/categories',
        {},
      ),
      (
        'folderLocations',
        (p) => p.library.folderLocations(sectionId: '1'),
        'GET',
        '/library/sections/1/location',
        {},
      ),
      (
        'albums (first page by default)',
        (p) => p.library.albums(sectionId: '1'),
        'GET',
        '/library/sections/1/albums',
        {'X-Plex-Container-Start': '0', 'X-Plex-Container-Size': '50'},
      ),
      (
        'albums (a page)',
        (p) => p.library.albums(sectionId: '1', start: 100, size: 25),
        'GET',
        '/library/sections/1/albums',
        {'X-Plex-Container-Start': '100', 'X-Plex-Container-Size': '25'},
      ),
      (
        'matches',
        (p) => p.library.matches({
          'type': 9,
          'title': 'Test Album',
          'parentTitle': 'A & B',
          'year': 2020,
        }),
        'GET',
        '/library/matches',
        {
          'type': '9',
          'title': 'Test Album',
          'parentTitle': 'A & B',
          'year': '2020',
        },
      ),
      (
        'randomArtwork (plain)',
        (p) => p.library.randomArtwork(),
        'GET',
        '/library/randomArtwork',
        {},
      ),
      (
        'randomArtwork (of some sections)',
        (p) => p.library.randomArtwork(sections: '1,2'),
        'GET',
        '/library/randomArtwork',
        {'sections': '1,2'},
      ),
      (
        'defaultSectionPrefs (plain)',
        (p) => p.library.defaultSectionPrefs(),
        'GET',
        '/library/sections/prefs',
        {},
      ),
      (
        'defaultSectionPrefs (type, agent)',
        (p) => p.library.defaultSectionPrefs(
          type: '8',
          agent: 'tv.plex.agents.music',
        ),
        'GET',
        '/library/sections/prefs',
        {'type': '8', 'agent': 'tv.plex.agents.music'},
      ),
      (
        'ingestTransientItem (plain)',
        (p) => p.library.ingestTransientItem(url: 'file:///tmp/a b.mkv'),
        'POST',
        '/library/file',
        {'url': 'file:///tmp/a b.mkv'},
      ),
      (
        'ingestTransientItem (everything)',
        (p) => p.library.ingestTransientItem(
          url: 'file:///tmp/a.mkv',
          virtualFilePath: '/Movies/A (2020)/a.mkv',
          computeHashes: true,
          ingestNonMatches: false,
        ),
        'POST',
        '/library/file',
        {
          'url': 'file:///tmp/a.mkv',
          'virtualFilePath': '/Movies/A (2020)/a.mkv',
          'computeHashes': '1',
          'ingestNonMatches': '0',
        },
      ),
    ]);
  });

  group('answers', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    test('sectionsAll reads the sections with their folders '
        '(PMS 1.43.2 shape)', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'allowSync': false,
          'title1': 'Plex Library',
          'Directory': [
            {
              'allowSync': true,
              'filters': true,
              'refreshing': false,
              'key': '1',
              'type': 'artist',
              'title': 'Music',
              'agent': 'tv.plex.agents.music',
              'scanner': 'Plex Music',
              'language': 'en-US',
              'metadataAgentProviderGroupId': 3,
              'uuid': '00000000-0000-0000-0000-000000000001',
              'updatedAt': 1791712675,
              'createdAt': 1786528059,
              'scannedAt': 1794562321,
              'hidden': 0,
              'Location': [
                {'id': 1, 'path': '/data/Music'},
              ],
            },
          ],
        },
      });
      final section = (await plex.library.sectionsAll()).single;
      expect(
        (section.id, section.title, section.type),
        ('1', 'Music', PlexLibraryType.music),
      );
      expect(
        (section.agent, section.scanner, section.language),
        ('tv.plex.agents.music', 'Plex Music', 'en-US'),
      );
      expect(section.locations, ['/data/Music']);
      expect(
        section.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1786528059 * 1000, isUtc: true),
      );
      expect(section.scannedAt!.isAfter(section.createdAt!), isTrue);
    });

    test('sectionsAll: no sections is empty, no container a parse '
        'error', () async {
      answer({
        'MediaContainer': {'size': 0, 'title1': 'Plex Library'},
      });
      expect(await plex.library.sectionsAll(), isEmpty);
      adapter.respond = (_) => CannedResponse(200, const []);
      await expectLater(plex.library.sectionsAll(), throwsParseError);
    });

    test('all, sectionAllLeaves, categories and matches read items', () async {
      answer(_tracks);
      for (final items in [
        await plex.library.all(),
        await plex.library.sectionAllLeaves(sectionId: '1'),
        await plex.library.categories(sectionId: '1'),
        await plex.library.matches({'type': 10}),
      ]) {
        expect(items.map((i) => (i.ratingKey, i.title, i.index)), [
          ('3', 'Track 1', 1),
          ('4', 'Track 2', 2),
        ]);
        expect(items.first.type, PlexMetadataType.track);
      }
    });

    test('albums reads a page with its total', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'totalSize': 40,
          'offset': 25,
          'Metadata': [
            {'ratingKey': '2', 'type': 'album', 'title': 'Test Album'},
          ],
        },
      });
      final page = await plex.library.albums(
        sectionId: '1',
        start: 25,
        size: 1,
      );
      expect((page.totalSize, page.items.single.title), (40, 'Test Album'));
    });

    test('the photo buckets and folder locations read Directory '
        'entries', () async {
      answer(_buckets);
      for (final buckets in [
        await plex.library.sectionArts(sectionId: '5'),
        await plex.library.sectionClusters(sectionId: '5'),
        await plex.library.sectionMoments(sectionId: '5'),
        await plex.library.folderLocations(sectionId: '5'),
      ]) {
        expect(
          (buckets.single.key, buckets.single.title),
          ('/library/sections/5/cluster/1', 'Rome'),
        );
        expect(buckets.single.raw['size'], 12);
      }
    });

    test('a section without buckets or matches is empty (PMS 1.43.2 '
        'answers a container with no entries)', () async {
      answer({
        'MediaContainer': {
          'size': 0,
          'allowSync': false,
          'clusterZoomLevel': 1,
          'clusteringActive': false,
          'viewGroup': 'secondary',
        },
      });
      expect(await plex.library.sectionArts(sectionId: '1'), isEmpty);
      expect(await plex.library.sectionClusters(sectionId: '1'), isEmpty);
      expect(await plex.library.sectionMoments(sectionId: '1'), isEmpty);
      expect(await plex.library.matches({'type': 9}), isEmpty);
    });

    test('a body that is not a container is a parse error', () async {
      answer([1]);
      await expectLater(plex.library.all(), throwsParseError);
      await expectLater(
        plex.library.sectionClusters(sectionId: '1'),
        throwsParseError,
      );
      await expectLater(plex.library.matches(const {}), throwsParseError);
    });

    test('randomArtwork, defaultSectionPrefs and ingestTransientItem hand '
        'the answer back, or an empty map without a body', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'Setting': [
            {'id': 'respectTags', 'type': 'bool', 'default': 'false'},
          ],
        },
      });
      final prefs = await plex.library.defaultSectionPrefs(type: '8');
      expect(
        (((prefs['MediaContainer']! as Map)['Setting']! as List).single
            as Map)['id'],
        'respectTags',
      );
      answer({
        'MediaContainer': {
          'size': 1,
          'Metadata': [
            {'ratingKey': '900', 'type': 'movie', 'title': 'a'},
          ],
        },
      });
      final ingested = await plex.library.ingestTransientItem(url: 'file:///a');
      expect((ingested['MediaContainer']! as Map)['size'], 1);
      answer({
        'MediaContainer': {'size': 0},
      });
      expect(await plex.library.randomArtwork(), {
        'MediaContainer': {'size': 0},
      });
      adapter.respond = (_) => CannedResponse(200, const []);
      expect(await plex.library.randomArtwork(), isEmpty);
      expect(await plex.library.defaultSectionPrefs(), isEmpty);
      expect(await plex.library.ingestTransientItem(url: 'file:///a'), isEmpty);
    });
  });
}
