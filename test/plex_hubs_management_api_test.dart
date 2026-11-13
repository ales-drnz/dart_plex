// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The hub rails and the management of a section's hubs on the wire
/// (`forMetadata` is in `plex_hubs_api_test.dart`): what each call sends,
/// and the hubs and items read, against PMS 1.43.2 answers where the test
/// server has them.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/fixtures.dart';
import '_helpers/wire_calls.dart';

const _hubs = {
  'MediaContainer': {
    'size': 1,
    'allowSync': true,
    'identifier': 'com.plexapp.plugins.library',
    'Hub': [
      {
        'key': '/hubs/sections/1/recentlyAdded',
        'hubKey': '/library/metadata/2',
        'title': 'Recently Added Music',
        'type': 'album',
        'hubIdentifier': 'music.recent.added.1',
        'context': 'hub.music.recent.added',
        'size': 1,
        'more': false,
        'style': 'shelf',
        'promoted': true,
        'Metadata': [
          {
            'ratingKey': '2',
            'type': 'album',
            'title': 'Test Album',
            'parentTitle': 'Test Artist',
          },
        ],
      },
    ],
  },
};

const _items = {
  'MediaContainer': {
    'size': 2,
    'Metadata': [
      {'ratingKey': '3', 'type': 'track', 'title': 'Track 1'},
      {'ratingKey': '4', 'type': 'track', 'title': 'Track 2'},
    ],
  },
};

