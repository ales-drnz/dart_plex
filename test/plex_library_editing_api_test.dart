// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Editing, matching and analysing single items on the wire: what each
/// call sends (booleans as `1`/`0`, lists comma-joined, free maps as they
/// are) and how the few that answer are read.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/fixtures.dart';
import '_helpers/wire_calls.dart';

void main() {
  group('item operations', () {
    testWireCalls([
      (
        'refreshItems (plain)',
        (p) => p.library.refreshItems(ids: '7'),
        'PUT',
        '/library/metadata/7/refresh',
        {},
      ),
      (
        'refreshItems (agent, markUpdated)',
        (p) => p.library.refreshItems(
          ids: '7,8',
          agent: 'tv.plex.agents.music',
          markUpdated: true,
        ),
        'PUT',
        '/library/metadata/7,8/refresh',
        {'agent': 'tv.plex.agents.music', 'markUpdated': '1'},
      ),
      (
        'refreshItems (markUpdated off)',
        (p) => p.library.refreshItems(ids: '7', markUpdated: false),
        'PUT',
        '/library/metadata/7/refresh',
        {'markUpdated': '0'},
      ),
      (
        'analyzeItem (plain)',
        (p) => p.library.analyzeItem(ids: '7'),
        'PUT',
        '/library/metadata/7/analyze',
        {},
      ),
      (
        'analyzeItem (offsets)',
        (p) => p.library.analyzeItem(ids: '7', thumbOffset: 30, artOffset: 90),
        'PUT',
        '/library/metadata/7/analyze',
        {'thumbOffset': '30', 'artOffset': '90'},
      ),
      (
        'detectIntros (default)',
        (p) => p.library.detectIntros(ids: '7'),
        'PUT',
        '/library/metadata/7/intro',
        {'force': '0'},
      ),
      (
        'detectIntros (forced, threshold)',
        (p) => p.library.detectIntros(ids: '7', force: true, threshold: 0.5),
        'PUT',
        '/library/metadata/7/intro',
        {'force': '1', 'threshold': '0.5'},
      ),
      (
        'detectCredits (default)',
        (p) => p.library.detectCredits(ids: '7'),
        'PUT',
        '/library/metadata/7/credits',
        {'force': '0', 'manual': '0'},
      ),
      (
        'detectCredits (forced, manual)',
        (p) => p.library.detectCredits(ids: '7', force: true, manual: true),
        'PUT',
        '/library/metadata/7/credits',
        {'force': '1', 'manual': '1'},
      ),
      (
        'detectAds',
        (p) => p.library.detectAds(ids: '7'),
        'PUT',
        '/library/metadata/7/addetect',
        {},
      ),
      (
        'detectVoiceActivity (default)',
        (p) => p.library.detectVoiceActivity(ids: '7'),
        'PUT',
        '/library/metadata/7/voiceActivity',
        {'force': '0', 'manual': '0'},
      ),
      (
        'detectVoiceActivity (manual only)',
        (p) => p.library.detectVoiceActivity(ids: '7', manual: true),
        'PUT',
        '/library/metadata/7/voiceActivity',
        {'force': '0', 'manual': '1'},
      ),
      (
        'generateChapterThumbs (default)',
        (p) => p.library.generateChapterThumbs(ids: '7'),
        'PUT',
        '/library/metadata/7/chapterThumbs',
        {'force': '0'},
      ),
      (
        'generateChapterThumbs (forced)',
        (p) => p.library.generateChapterThumbs(ids: '7', force: true),
        'PUT',
        '/library/metadata/7/chapterThumbs',
        {'force': '1'},
      ),
      (
        'startBifGeneration (default)',
        (p) => p.library.startBifGeneration(ids: '7'),
        'PUT',
        '/library/metadata/7/index',
        {'force': '0'},
      ),
      (
        'startBifGeneration (forced)',
        (p) => p.library.startBifGeneration(ids: '7', force: true),
        'PUT',
        '/library/metadata/7/index',
        {'force': '1'},
      ),
      (
        'matchItem (plain)',
        (p) => p.library.matchItem(ids: '7'),
        'PUT',
        '/library/metadata/7/match',
        {},
      ),
      (
        'matchItem (guid, name, year)',
        (p) => p.library.matchItem(
          ids: '7',
          guid: 'plex://movie/5d776b59ad5437001f79c6f8?lang=en&x=1',
          name: 'Rock & Roll',
          year: 1999,
        ),
        'PUT',
        '/library/metadata/7/match',
        {
          'guid': 'plex://movie/5d776b59ad5437001f79c6f8?lang=en&x=1',
          'name': 'Rock & Roll',
          'year': '1999',
        },
      ),
      (
        'unmatch',
        (p) => p.library.unmatch(ids: '7'),
        'PUT',
        '/library/metadata/7/unmatch',
        {},
      ),
      (
        'mergeItems',
        (p) => p.library.mergeItems(primaryId: '7', otherIds: ['8', '9']),
        'PUT',
        '/library/metadata/7/merge',
        {'ids': '8,9'},
      ),
      (
        'splitItem',
        (p) => p.library.splitItem(ids: '7'),
        'PUT',
        '/library/metadata/7/split',
        {},
      ),
      (
        'setItemPreferences',
        (p) => p.library.setItemPreferences(
          ids: '7',
          args: {'episodeSort': 1, 'languageOverride': 'it-IT'},
        ),
        'PUT',
        '/library/metadata/7/prefs',
        {'episodeSort': '1', 'languageOverride': 'it-IT'},
      ),
      (
        'addExtra',
        (p) => p.library.addExtra(
          ids: '7',
          extraType: 'trailer',
          url: 'https://example.com/a b.mp4?x=1&y=2',
        ),
        'POST',
        '/library/metadata/7/extras',
        {'extraType': 'trailer', 'url': 'https://example.com/a b.mp4?x=1&y=2'},
      ),
      (
        'editItem',
        (p) => p.library.editItem(
          ids: '7',
          type: PlexMetadataType.album,
          args: {'title.value': 'A & B', 'title.locked': 1},
        ),
        'PUT',
        '/library/metadata/7',
        {'type': '9', 'title.value': 'A & B', 'title.locked': '1'},
      ),
      (
        'deleteMetadataItem (plain)',
        (p) => p.library.deleteMetadataItem(ids: '7'),
        'DELETE',
        '/library/metadata/7',
        {},
      ),
      (
        'deleteMetadataItem (proxy)',
        (p) => p.library.deleteMetadataItem(ids: '7', proxy: true),
        'DELETE',
        '/library/metadata/7',
        {'proxy': '1'},
      ),
      (
        'setItemArtwork (from a URL)',
        (p) => p.library.setItemArtwork(
          ids: '7',
          element: 'thumb',
          url: 'https://example.com/p.jpg?size=1&v=2',
        ),
        'POST',
        '/library/metadata/7/thumb',
        {'url': 'https://example.com/p.jpg?size=1&v=2'},
      ),
      (
        'setItemArtwork (update)',
        (p) => p.library.setItemArtwork(
          ids: '7',
          element: 'art',
          url: 'upload://posters/1',
          update: true,
        ),
        'PUT',
        '/library/metadata/7/art',
        {'url': 'upload://posters/1'},
      ),
    ]);
  });

  group('requests with a body, and answers', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    test('setItemArtwork uploads the bytes as the body, unencoded', () async {
      await plex.library.setItemArtwork(
        ids: '7',
        element: 'poster',
        data: [0xff, 0xd8, 0xff, 0x00],
      );
      final request = adapter.last!;
      expect(request.method, 'POST');
      expect(request.uri.path, '/library/metadata/7/poster');
      expect(request.uri.query, isEmpty);
      expect(request.body, [0xff, 0xd8, 0xff, 0x00]);
    });

    test('addSubtitles sends the file and its flags as 1/0', () async {
      await plex.library.addSubtitles(
        ids: '7',
        title: 'Director & cast',
        language: 'ita',
        url: 'file:///subs/a b.srt',
        format: 'srt',
        mediaItemID: '12',
        forced: true,
        hearingImpaired: false,
      );
      // The verb is left out on purpose: which one attaches a subtitle is
      // not settled against a server.
      expect(adapter.last!.uri.path, '/library/metadata/7/subtitles');
      expect(adapter.last!.queryParameters, {
        'title': 'Director & cast',
        'language': 'ita',
        'url': 'file:///subs/a b.srt',
        'format': 'srt',
        'mediaItemID': '12',
        'forced': '1',
        'hearingImpaired': '0',
      });
    });

    test('addSubtitles leaves out what was not given', () async {
      await plex.library.addSubtitles(
        ids: '7',
        title: 'T',
        language: 'eng',
        url: 'file:///s.srt',
      );
      expect(adapter.last!.queryParameters.keys, ['title', 'language', 'url']);
    });

    test(
      'listMatches asks with every hint and hands the answer back',
      () async {
        answer({
          'MediaContainer': {
            'size': 1,
            'SearchResult': [
              {'guid': 'plex://album/1', 'name': 'Test Album', 'score': 96},
            ],
          },
        });
        final matches = await plex.library.listMatches(
          ids: '2',
          title: 'Test Album',
          parentTitle: 'Test Artist',
          agent: 'tv.plex.agents.music',
          language: 'en-US',
          year: 2020,
          manual: true,
        );
        expect(adapter.last!.method, 'PUT');
        expect(adapter.last!.uri.path, '/library/metadata/2/matches');
        expect(adapter.last!.queryParameters, {
          'title': 'Test Album',
          'parentTitle': 'Test Artist',
          'agent': 'tv.plex.agents.music',
          'language': 'en-US',
          'year': '2020',
          'manual': '1',
        });
        final results = (matches['MediaContainer']! as Map)['SearchResult'];
        expect(((results as List).single as Map)['score'], 96);
      },
    );

    test(
      'listMatches without hints sends none; no body is an empty map',
      () async {
        adapter.respond = (_) => CannedResponse(200, const []);
        expect(await plex.library.listMatches(ids: '2'), isEmpty);
        expect(adapter.last!.uri.query, isEmpty);
      },
    );

    test('relatedItems reads the hubs and their items', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'Hub': [
            {
              'hubKey': '/library/metadata/9,10',
              'key': '/library/metadata/2/related?hub=similar',
              'hubIdentifier': 'album.similar',
              'title': 'Similar Albums',
              'type': 'album',
              'size': 2,
              'more': true,
              'Metadata': [
                {'ratingKey': '9', 'type': 'album', 'title': 'Nine'},
                {'ratingKey': '10', 'type': 'album', 'title': 'Ten'},
              ],
            },
          ],
        },
      });
      final hub = (await plex.library.relatedItems(ids: '2')).single;
      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.uri.path, '/library/metadata/2/related');
      expect(hub.hubIdentifier, 'album.similar');
      expect(
        (hub.title, hub.type, hub.size, hub.more),
        ('Similar Albums', 'album', 2, true),
      );
      expect(hub.items.map((i) => i.ratingKey), ['9', '10']);
      expect(hub.items.first.type, PlexMetadataType.album);
    });

    test('extras reads the metadata entries', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'Metadata': [
            {
              'ratingKey': '31',
              'type': 'clip',
              'title': 'Trailer',
              'subtype': 'trailer',
              'duration': 120000,
            },
          ],
        },
      });
      final extra = (await plex.library.extras(ids: '7')).single;
      expect(adapter.last!.uri.path, '/library/metadata/7/extras');
      expect((extra.ratingKey, extra.title), ('31', 'Trailer'));
      expect(extra.durationMs, 120000);
    });

    test('related and extras of an item that has none are empty '
        '(PMS 1.43.2 answers a bare container)', () async {
      answer({
        'MediaContainer': {
          'size': 0,
          'identifier': 'com.plexapp.plugins.library',
        },
      });
      expect(await plex.library.relatedItems(ids: '2'), isEmpty);
      expect(await plex.library.extras(ids: '2'), isEmpty);
    });

    test('a list where the container should be is a parse error', () async {
      answer(['not', 'a', 'container']);
      await expectLater(plex.library.extras(ids: '2'), throwsParseError);
      await expectLater(plex.library.relatedItems(ids: '2'), throwsParseError);
    });

    test('itemTree hands back the nested tree (PMS 1.43.2)', () async {
      answer(realFixture('item_tree'));
      final tree = await plex.library.itemTree(ids: '1');
      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.uri.path, '/library/metadata/1/tree');
      final artist =
          ((tree['MediaContainer']! as Map)['MetadataItem']! as List).single
              as Map;
      final album = (artist['MetadataItem']! as List).single as Map;
      final track = (album['MetadataItem']! as List).single as Map;
      expect(
        (artist['title'], album['title'], track['title']),
        ('Test Artist', 'Test Album', 'Track 1'),
      );
      expect(track.containsKey('MediaItem'), isTrue);
    });

    test('itemTree and topUsers answer an empty map to no body', () async {
      adapter.respond = (_) => CannedResponse(200, const []);
      expect(await plex.library.itemTree(ids: '1'), isEmpty);
      expect(await plex.library.topUsers(ids: '1'), isEmpty);
      expect(adapter.last!.uri.path, '/library/metadata/1/users/top');
    });

    test('topUsers hands the answer back', () async {
      answer({
        'MediaContainer': {
          'Account': [
            {'id': 1, 'globalViewCount': 12},
          ],
        },
      });
      final top = await plex.library.topUsers(ids: '3');
      expect(adapter.last!.method, 'GET');
      expect((top['MediaContainer']! as Map)['Account'], [
        {'id': 1, 'globalViewCount': 12},
      ]);
    });
  });

  group('URLs for a player', () {
    late PlexClient plex;

    setUp(() => plex = testClient(CapturingAdapter()));

    test('itemFileUrl carries the bundle path, encoded, and the token', () {
      final url = Uri.parse(
        plex.library.itemFileUrl(ids: '7', url: 'Contents/a b&c.jpg'),
      );
      expect(url.origin, 'http://192.168.1.10:32400');
      expect(url.path, '/library/metadata/7/file');
      expect(url.queryParameters, {
        'url': 'Contents/a b&c.jpg',
        'X-Plex-Token': 'tok',
      });
    });

    test('itemArtworkUrl points at the element and its version', () {
      final url = plex.library.itemArtworkUrl(
        ids: '7',
        element: 'thumb',
        timestamp: 1794079152,
      );
      expect(Uri.parse(url).origin, 'http://192.168.1.10:32400');
      expect(pathAndToken(url), (
        '/library/metadata/7/thumb/1794079152',
        'tok',
      ));
    });
  });
}
