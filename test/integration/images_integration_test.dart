// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@Tags(['integration'])
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_fixture.dart';

/// Smoke tests for [PlexImagesApi] (image transcode URL builders).
void main() {
  group('Plex images', () {
    late PlexClient plex;

    setUpAll(() {
      plex = plexFromCache();
    });

    test('transcodeUrl builds a deterministic transcoded image URL', () {
      final url = plex.images.transcodeUrl(
        sourcePath: '/library/metadata/12345/thumb/9999',
        width: 200,
        height: 200,
      );
      expect(url, contains('/photo/:/transcode'));
      expect(url, contains('width=200'));
      expect(url, contains('height=200'));
      expect(
        url,
        contains(
            Uri.encodeQueryComponent('/library/metadata/12345/thumb/9999')),
      );
    });

    test('ultraBlur.imageUrl builds a gradient URL', () {
      final url = plex.ultraBlur.imageUrl(
        topLeft: 'ff0000',
        topRight: '00ff00',
        bottomLeft: '0000ff',
        bottomRight: 'ffffff',
        width: 1920,
        height: 1080,
      );
      expect(url, contains('/services/ultrablur/image'));
      expect(url, contains('topLeft=ff0000'));
      expect(url, contains('width=1920'));
    });
  }, skip: bootstrapSkipReason);
}
