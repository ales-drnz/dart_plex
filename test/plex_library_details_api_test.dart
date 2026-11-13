// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Markers, streams, parts and people of single items on the wire, the
/// URLs built for a player, and the models they read: [PlexMarker],
/// [PlexChapter], [PlexStream] and [PlexPerson].
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/wire_calls.dart';

void main() {
  group('markers, streams and parts', () {
    testWireCalls([
      (
        'createMarker',
        (p) => p.library.createMarker(
          ids: '7',
          type: PlexMarkerType.intro,
          startTimeOffset: 1000,
          endTimeOffset: 61000,
        ),
        'POST',
        '/library/metadata/7/marker',
        {'type': 'intro', 'startTimeOffset': '1000', 'endTimeOffset': '61000'},
      ),
      (
        'createMarker (with attributes)',
        (p) => p.library.createMarker(
          ids: '7',
          type: PlexMarkerType.credits,
          startTimeOffset: 0,
          endTimeOffset: 5,
          attributes: {'attributes[final]': 1},
        ),
        'POST',
        '/library/metadata/7/marker',
        {
          'type': 'credits',
          'startTimeOffset': '0',
          'endTimeOffset': '5',
          'attributes[final]': '1',
        },
      ),
      (
        'editMarker (nothing to change)',
        (p) => p.library.editMarker(ids: '7', marker: '3'),
        'PUT',
        '/library/metadata/7/marker/3',
        {},
      ),
      (
        'editMarker',
        (p) => p.library.editMarker(
          ids: '7',
          marker: '3',
          type: PlexMarkerType.commercial,
          startTimeOffset: 10,
          endTimeOffset: 20,
          attributes: {'title': 'Ad & more'},
        ),
        'PUT',
        '/library/metadata/7/marker/3',
        {
          'type': 'commercial',
          'startTimeOffset': '10',
          'endTimeOffset': '20',
          'title': 'Ad & more',
        },
      ),
      (
        'deleteMarker',
        (p) => p.library.deleteMarker(ids: '7', marker: '3'),
        'DELETE',
        '/library/metadata/7/marker/3',
        {},
      ),
      (
        'deleteMediaItem',
        (p) => p.library.deleteMediaItem(ids: '7', mediaItem: '11'),
        'DELETE',
        '/library/metadata/7/media/11',
        {},
      ),
      (
        'deleteMediaItem (proxy off)',
        (p) =>
            p.library.deleteMediaItem(ids: '7', mediaItem: '11', proxy: false),
        'DELETE',
        '/library/metadata/7/media/11',
        {'proxy': '0'},
      ),
      (
        'setStreamOffset',
        (p) => p.library.setStreamOffset(
          streamId: '21',
          ext: 'srt',
          offsetMs: -250,
        ),
        'PUT',
        '/library/streams/21.srt',
        {'offset': '-250'},
      ),
      (
        'deleteStream',
        (p) => p.library.deleteStream(streamId: '21', ext: 'srt'),
        'DELETE',
        '/library/streams/21.srt',
        {},
      ),
      (
        'setPartStreamSelection (nothing chosen)',
        (p) => p.library.setPartStreamSelection(partId: '5'),
        'PUT',
        '/library/parts/5',
        {},
      ),
      (
        'setPartStreamSelection',
        (p) => p.library.setPartStreamSelection(
          partId: '5',
          audioStreamID: '21',
          subtitleStreamID: '0',
          allParts: true,
        ),
        'PUT',
        '/library/parts/5',
        {'audioStreamID': '21', 'subtitleStreamID': '0', 'allParts': '1'},
      ),
      (
        'streamLoudness',
        (p) => p.library.streamLoudness(streamId: '21'),
        'GET',
        '/library/streams/21/loudness',
        {},
      ),
      (
        'streamLoudness (subsampled)',
        (p) => p.library.streamLoudness(streamId: '21', subsample: 8),
        'GET',
        '/library/streams/21/loudness',
        {'subsample': '8'},
      ),
      (
        'streamLevels',
        (p) => p.library.streamLevels(streamId: '21', subsample: 128),
        'GET',
        '/library/streams/21/levels',
        {'subsample': '128'},
      ),
      (
        'partIndex',
        (p) => p.library.partIndex(partId: '5', index: 'sd'),
        'GET',
        '/library/parts/5/indexes/sd',
        {},
      ),
      (
        'partIndex (interval)',
        (p) => p.library.partIndex(partId: '5', index: 'sd', interval: 10000),
        'GET',
        '/library/parts/5/indexes/sd',
        {'interval': '10000'},
      ),
      (
        'personMedia',
        (p) => p.library.personMedia(personId: '9'),
        'GET',
        '/library/people/9/media',
        {},
      ),
      (
        'sonicPath',
        (p) => p.library.sonicPath(sectionId: '1', startId: '3', endId: '5'),
        'GET',
        '/library/sections/1/computePath',
        {'startID': '3', 'endID': '5'},
      ),
      (
        'sonicPath (maxDistance)',
        (p) => p.library.sonicPath(
          sectionId: '1',
          startId: '3',
          endId: '5',
          maxDistance: 0.25,
        ),
        'GET',
        '/library/sections/1/computePath',
        {'startID': '3', 'endID': '5', 'maxDistance': '0.25'},
      ),
      (
        'nearestInSection (tracks by default)',
        (p) => p.library.nearestInSection(sectionId: '1', values: [0.5, -1, 2]),
        'GET',
        '/library/sections/1/nearest',
        {'type': '10', 'values': '0.5,-1,2'},
      ),
      (
        'nearestInSection (type, limit, maxDistance)',
        (p) => p.library.nearestInSection(
          sectionId: '1',
          values: [1],
          type: 9,
          limit: 20,
          maxDistance: 0.1,
        ),
        'GET',
        '/library/sections/1/nearest',
        {'type': '9', 'values': '1', 'limit': '20', 'maxDistance': '0.1'},
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

    test('streamLoudness and streamLevels hand the samples back', () async {
      answer({
        'MediaContainer': {
          'size': 2,
          'Loudness': [
            {'v': -23.5},
            {'v': -18},
          ],
        },
      });
      final loudness = await plex.library.streamLoudness(streamId: '21');
      expect((loudness['MediaContainer']! as Map)['Loudness'], hasLength(2));
      answer({
        'MediaContainer': {
          'size': 1,
          'totalSamples': '4096',
          'Level': [
            {'v': -60.2},
          ],
        },
      });
      final levels = await plex.library.streamLevels(streamId: '21');
      expect((levels['MediaContainer']! as Map)['totalSamples'], '4096');
    });

    test('loudness, levels and part index are an empty map without a '
        'body', () async {
      adapter.respond = (_) => CannedResponse(200, const []);
      expect(await plex.library.streamLoudness(streamId: '21'), isEmpty);
      expect(await plex.library.streamLevels(streamId: '21'), isEmpty);
      expect(await plex.library.partIndex(partId: '5', index: 'sd'), isEmpty);
    });

    test('a stream without loudness is a not-found error '
        '(PMS 1.43.2 answers 404)', () async {
      adapter.respond = (_) => CannedResponse(
        404,
        '<html><head><title>Not Found</title></head></html>'.codeUnits,
        contentType: 'text/html',
      );
      await expectLater(
        plex.library.streamLoudness(streamId: '1'),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.notFound)
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('personMedia reads the items credited to a person', () async {
      answer({
        'MediaContainer': {
          'size': 2,
          'Metadata': [
            {'ratingKey': '40', 'type': 'movie', 'title': 'One', 'year': 1999},
            {'ratingKey': '41', 'type': 'show', 'title': 'Two'},
          ],
        },
      });
      final media = await plex.library.personMedia(personId: '9');
      expect(media.map((m) => (m.ratingKey, m.type, m.title)), [
        ('40', PlexMetadataType.movie, 'One'),
        ('41', PlexMetadataType.show, 'Two'),
      ]);
      expect(media.first.year, 1999);
    });

    test('personMedia of nobody is empty (PMS 1.43.2 answers a bare '
        'container); a list is a parse error', () async {
      answer({
        'MediaContainer': {
          'size': 0,
          'identifier': 'com.plexapp.plugins.library',
        },
      });
      expect(await plex.library.personMedia(personId: '1'), isEmpty);
      answer([1, 2]);
      await expectLater(
        plex.library.personMedia(personId: '1'),
        throwsParseError,
      );
    });

    test('person reads id, name and thumb, and is null when the answer '
        'holds none', () async {
      answer({
        'MediaContainer': {
          'Directory': [
            {'id': 9, 'tag': 'Ann Actor', 'thumb': 'https://example.com/a.jpg'},
          ],
        },
      });
      final person = (await plex.library.person(personId: '9'))!;
      expect(adapter.last!.uri.path, '/library/people/9');
      expect(
        (person.id, person.name, person.thumb),
        (9, 'Ann Actor', 'https://example.com/a.jpg'),
      );
      expect(person.raw['tag'], 'Ann Actor');
      answer({
        'MediaContainer': {'size': 0},
      });
      expect(await plex.library.person(personId: '9'), isNull);
    });

    test('sonicPath and nearestInSection read tracks with their '
        'distance', () async {
      answer({
        'MediaContainer': {
          'Metadata': [
            {'ratingKey': '3', 'type': 'track', 'title': 'A', 'distance': 0},
            {'ratingKey': '4', 'type': 'track', 'title': 'B', 'distance': 0.12},
          ],
        },
      });
      final path = await plex.library.sonicPath(
        sectionId: '1',
        startId: '3',
        endId: '4',
      );
      expect(path.map((t) => t.distance), [0, 0.12]);
      final near = await plex.library.nearestInSection(
        sectionId: '1',
        values: [0.1],
      );
      expect(near.last.ratingKey, '4');
    });

    test('item() reads markers and chapters when asked', () async {
      answer({
        'MediaContainer': {
          'Metadata': [
            {
              'ratingKey': '7',
              'type': 'episode',
              'title': 'Pilot',
              'Marker': [
                {
                  'id': 1,
                  'type': 'intro',
                  'startTimeOffset': 1000,
                  'endTimeOffset': 61000,
                },
                {
                  'id': 2,
                  'type': 'credits',
                  'startTimeOffset': 1200000,
                  'endTimeOffset': 1260000,
                  'final': true,
                },
              ],
              'Chapter': [
                {
                  'id': 5,
                  'index': 1,
                  'tag': 'Cold open',
                  'startTimeOffset': 0,
                  'endTimeOffset': 90500,
                  'thumb': '/library/media/11/chapterImages/1',
                },
              ],
            },
          ],
        },
      });
      final item = (await plex.library.item(
        ratingKey: '7',
        includeMarkers: true,
        includeChapters: true,
      ))!;
      expect(adapter.last!.queryParameters, {
        'includeMarkers': '1',
        'includeChapters': '1',
      });
      expect(item.markers.map((m) => (m.id, m.type, m.isFinal)), [
        (1, PlexMarkerType.intro, false),
        (2, PlexMarkerType.credits, true),
      ]);
      expect(item.markers.first.start, const Duration(seconds: 1));
      expect(item.markers.first.end, const Duration(seconds: 61));
      final chapter = item.chapters.single;
      expect((chapter.id, chapter.index, chapter.title), (5, 1, 'Cold open'));
      expect(chapter.start, Duration.zero);
      expect(chapter.end, const Duration(milliseconds: 90500));
      expect(chapter.thumb, '/library/media/11/chapterImages/1');
    });
  });

  group('models', () {
    test('PlexChapter: title from tag or title, offsets default to zero', () {
      final named = PlexChapter.fromJson(const {
        'title': 'Chapter 2',
        'startTimeOffset': '60000',
        'endTimeOffset': 120000,
      });
      expect(named.title, 'Chapter 2');
      expect(
        (named.start, named.end),
        (const Duration(minutes: 1), const Duration(minutes: 2)),
      );
      expect(named.raw['title'], 'Chapter 2');
      final bare = PlexChapter.fromJson(const {});
      expect(
        (bare.id, bare.index, bare.title, bare.thumb),
        (null, null, null, null),
      );
      expect((bare.start, bare.end), (Duration.zero, Duration.zero));
    });

    test('PlexMarker reads the document\'s `credit` as credits', () {
      final marker = PlexMarker.fromJson(const {
        'type': 'credit',
        'startTimeOffset': 5,
        'endTimeOffset': 9,
      });
      expect(marker.type, PlexMarkerType.credits);
      expect(marker.isFinal, isFalse);
      expect(marker.end - marker.start, const Duration(milliseconds: 4));
    });

    test('PlexPerson: name from tag, then title; empty when neither', () {
      expect(PlexPerson.fromJson(const {'title': 'By Title'}).name, 'By Title');
      expect(
        PlexPerson.fromJson(const {'tag': 'By Tag', 'title': 'x'}).name,
        'By Tag',
      );
      final nobody = PlexPerson.fromJson(const {});
      expect((nobody.id, nobody.name, nobody.thumb), (null, '', null));
    });

    test('PlexStream knows its kind from streamType', () {
      PlexStream stream(int type) =>
          PlexStream.fromJson({'id': type, 'streamType': type});
      List<bool> kinds(PlexStream s) => [
        s.isVideo,
        s.isAudio,
        s.isSubtitle,
        s.isLyrics,
      ];
      expect(kinds(stream(1)), [true, false, false, false]);
      expect(kinds(stream(2)), [false, true, false, false]);
      expect(kinds(stream(3)), [false, false, true, false]);
      expect(kinds(stream(4)), [false, false, false, true]);
      expect(kinds(stream(9)), everyElement(isFalse));
    });
  });

  group('URLs for a player', () {
    late PlexClient plex;

    setUp(() => plex = testClient(CapturingAdapter()));

    test('chapterImageUrl', () {
      final url = plex.library.chapterImageUrl(mediaId: '11', chapter: 2);
      expect(Uri.parse(url).origin, 'http://192.168.1.10:32400');
      expect(pathAndToken(url), ('/library/media/11/chapterImages/2', 'tok'));
    });

    test('streamUrl carries only the token unless told more', () {
      final url = Uri.parse(plex.library.streamUrl(streamId: '21', ext: 'srt'));
      expect(url.origin, 'http://192.168.1.10:32400');
      expect(url.path, '/library/streams/21.srt');
      expect(url.queryParameters, {'X-Plex-Token': 'tok'});
    });

    test('streamUrl sends encoding, format and the adjust flag as 1/0', () {
      final url = Uri.parse(
        plex.library.streamUrl(
          streamId: '21',
          ext: 'ass',
          encoding: 'utf-8',
          format: 'srt',
          autoAdjustSubtitle: true,
        ),
      );
      expect(url.path, '/library/streams/21.ass');
      expect(url.queryParameters, {
        'X-Plex-Token': 'tok',
        'encoding': 'utf-8',
        'format': 'srt',
        'autoAdjustSubtitle': '1',
      });
      final off = Uri.parse(
        plex.library.streamUrl(
          streamId: '21',
          ext: 'ass',
          autoAdjustSubtitle: false,
        ),
      );
      expect(off.queryParameters['autoAdjustSubtitle'], '0');
    });

    test('partFileUrl points at the file, with download as 1/0', () {
      final plain = Uri.parse(
        plex.library.partFileUrl(
          partId: '5',
          changestamp: 1786527974,
          filename: 'file.mp3',
        ),
      );
      expect(plain.origin, 'http://192.168.1.10:32400');
      expect(plain.path, '/library/parts/5/1786527974/file.mp3');
      expect(plain.queryParameters, {'X-Plex-Token': 'tok'});
      final download = Uri.parse(
        plex.library.partFileUrl(
          partId: '5',
          changestamp: 1786527974,
          filename: 'file.mp3',
          download: true,
        ),
      );
      expect(download.queryParameters, {
        'X-Plex-Token': 'tok',
        'download': '1',
      });
    });

    test('partBifThumbUrl', () {
      final url = plex.library.partBifThumbUrl(
        partId: '5',
        index: 'sd',
        offset: 30000,
      );
      expect(pathAndToken(url), ('/library/parts/5/indexes/sd/30000', 'tok'));
    });

    test('partFileUrl keeps the folders of a filename, each piece encoded', () {
      final url = plex.library.partFileUrl(
        partId: '5/6',
        changestamp: 1,
        filename: 'CD 1/a#b.mp3',
        download: false,
      );
      expect(
        url,
        'http://192.168.1.10:32400/library/parts/5%2F6/1/CD%201/a%23b.mp3'
        '?download=0&X-Plex-Token=tok',
      );
      for (final bad in ['', '/file.mp3', 'a//b.mp3', '../file.mp3']) {
        expect(
          () => plex.library.partFileUrl(
            partId: '5',
            changestamp: 1,
            filename: bad,
          ),
          throwsArgumentError,
          reason: bad,
        );
      }
    });

    test('the token is the last parameter, form-encoded', () {
      plex.connect('http://192.168.1.10:32400', accessToken: 'to k&n=1');
      final url = plex.library.streamUrl(
        streamId: '21',
        ext: 'srt',
        encoding: 'utf-8',
      );
      expect(
        url,
        'http://192.168.1.10:32400/library/streams/21.srt'
        '?encoding=utf-8&X-Plex-Token=to+k%26n%3D1',
      );
      expect(Uri.parse(url).queryParameters['X-Plex-Token'], 'to k&n=1');
    });

    test('without a token no X-Plex-Token is sent', () {
      final anonymous = PlexClient(
        credentials: testCredentials,
        httpClient: CapturingAdapter(),
      )..connect('http://192.168.1.10:32400');
      expect(
        anonymous.library.chapterImageUrl(mediaId: '11', chapter: 2),
        'http://192.168.1.10:32400/library/media/11/chapterImages/2',
      );
      expect(
        anonymous.library.partFileUrl(
          partId: '5',
          changestamp: 1,
          filename: 'file.mp3',
          download: true,
        ),
        'http://192.168.1.10:32400/library/parts/5/1/file.mp3?download=1',
      );
    });

    test('before connect() every URL is a state error, not "null/…"', () {
      final library = PlexClient(
        credentials: testCredentials,
        httpClient: CapturingAdapter(),
      ).library;
      final builders = <String Function()>[
        () => library.chapterImageUrl(mediaId: '11', chapter: 2),
        () => library.streamUrl(streamId: '21', ext: 'srt'),
        () => library.partFileUrl(
          partId: '5',
          changestamp: 1,
          filename: 'file.mp3',
        ),
        () => library.partBifThumbUrl(partId: '5', index: 'sd', offset: 0),
        () => library.itemFileUrl(ids: '7', url: 'Contents/a.jpg'),
        () => library.itemArtworkUrl(ids: '7', element: 'thumb', timestamp: 1),
        () => library.sectionCompositeImageUrl(sectionId: '1', updatedAt: 1),
      ];
      for (final build in builders) {
        expect(
          build,
          throwsA(
            isA<PlexException>().having(
              (e) => e.type,
              'type',
              PlexErrorType.state,
            ),
          ),
        );
      }
    });
  });
}