void main() {
  group('hub requests', () {
    testWireCalls([
      (
        'global (default)',
        (p) => p.hubs.global(),
        'GET',
        '/hubs',
        {'count': '16', 'onlyTransient': '0', 'includeMeta': '1'},
      ),
      (
        'global (transient only, no meta)',
        (p) => p.hubs.global(count: 3, onlyTransient: true, includeMeta: false),
        'GET',
        '/hubs',
        {'count': '3', 'onlyTransient': '1', 'includeMeta': '0'},
      ),
      (
        'forSection (default)',
        (p) => p.hubs.forSection(sectionId: '1'),
        'GET',
        '/hubs/sections/1',
        {'count': '16', 'onlyTransient': '0', 'includeMeta': '1'},
      ),
      (
        'forSection (transient only, no meta)',
        (p) => p.hubs.forSection(
          sectionId: '1',
          count: 5,
          onlyTransient: true,
          includeMeta: false,
        ),
        'GET',
        '/hubs/sections/1',
        {'count': '5', 'onlyTransient': '1', 'includeMeta': '0'},
      ),
      (
        'promoted (default)',
        (p) => p.hubs.promoted(),
        'GET',
        '/hubs/promoted',
        {'count': '16'},
      ),
      (
        'promoted (count)',
        (p) => p.hubs.promoted(count: 2),
        'GET',
        '/hubs/promoted',
        {'count': '2'},
      ),
      (
        'continueWatching',
        (p) => p.hubs.continueWatching(count: 4),
        'GET',
        '/hubs/continueWatching',
        {'count': '4'},
      ),
      (
        'sectionOnDeck (default)',
        (p) => p.hubs.sectionOnDeck(sectionId: '1'),
        'GET',
        '/library/sections/1/onDeck',
        {'X-Plex-Container-Start': '0', 'X-Plex-Container-Size': '16'},
      ),
      (
        'sectionOnDeck (count)',
        (p) => p.hubs.sectionOnDeck(sectionId: '1', count: 5),
        'GET',
        '/library/sections/1/onDeck',
        {'X-Plex-Container-Start': '0', 'X-Plex-Container-Size': '5'},
      ),
      (
        'itemsByIdentifier (default page)',
        (p) => p.hubs.itemsByIdentifier(identifier: 'home.continue'),
        'GET',
        '/hubs/items',
        {
          'identifier': 'home.continue',
          'X-Plex-Container-Start': '0',
          'X-Plex-Container-Size': '50',
        },
      ),
      (
        'itemsByIdentifier (a page)',
        (p) => p.hubs.itemsByIdentifier(
          identifier: 'music.recent.added.1',
          start: 50,
          size: 10,
        ),
        'GET',
        '/hubs/items',
        {
          'identifier': 'music.recent.added.1',
          'X-Plex-Container-Start': '50',
          'X-Plex-Container-Size': '10',
        },
      ),
      (
        'postplay (plain)',
        (p) => p.hubs.postplay(metadataId: '3'),
        'GET',
        '/hubs/metadata/3/postplay',
        {},
      ),
      (
        'postplay (transient only)',
        (p) => p.hubs.postplay(metadataId: '3', onlyTransient: true),
        'GET',
        '/hubs/metadata/3/postplay',
        {'onlyTransient': '1'},
      ),
      (
        'related (plain)',
        (p) => p.hubs.related(metadataId: '2'),
        'GET',
        '/hubs/metadata/2/related',
        {},
      ),
      (
        'related (not only transient)',
        (p) => p.hubs.related(metadataId: '2', onlyTransient: false),
        'GET',
        '/hubs/metadata/2/related',
        {'onlyTransient': '0'},
      ),
      (
        'manage (plain)',
        (p) => p.hubs.manage(sectionId: '1'),
        'GET',
        '/hubs/sections/1/manage',
        {},
      ),
      (
        'manage (of an item)',
        (p) => p.hubs.manage(sectionId: '1', metadataItemId: '914'),
        'GET',
        '/hubs/sections/1/manage',
        {'metadataItemId': '914'},
      ),
      (
        'createCustom (default)',
        (p) => p.hubs.createCustom(sectionId: '1', metadataItemId: '914'),
        'POST',
        '/hubs/sections/1/manage',
        {
          'metadataItemId': '914',
          'promotedToRecommended': '0',
          'promotedToOwnHome': '0',
          'promotedToSharedHome': '0',
        },
      ),
      (
        'createCustom (promoted)',
        (p) => p.hubs.createCustom(
          sectionId: '1',
          metadataItemId: '914',
          promotedToRecommended: true,
          promotedToSharedHome: true,
        ),
        'POST',
        '/hubs/sections/1/manage',
        {
          'metadataItemId': '914',
          'promotedToRecommended': '1',
          'promotedToOwnHome': '0',
          'promotedToSharedHome': '1',
        },
      ),
      (
        'updateVisibility (nothing to change)',
        (p) =>
            p.hubs.updateVisibility(sectionId: '1', identifier: 'music.mixes'),
        'PUT',
        '/hubs/sections/1/manage/music.mixes',
        {},
      ),
      (
        'updateVisibility',
        (p) => p.hubs.updateVisibility(
          sectionId: '1',
          identifier: 'music.mixes',
          promotedToRecommended: false,
          promotedToOwnHome: true,
          promotedToSharedHome: false,
        ),
        'PUT',
        '/hubs/sections/1/manage/music.mixes',
        {
          'promotedToRecommended': '0',
          'promotedToOwnHome': '1',
          'promotedToSharedHome': '0',
        },
      ),
      (
        'deleteCustom',
        (p) => p.hubs.deleteCustom(
          sectionId: '1',
          identifier: 'custom.collection.1.914',
        ),
        'DELETE',
        '/hubs/sections/1/manage/custom.collection.1.914',
        {},
      ),
      (
        'move (to the start)',
        (p) => p.hubs.move(sectionId: '1', identifier: 'music.mixes'),
        'PUT',
        '/hubs/sections/1/manage/move',
        {'identifier': 'music.mixes', 'after': ''},
      ),
      (
        'move (after another)',
        (p) => p.hubs.move(
          sectionId: '1',
          identifier: 'music.mixes',
          afterIdentifier: 'music.recent.played',
        ),
        'PUT',
        '/hubs/sections/1/manage/move',
        {'identifier': 'music.mixes', 'after': 'music.recent.played'},
      ),
      (
        'resetSection',
        (p) => p.hubs.resetSection(sectionId: '1'),
        'DELETE',
        '/hubs/sections/1/manage',
        {},
      ),
      (
        'drill (by identifier)',
        (p) => p.hubs.drill(hubKeyOrIdentifier: 'home.continue'),
        'GET',
        '/hubs/home.continue/items',
        {'X-Plex-Container-Start': '0', 'X-Plex-Container-Size': '50'},
      ),
      (
        'drill (by key, a page)',
        (p) => p.hubs.drill(
          hubKeyOrIdentifier: '/hubs/sections/1/recentlyAdded',
          start: 20,
          size: 10,
        ),
        'GET',
        '/hubs/sections/1/recentlyAdded',
        {'X-Plex-Container-Start': '20', 'X-Plex-Container-Size': '10'},
      ),
    ]);

    test('drill keeps the query a hub key already carries', () async {
      final adapter = CapturingAdapter(_items);
      await testClient(adapter).hubs.drill(
        hubKeyOrIdentifier: '/library/sections/1/all?type=9&sort=addedAt:desc',
        size: 5,
      );
      expect(adapter.last!.uri.path, '/library/sections/1/all');
      expect(adapter.last!.queryParameters, {
        'type': '9',
        'sort': 'addedAt:desc',
        'X-Plex-Container-Start': '0',
        'X-Plex-Container-Size': '5',
      });
    });
  });

  group('answers', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    test('the hub rails read hubs with their items', () async {
      answer(_hubs);
      for (final hubs in [
        await plex.hubs.global(),
        await plex.hubs.forSection(sectionId: '1'),
        await plex.hubs.promoted(),
        await plex.hubs.postplay(metadataId: '3'),
        await plex.hubs.related(metadataId: '2'),
      ]) {
        final hub = hubs.single;
        expect(
          (hub.key, hub.hubKey),
          ('/hubs/sections/1/recentlyAdded', '/library/metadata/2'),
        );
        expect(
          (hub.hubIdentifier, hub.title, hub.type),
          ('music.recent.added.1', 'Recently Added Music', 'album'),
        );
        expect((hub.size, hub.more), (1, false));
        expect(
          (hub.items.single.ratingKey, hub.items.single.parentTitle),
          ('2', 'Test Artist'),
        );
        expect(hub.raw['style'], 'shelf');
      }
    });

    test('an item without related or post-play hubs has none (PMS 1.43.2 '
        'answers a container with no Hub)', () async {
      answer({
        'MediaContainer': {
          'size': 0,
          'allowSync': true,
          'identifier': 'com.plexapp.plugins.library',
        },
      });
      expect(await plex.hubs.related(metadataId: '2'), isEmpty);
      expect(await plex.hubs.postplay(metadataId: '3'), isEmpty);
    });

    test('sectionOnDeck, itemsByIdentifier and drill read items', () async {
      answer(_items);
      for (final items in [
        await plex.hubs.sectionOnDeck(sectionId: '1'),
        await plex.hubs.itemsByIdentifier(identifier: 'home.continue'),
        await plex.hubs.drill(hubKeyOrIdentifier: 'home.continue'),
      ]) {
        expect(items.map((i) => (i.ratingKey, i.title)), [
          ('3', 'Track 1'),
          ('4', 'Track 2'),
        ]);
        expect(items.first.type, PlexMetadataType.track);
      }
    });

    test('continueWatching with nothing to continue is empty '
        '(PMS 1.43.2)', () async {
      answer(realFixture('hubs_continue_watching'));
      expect(await plex.hubs.continueWatching(), isEmpty);
    });

    test(
      'continueWatching reads the items of the rail PMS answers with',
      () async {
        // PMS 1.43.2 answers `/hubs/continueWatching` with one `Hub`
        // (hubIdentifier `continueWatching`); its items sit inside it.
        final fixture = realFixture('hubs_continue_watching');
        final hub =
            ((fixture['MediaContainer']! as Map)['Hub']! as List).single as Map;
        answer({
          'MediaContainer': {
            'size': 1,
            'Hub': [
              {
                ...hub,
                'size': 2,
                'Metadata': (_items['MediaContainer']! as Map)['Metadata'],
              },
            ],
          },
        });
        final items = await plex.hubs.continueWatching();
        expect(items.map((i) => i.ratingKey), ['3', '4']);
      },
      skip:
          'BUG: hubs.continueWatching reads a top-level Metadata, but PMS '
          '1.43.2 answers a Hub that holds the items: always empty',
    );

    test('manage lists the hubs of a section (PMS 1.43.2): titles and '
        'promotion flags', () async {
      answer(realFixture('hubs_manage'));
      final hubs = await plex.hubs.manage(sectionId: '1');
      expect(hubs.map((h) => h.title), [
        'Mixes For You',
        'Recently Played Music',
      ]);
      expect(hubs.first.raw['promotedToRecommended'], isTrue);
      expect(hubs.first.raw['promotedToOwnHome'], isFalse);
      expect(hubs.first.raw['recommendationsVisibility'], 'all');
      expect(hubs.first.items, isEmpty);
    });

    test(
      'manage gives each hub the identifier the other calls take',
      () async {
        answer(realFixture('hubs_manage'));
        final hubs = await plex.hubs.manage(sectionId: '1');
        expect(hubs.map((h) => h.hubIdentifier), [
          'music.mixes',
          'music.recent.played',
        ]);
      },
      skip:
          'BUG: PMS 1.43.2 names it `identifier` in /hubs/sections/{id}/manage; '
          'PlexHub.fromJson reads only `hubIdentifier`, so it is empty',
    );

    test('a body that is not a container is a parse error', () async {
      answer([1, 2]);
      await expectLater(plex.hubs.global(), throwsParseError);
      await expectLater(plex.hubs.manage(sectionId: '1'), throwsParseError);
      await expectLater(
        plex.hubs.drill(hubKeyOrIdentifier: 'x'),
        throwsParseError,
      );
    });
  });
}
