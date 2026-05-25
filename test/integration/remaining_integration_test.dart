// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@Tags(['integration'])
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_fixture.dart';

/// Smoke tests for the remaining Plex sub-APIs that don't need a
/// tuner: [PlexTranscoderApi], [PlexDevicesApi], [PlexUltraBlurApi].
void main() {
  group('Plex remaining APIs', () {
    late PlexClient plex;
    late String trackRatingKey;
    late String? trackThumbPath;

    setUpAll(() async {
      plex = plexFromCache();
      if (bootstrapSkipReason != null) return;
      final sections = await plex.library.sections();
      final music = sections.firstWhere((s) => s.title == 'Music');
      final page = await plex.library.allByType(
        sectionId: music.id,
        type: PlexMetadataType.track,
        size: 1,
      );
      final track = page.items.first;
      trackRatingKey = track.ratingKey;
      // Plex builds thumbs at /library/metadata/{id}/thumb/{ts}; even
      // when the track has no embedded art the path is well-formed.
      trackThumbPath = track.thumb ?? '/library/metadata/$trackRatingKey/thumb';
    });

    test('transcoder.imageUrl builds a /photo/:/transcode URL', () {
      final url = plex.transcoder.imageUrl(
        sourceUrl: trackThumbPath!,
        width: 320,
        height: 320,
      );
      expect(url, contains('/photo/:/transcode'));
      expect(url, contains('X-Plex-Token='));
      expect(url, contains('width=320'));
    });

    test('transcoder.startUrl builds the universal-start URL', () {
      final url = plex.transcoder.startUrl(
        transcodeType: 'audio',
        extension: 'm3u8',
        params: const {'path': '/library/metadata/1'},
      );
      expect(url, contains('/audio/:/transcode/universal/start.m3u8'));
      expect(url, contains('X-Plex-Token='));
    });

    test('transcoder.subtitlesUrl builds the universal-subtitles URL', () {
      final url = plex.transcoder.subtitlesUrl(transcodeType: 'video');
      expect(url, contains('/video/:/transcode/universal/subtitles'));
      expect(url, contains('X-Plex-Token='));
    });

    test('devices.list returns the registered grabber-device map', () async {
      final d = await plex.devices.list();
      expect(d, isA<Map<String, dynamic>>());
    });

    test('devices.grabbers returns the available protocol list', () async {
      final g = await plex.devices.grabbers();
      expect(g, isA<Map<String, dynamic>>());
    });

    test('ultraBlur.imageUrl builds a backdrop URL', () {
      final url = plex.ultraBlur.imageUrl(
        topLeft: '112233',
        topRight: '445566',
        bottomLeft: '778899',
        bottomRight: 'aabbcc',
        width: 480,
        height: 270,
      );
      expect(url, contains('/services/ultrablur/image'));
      expect(url, contains('topLeft=112233'));
      expect(url, contains('X-Plex-Token='));
    });

    test('ultraBlur.colors handles a missing-thumb source gracefully',
        () async {
      // Our ffmpeg-seeded tracks carry no embedded art, so the
      // ultrablur endpoint will return an empty UltraBlurColors list
      // (or 404). Either is fine; we just want call shape coverage.
      try {
        final cs = await plex.ultraBlur.colors(sourceUrl: trackThumbPath!);
        expect(cs, isA<List<PlexUltraBlurColors>>());
      } on PlexException catch (e) {
        expect(
          e.type,
          anyOf(PlexErrorType.notFound, PlexErrorType.badRequest),
        );
      }
    });
  }, skip: bootstrapSkipReason);
}
