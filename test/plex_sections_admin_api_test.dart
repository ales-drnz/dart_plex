// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Creating, editing, scanning and emptying library sections on the wire,
/// and the section indexes (sorts, first letters, autocomplete, common
/// fields, preferences) against PMS 1.43.2 answers.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/fixtures.dart';
import '_helpers/wire_calls.dart';

void main() {
  group('section management', () {
    testWireCalls([
      (
        'sectionDetails (plain)',
        (p) => p.library.sectionDetails(sectionId: '1'),
        'GET',
        '/library/sections/1',
        {},
      ),
      (
        'sectionDetails (with details)',
        (p) => p.library.sectionDetails(sectionId: '1', includeDetails: true),
        'GET',
        '/library/sections/1',
        {'includeDetails': '1'},
      ),
      (
        'editSection (nothing to change)',
        (p) => p.library.editSection(sectionId: '1'),
        'PUT',
        '/library/sections/1',
        {},
      ),
      (
        'deleteSection (default)',
        (p) => p.library.deleteSection(sectionId: '1'),
        'DELETE',
        '/library/sections/1',
        {'async': '0'},
      ),
      (
        'deleteSection (async)',
        (p) => p.library.deleteSection(sectionId: '1', asyncMode: true),
        'DELETE',
        '/library/sections/1',
        {'async': '1'},
      ),
      (
        'refreshSection (default)',
        (p) => p.library.refreshSection(sectionId: '1'),
        'POST',
        '/library/sections/1/refresh',
        {'force': '0'},
      ),
      (
        'refreshSection (forced, one folder)',
        (p) => p.library.refreshSection(
          sectionId: '1',
          force: true,
          path: '/data/Music/A & B',
        ),
        'POST',
        '/library/sections/1/refresh',
        {'force': '1', 'path': '/data/Music/A & B'},
      ),
      (
        'cancelSectionRefresh',
        (p) => p.library.cancelSectionRefresh(sectionId: '1'),
        'DELETE',
        '/library/sections/1/refresh',
        {},
      ),
      (
        'analyzeSection',
        (p) => p.library.analyzeSection(sectionId: '1'),
        'PUT',
        '/library/sections/1/analyze',
        {},
      ),
      (
        'emptyTrash',
        (p) => p.library.emptyTrash(sectionId: '1'),
        'PUT',
        '/library/sections/1/emptyTrash',
        {},
      ),
      (
        'deleteSectionIndexes',
        (p) => p.library.deleteSectionIndexes(sectionId: '1'),
        'DELETE',
        '/library/sections/1/indexes',
        {},
      ),
      (
        'deleteSectionIntros',
        (p) => p.library.deleteSectionIntros(sectionId: '1'),
        'DELETE',
        '/library/sections/1/intros',
        {},
      ),
      (
        'sectionPreferences (plain)',
        (p) => p.library.sectionPreferences(sectionId: '1'),
        'GET',
        '/library/sections/1/prefs',
        {},
      ),
      (
        'sectionPreferences (of an agent)',
        (p) => p.library.sectionPreferences(
          sectionId: '1',
          agent: 'tv.plex.agents.music',
        ),
        'GET',
        '/library/sections/1/prefs',
        {'agent': 'tv.plex.agents.music'},
      ),
      (
        'setSectionPreferences',
        (p) => p.library.setSectionPreferences(
          sectionId: '1',
          prefs: {'albumSort': 2, 'respectTags': true, 'hidden': '0'},
        ),
        'PUT',
        '/library/sections/1/prefs',
        {'albumSort': '2', 'respectTags': 'true', 'hidden': '0'},
      ),
      (
        'firstCharacters (plain)',
        (p) => p.library.firstCharacters(sectionId: '1'),
        'GET',
        '/library/sections/1/firstCharacter',
        {},
      ),
      (
        'sectionCollections',
        (p) => p.library.sectionCollections(sectionId: '1'),
        'GET',
        '/library/sections/1/collections',
        {},
      ),
      (
        'deleteSectionCollection',
        (p) => p.library.deleteSectionCollection(
          sectionId: '1',
          collectionId: '9',
        ),
        'DELETE',
        '/library/sections/1/collection/9',
        {},
      ),
    ]);
  });

  group('requests whose encoding matters, and answers', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter(const {'MediaContainer': <String, Object?>{}});
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    test(
      'editSection repeats location and wraps prefs as prefs[name]',
      () async {
        await plex.library.editSection(
          sectionId: '1',
          name: 'Music & more',
          scanner: 'Plex Music',
          agent: 'tv.plex.agents.music',
          metadataAgentProviderGroupId: '3',
          language: 'en-US',
          locations: ['/data/Music', '/data/More Music'],
          prefs: {'enableCinemaTrailers': 0, 'albumSort': '2'},
        );
        final request = adapter.last!;
        expect(request.method, 'PUT');
        expect(request.uri.path, '/library/sections/1');
        expect(request.queryParametersAll, {
          'name': ['Music & more'],
          'scanner': ['Plex Music'],
          'agent': ['tv.plex.agents.music'],
          'metadataAgentProviderGroupId': ['3'],
          'language': ['en-US'],
          'location': ['/data/Music', '/data/More Music'],
          'prefs[enableCinemaTrailers]': ['0'],
          'prefs[albumSort]': ['2'],
        });
      },
    );

    test('addSection sends the type on the wire, every location, the flags '
        'as 1/0 and prefs as prefs[name]', () async {
      await plex.library.addSection(
        name: 'Music',
        type: PlexLibraryType.music,
        scanner: 'Plex Music',
        agent: 'tv.plex.agents.music',
        locations: ['/data/Music', '/data/B'],
        metadataAgentProviderGroupId: '3',
        language: 'en-US',
        prefs: {'respectTags': 1},
        relative: false,
        importFromiTunes: true,
      );
      final request = adapter.last!;
      expect(request.method, 'POST');
      expect(request.uri.path, '/library/sections');
      expect(request.queryParametersAll, {
        'name': ['Music'],
        'type': ['artist'],
        'scanner': ['Plex Music'],
        'agent': ['tv.plex.agents.music'],
        'location': ['/data/Music', '/data/B'],
        'metadataAgentProviderGroupId': ['3'],
        'language': ['en-US'],
        'relative': ['0'],
        'importFromiTunes': ['1'],
        'prefs[respectTags]': ['1'],
      });
    });

    test('addSection sends only what it must by default', () async {
      await plex.library.addSection(
        name: 'Films',
        type: PlexLibraryType.movie,
        scanner: 'Plex Movie',
        agent: 'tv.plex.agents.movie',
        locations: ['/data/Movies'],
      );
      expect(adapter.last!.queryParameters, {
        'name': 'Films',
        'type': 'movie',
        'scanner': 'Plex Movie',
        'agent': 'tv.plex.agents.movie',
        'location': '/data/Movies',
      });
    });

    test('sectionPreferences hands the settings back (PMS 1.43.2)', () async {
      answer(realFixture('section_prefs'));
      final prefs = await plex.library.sectionPreferences(sectionId: '1');
      final settings = (prefs['MediaContainer']! as Map)['Setting']! as List;
      expect(settings.map((s) => (s as Map)['id']), ['hidden', 'albumSort']);
      expect((settings.last as Map)['value'], '-1');
    });

    test('sectionPreferences, autocomplete and sectionCommon are an empty '
        'map without a body', () async {
      adapter.respond = (_) => CannedResponse(200, const []);
      expect(await plex.library.sectionPreferences(sectionId: '1'), isEmpty);
      expect(
        await plex.library.autocomplete(
          sectionId: '1',
          type: PlexMetadataType.track,
        ),
        isEmpty,
      );
      expect(
        await plex.library.sectionCommon(
          sectionId: '1',
          type: PlexMetadataType.album,
        ),
        isEmpty,
      );
    });

    test('autocomplete sends the type and the field query (PMS 1.43.2 '
        'answer)', () async {
      answer(realFixture('autocomplete'));
      final found = await plex.library.autocomplete(
        sectionId: '1',
        type: PlexMetadataType.track,
        fieldQuery: {'title.query': 'T & 1'},
      );
      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.uri.path, '/library/sections/1/autocomplete');
      expect(adapter.last!.queryParameters, {
        'type': '10',
        'title.query': 'T & 1',
      });
      final hit =
          ((found['MediaContainer']! as Map)['Metadata']! as List).single
              as Map;
      expect((hit['title'], hit['title.queryRange']), ('Track 1', '0,0'));
    });

    test('sectionCommon sends the type (PMS 1.43.2 answer)', () async {
      answer(realFixture('section_common'));
      final common = await plex.library.sectionCommon(
        sectionId: '1',
        type: PlexMetadataType.album,
      );
      expect(adapter.last!.uri.path, '/library/sections/1/common');
      expect(adapter.last!.queryParameters, {'type': '9'});
      final entry =
          ((common['MediaContainer']! as Map)['Metadata']! as List).single
              as Map;
      expect((entry['type'], entry['mixedFields']), ('common', ''));
    });

    test('firstCharacters sends type and sort, and reads the letters '
        '(PMS 1.43.2)', () async {
      answer(realFixture('first_character'));
      final letters = await plex.library.firstCharacters(
        sectionId: '1',
        type: PlexMetadataType.artist,
        sort: PlexSort.titleSort.desc,
      );
      expect(adapter.last!.uri.path, '/library/sections/1/firstCharacter');
      expect(adapter.last!.queryParameters, {
        'type': '8',
        'sort': 'titleSort:desc',
      });
      expect((letters.single.key, letters.single.title), ('T', 'T'));
      expect(letters.single.raw['size'], 1);
    });

    test('sectionSorts reads the sorts of the section (PMS 1.43.2)', () async {
      answer(realFixture('section_sorts'));
      final sorts = await plex.library.sectionSorts(sectionId: '1');
      expect(adapter.last!.uri.path, '/library/sections/1/sorts');
      expect(sorts.map((s) => (s.key, s.title)), [
        ('titleSort', 'Title'),
        ('userRating', 'Rating'),
      ]);
      expect(sorts.first.raw['defaultDirection'], 'asc');
      expect(sorts.last.raw['descKey'], 'userRating:desc');
    });

    test('sectionCollections reads the collections', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'Metadata': [
            {
              'ratingKey': '914',
              'key': '/library/collections/914/children',
              'type': 'collection',
              'title': 'Favourites',
              'childCount': 3,
            },
          ],
        },
      });
      final c = (await plex.library.sectionCollections(sectionId: '1')).single;
      expect(
        (c.ratingKey, c.type, c.title, c.childCount),
        ('914', PlexMetadataType.collection, 'Favourites', 3),
      );
    });

    test('the section indexes are empty for an empty container, and a '
        'parse error for anything else', () async {
      expect(await plex.library.firstCharacters(sectionId: '1'), isEmpty);
      expect(await plex.library.sectionSorts(sectionId: '1'), isEmpty);
      expect(await plex.library.sectionCollections(sectionId: '1'), isEmpty);
      answer('nope');
      await expectLater(
        plex.library.sectionSorts(sectionId: '1'),
        throwsParseError,
      );
      await expectLater(
        plex.library.sectionCollections(sectionId: '1'),
        throwsParseError,
      );
    });

    test('PlexSectionDetails: the container without its views, and the '
        'views (PMS 1.43.2)', () {
      final details = PlexSectionDetails.fromJson(
        realFixture('section_details'),
      );
      expect(details.librarySectionId, '1');
      expect(details.title, 'Music');
      expect(details.allowSync, isFalse);
      expect(details.views, isNotEmpty);
      expect(details.views.first.key, 'all');
      expect(details.raw.containsKey('Directory'), isFalse);
      final empty = PlexSectionDetails.fromJson(const {});
      expect((empty.title, empty.allowSync), (null, false));
      expect(empty.views, isEmpty);
    });
  });

  test('sectionCompositeImageUrl points at the cover and its version', () {
    final url = testClient(
      CapturingAdapter(),
    ).library.sectionCompositeImageUrl(sectionId: '1', updatedAt: 1791712675);
    expect(Uri.parse(url).origin, 'http://192.168.1.10:32400');
    expect(pathAndToken(url), (
      '/library/sections/1/composite/1791712675',
      'tok',
    ));
  });
}
