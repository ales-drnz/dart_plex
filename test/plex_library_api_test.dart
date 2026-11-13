// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The library API's typed answers: tags, section details, people,
/// folders, and the item options.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/fixtures.dart';

void main() {
  group('library answers', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    test('library tags (PMS 1.43.2) are filterable', () async {
      answer(realFixture('library_tags'));
      final tags = await plex.library.tags(type: PlexMetadataType.album);
      expect(adapter.last!.queryParameters['type'], '9');
      expect(tags.single.title, 'Rock');
      expect(PlexFilter.of(tags.single).toString(), 'genre=5');
    });

    test('section details (PMS 1.43.2)', () async {
      answer(realFixture('section_details'));
      final d = await plex.library.sectionDetails(sectionId: '1');
      expect(d.title, 'Music');
      expect(d.views.map((v) => (v.key, v.secondary, v.search)), [
        ('all', false, false),
        ('genre', true, false),
        ('search?type=8', false, true),
      ]);
      expect(d.raw.containsKey('Directory'), isFalse);
    });

    test('person and folder', () async {
      answer({
        'MediaContainer': {
          'Directory': [
            {'id': 9, 'tag': 'Someone', 'thumb': '/t'},
          ],
        },
      });
      expect((await plex.library.person(personId: '9'))!.name, 'Someone');
      answer({
        'MediaContainer': {
          'totalSize': 2,
          'Metadata': [
            {'key': '/library/sections/10/folder?parent=3706', 'title': 'A'},
            {'ratingKey': '98901', 'type': 'photo', 'title': 'root.jpg'},
          ],
        },
      });
      final page = await plex.library.folder(
        sectionId: '10',
        parent: '3706',
        size: 50,
      );
      expect(adapter.last!.uri.path, '/library/sections/10/folder');
      expect(adapter.last!.queryParameters['parent'], '3706');
      expect(page.items.first.key, contains('parent=3706'));
    });

    test('item() asks for markers and chapters only when told', () async {
      answer({
        'MediaContainer': {
          'Metadata': [
            {'ratingKey': '1'},
          ],
        },
      });
      await plex.library.item(ratingKey: '1');
      expect(adapter.last!.uri.query, isEmpty);
      await plex.library.item(
        ratingKey: '1',
        includeMarkers: true,
        includeChapters: true,
      );
      expect(adapter.last!.queryParameters, {
        'includeMarkers': '1',
        'includeChapters': '1',
      });
    });
  });

  group('ids in a request path', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter(const {'MediaContainer': <String, Object?>{}});
      plex = testClient(adapter);
    });

    test('an id with a slash stays one encoded segment', () async {
      await plex.library.children(ratingKey: 'a/b?c#d');
      expect(
        adapter.last!.uri.path,
        '/library/metadata/a%2Fb%3Fc%23d/children',
      );
      expect(adapter.last!.uri.query, isEmpty);
      await plex.library.sectionSorts(sectionId: '../1');
      expect(adapter.last!.uri.path, '/library/sections/..%2F1/sorts');
      await plex.library.deleteSectionCollection(
        sectionId: '1',
        collectionId: '5/../6',
      );
      expect(
        adapter.last!.uri.path,
        '/library/sections/1/collection/5%2F..%2F6',
      );
      await plex.library.setStreamOffset(
        streamId: '2/1',
        ext: 's rt',
        offsetMs: 100,
      );
      expect(adapter.last!.uri.path, '/library/streams/2%2F1.s%20rt');
    });

    test('a list of rating keys keeps its commas', () async {
      await plex.library.editItem(ids: '1,2,3', args: {'title.value': 'T'});
      expect(adapter.last!.uri.path, '/library/metadata/1,2,3');
    });

    test('an empty id, "." and ".." are refused before any request', () {
      expect(() => plex.library.children(ratingKey: ''), throwsArgumentError);
      expect(() => plex.library.item(ratingKey: '..'), throwsArgumentError);
      expect(() => plex.library.unmatch(ids: '.'), throwsArgumentError);
      expect(
        () => plex.library.deleteMarker(ids: '7', marker: ''),
        throwsArgumentError,
      );
      expect(
        () => plex.library.emptyTrash(sectionId: '..'),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });
  });
}
