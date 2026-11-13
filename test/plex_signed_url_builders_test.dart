// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

// The deprecated builders are tested here until they go.
// ignore_for_file: deprecated_member_use_from_same_package

/// The URLs the streaming, transcoder, image, UltraBlur and collection
/// sub-APIs hand to a player or an image widget, and the ids they put in
/// a path.
library;

import 'dart:typed_data';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

const _base = 'http://192.168.1.10:32400';

const _playable = {
  'MediaContainer': {'generalDecisionCode': 1001},
};

final Matcher _throwsState = throwsA(
  isA<PlexException>().having((e) => e.type, 'type', PlexErrorType.state),
);

/// Every builder of a signed URL, by name.
Map<String, String Function()> _builders(PlexClient plex) => {
  'streaming.directFileUrl': () =>
      plex.streaming.directFileUrl(partKey: '/library/parts/1/2/a.flac').$1,
  'streaming.universalVideoUrl': () =>
      plex.streaming.universalVideoUrl(ratingKey: '1'),
  'transcoder.imageUrl': () =>
      plex.transcoder.imageUrl(sourceUrl: '/library/metadata/1/thumb/2'),
  'transcoder.subtitlesUrl': () =>
      plex.transcoder.subtitlesUrl(transcodeType: 'video'),
  'transcoder.startUrl': () =>
      plex.transcoder.startUrl(transcodeType: 'video', extension: 'm3u8'),
  'images.transcodeUrl': () =>
      plex.images.transcodeUrl(sourcePath: '/library/metadata/1/thumb/2'),
  'ultraBlur.imageUrl': () => plex.ultraBlur.imageUrl(topLeft: '#102030'),
  'collections.compositeImageUrl': () =>
      plex.collections.compositeImageUrl(collectionId: '914', updatedAt: 7),
};

PlexClient _client(CapturingAdapter adapter, {String? token}) => PlexClient(
  credentials: testCredentials,
  httpClient: adapter,
  jsonIsolateThreshold: 0,
)..connect(_base, accessToken: token);

void main() {
  group('signed URLs', () {
    test('before connect() every builder is a state error', () async {
      final plex = PlexClient(
        credentials: testCredentials,
        httpClient: CapturingAdapter(),
      );
      for (final MapEntry(key: name, value: build) in _builders(plex).entries) {
        expect(build, _throwsState, reason: name);
      }
      await expectLater(
        plex.streaming.startAudioTranscode(ratingKey: '1', session: 's'),
        _throwsState,
      );
      await expectLater(
        plex.streaming.startVideoTranscode(ratingKey: '1', session: 's'),
        _throwsState,
      );
    });

    test('the token is form-encoded and the last parameter', () {
      final plex = _client(CapturingAdapter(), token: 'to k&n');
      for (final MapEntry(key: name, value: build) in _builders(plex).entries) {
        final url = build();
        expect(url, startsWith('$_base/'), reason: name);
        expect(url, endsWith('X-Plex-Token=to+k%26n'), reason: name);
        expect(
          Uri.parse(url).queryParameters['X-Plex-Token'],
          'to k&n',
          reason: name,
        );
      }
    });

    test('without a token there is no X-Plex-Token, not an empty one', () {
      for (final token in [null, '']) {
        final plex = _client(CapturingAdapter(), token: token);
        for (final MapEntry(key: name, value: build) in _builders(
          plex,
        ).entries) {
          expect(build(), isNot(contains('X-Plex-Token')), reason: name);
        }
        expect(
          plex.collections.compositeImageUrl(collectionId: '914', updatedAt: 7),
          '$_base/library/collections/914/composite/7',
        );
        expect(
          plex.streaming.directFileUrl(partKey: '/library/parts/1/2/a.flac').$1,
          '$_base/library/parts/1/2/a.flac?download=1',
        );
      }
    });

    test('the parameters of each URL, in the order they are sent', () {
      final plex = testClient(CapturingAdapter());
      expect(
        plex.images.transcodeUrl(
          sourcePath: '/library/metadata/1/thumb/2',
          width: 300,
          height: 200,
        ),
        '$_base/photo/:/transcode?width=300&height=200&minSize=1&upscale=0'
        '&url=%2Flibrary%2Fmetadata%2F1%2Fthumb%2F2&X-Plex-Token=tok',
      );
      expect(
        plex.ultraBlur.imageUrl(
          topLeft: '#102030',
          bottomRight: 'ffffff',
          width: 320,
          noise: 1,
        ),
        '$_base/services/ultrablur/image?topLeft=%23102030'
        '&bottomRight=ffffff&width=320&noise=1&X-Plex-Token=tok',
      );
      expect(
        plex.streaming.directFileUrl(
          partKey: '/library/parts/1/2/a.flac',
          download: false,
        ),
        ('$_base/library/parts/1/2/a.flac?X-Plex-Token=tok', 'flac'),
      );
      expect(
        plex.transcoder.subtitlesUrl(
          transcodeType: 'video',
          params: {'session': 's 1', 'path': '/library/metadata/1'},
        ),
        '$_base/video/:/transcode/universal/subtitles?session=s+1'
        '&path=%2Flibrary%2Fmetadata%2F1&X-Plex-Token=tok',
      );
    });

    test("a started transcode plays the decision's own parameters, then "
        'the token', () async {
      final adapter = CapturingAdapter(_playable);
      final plex = testClient(adapter);
      final video = await plex.streaming.startVideoTranscode(
        ratingKey: '888',
        session: 's1',
        maxVideoBitrateKbps: 2000,
        videoResolution: '640x480',
      );
      final decided = adapter.last!.queryParameters;
      final played = Uri.parse(video.url).queryParameters;
      expect(played.keys, [...decided.keys, 'X-Plex-Token']);
      expect({...played}..remove('X-Plex-Token'), decided);

      final audio = await plex.streaming.startAudioTranscode(
        ratingKey: '7',
        session: 's2',
        maxAudioBitrateKbps: 96,
      );
      final audioDecided = adapter.last!.queryParameters;
      final audioPlayed = Uri.parse(audio.url).queryParameters;
      expect(audioPlayed.keys, [...audioDecided.keys, 'X-Plex-Token']);
      expect({...audioPlayed}..remove('X-Plex-Token'), audioDecided);
      expect(
        Uri.parse(audio.url).path,
        '/music/:/transcode/universal/start.m3u8',
      );
    });
  });

  group('transcoder and deprecated builders', () {
    late PlexClient plex;

    setUp(() => plex = testClient(CapturingAdapter()));

    test('transcoder.imageUrl sends only the options given', () {
      expect(
        plex.transcoder.imageUrl(
          sourceUrl: '/library/metadata/1/thumb/2',
          width: 300,
          quality: 80,
          chromaSubsampling: 1,
          upscale: true,
        ),
        '$_base/photo/:/transcode?url=%2Flibrary%2Fmetadata%2F1%2Fthumb%2F2'
        '&width=300&quality=80&chromaSubsampling=1&upscale=1'
        '&X-Plex-Token=tok',
      );
    });

    test('transcoder.startUrl (deprecated) still builds the URL', () {
      expect(
        plex.transcoder.startUrl(
          transcodeType: 'music',
          extension: 'm3u8',
          params: {'session': 's'},
        ),
        '$_base/music/:/transcode/universal/start.m3u8?session=s'
        '&X-Plex-Token=tok',
      );
    });

    test('streaming.universalVideoUrl (deprecated) still builds the '
        'URL', () {
      expect(
        plex.streaming.universalVideoUrl(
          ratingKey: '1',
          videoResolution: '1280x720',
          maxVideoBitrateKbps: 4000,
          session: 's',
        ),
        '$_base/video/:/transcode/universal/start.m3u8'
        '?path=%2Flibrary%2Fmetadata%2F1&mediaIndex=0&partIndex=0'
        '&protocol=hls&directPlay=0&directStream=1&fastSeek=1&offset=0'
        '&audioBoost=100&container=mpegts&videoResolution=1280x720'
        '&maxVideoBitrate=4000&session=s&X-Plex-Token=tok',
      );
      expect(
        Uri.parse(
          plex.streaming.universalVideoUrl(
            ratingKey: '1',
            protocol: PlexStreamingProtocol.http,
            container: 'mkv',
          ),
        ).path,
        '/video/:/transcode/universal/start.mkv',
      );
    });
  });

  group('ids in a path', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    test('a slash in an id stays inside its segment', () async {
      final calls = <String, Future<Object?> Function()>{
        '/library/collections/1%2F2/items': () =>
            plex.collections.addItems(collectionId: '1/2', uri: 'u'),
        '/library/collections/1%2F2/items/3%2F4': () =>
            plex.collections.removeItem(collectionId: '1/2', itemId: '3/4'),
        '/library/collections/1%2F2/items/3%2F4/move': () => plex.collections
            .moveItem(collectionId: '1/2', itemId: '3/4', afterItemId: '0'),
        '/hubs/sections/1%2F2/manage/a%2Fb': () =>
            plex.hubs.deleteCustom(sectionId: '1/2', identifier: 'a/b'),
        '/hubs/metadata/1%2F2/related': () =>
            plex.hubs.related(metadataId: '1/2'),
        '/hubs/a%3Fb/items': () => plex.hubs.drill(hubKeyOrIdentifier: 'a?b'),
        '/a%2Fb/:/transcode/universal/fallback': () =>
            plex.transcoder.triggerFallback(transcodeType: 'a/b'),
        '/a%2Fb/:/transcode/universal/decision': () => plex.streaming
            .decisionUniversal(params: const {}, transcodeType: 'a/b'),
      };
      for (final MapEntry(key: path, value: call) in calls.entries) {
        try {
          await call();
        } on PlexException {
          // The canned answer is not a container; only the path matters.
        }
        expect(adapter.last!.uri.path, path);
      }
      expect(
        Uri.parse(
          plex.collections.compositeImageUrl(collectionId: '1/2', updatedAt: 7),
        ).path,
        '/library/collections/1%2F2/composite/7',
      );
      expect(
        Uri.parse(
          plex.transcoder.startUrl(transcodeType: 'a/b', extension: 'm/8'),
        ).path,
        '/a%2Fb/:/transcode/universal/start.m%2F8',
      );
    });

    test('a key the server gave is followed as it is', () async {
      try {
        await plex.hubs.drill(
          hubKeyOrIdentifier: '/library/sections/3/recentlyAdded',
        );
      } on PlexException {
        // Only the path matters.
      }
      expect(adapter.last!.uri.path, '/library/sections/3/recentlyAdded');
    });

    test('an empty id or a dot segment is refused before any request', () {
      expect(
        () => plex.collections.items(collectionId: ''),
        throwsArgumentError,
      );
      expect(
        () => plex.collections.removeItem(collectionId: '..', itemId: '1'),
        throwsArgumentError,
      );
      expect(
        () => plex.hubs.deleteCustom(sectionId: '1', identifier: ''),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('arguments', () {
    test('a smart collection without a seedUri is an ArgumentError', () {
      final adapter = CapturingAdapter();
      expect(
        () =>
            testClient(adapter).collections.create(sectionId: '1', smart: true),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });

    test('collections.create sends smart as 1/0, in the order of '
        '0.3.0', () async {
      final adapter = CapturingAdapter({
        'MediaContainer': {
          'Metadata': [
            {'ratingKey': '9', 'type': 'collection', 'title': 'c'},
          ],
        },
      });
      final created = await testClient(adapter).collections.create(
        sectionId: '1',
        title: 'c',
        type: PlexMetadataType.album,
        smart: false,
        seedUri: 'server://x/y',
      );
      expect(created.ratingKey, '9');
      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.queryParameters, {
        'sectionId': '1',
        'title': 'c',
        'type': '${PlexMetadataType.album.value}',
        'smart': '0',
        'uri': 'server://x/y',
      });
      expect(adapter.last!.queryParameters.keys, [
        'sectionId',
        'title',
        'type',
        'smart',
        'uri',
      ]);
    });

    test('a chromaSubsampling outside 0-3 is an ArgumentError', () {
      final plex = testClient(CapturingAdapter());
      for (final bad in [-1, 4]) {
        expect(
          () =>
              plex.transcoder.imageUrl(sourceUrl: '/a', chromaSubsampling: bad),
          throwsArgumentError,
        );
      }
    });
  });

  group('image bytes', () {
    test('images.fetch and ultraBlur.fetchImage answer the body', () async {
      final adapter = BytesAdapter([1, 2, 3]);
      final plex = testClient(adapter);
      expect(
        await plex.images.fetch(sourcePath: '/library/metadata/1/thumb/2'),
        Uint8List.fromList([1, 2, 3]),
      );
      expect(adapter.last!.uri.path, '/photo/:/transcode');
      expect(
        await plex.ultraBlur.fetchImage(topLeft: '#102030'),
        Uint8List.fromList([1, 2, 3]),
      );
      expect(adapter.last!.uri.path, '/services/ultrablur/image');
      adapter.responseBytes = const [];
      expect(await plex.images.fetch(sourcePath: '/a'), isNull);
      expect(await plex.ultraBlur.fetchImage(), isNull);
    });
  });
}
