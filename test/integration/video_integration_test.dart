// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@Tags(['integration'])
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_fixture.dart';

/// Video against the Docker PMS: the suite makes a movie section of the
/// seed's `/data/Movies` (one 5 s h264 clip) and removes it afterwards.
/// Covers the video transcode decision for every protocol, the media
/// filters of PMS 1.43.2, the section's details, folders and tags, and
/// item details with markers and chapters.
void main() {
  group('video', () {
    late PlexClient plex;
    late String sectionId;
    late String movieKey;

    setUpAll(() async {
      plex = plexFromCache();
      await plex.library.addSection(
        name: 'dart_plex video it',
        type: PlexLibraryType.movie,
        scanner: 'Plex Movie',
        agent: 'tv.plex.agents.none',
        language: 'xn',
        locations: const ['/data/Movies'],
      );
      final section = (await plex.library.sections()).firstWhere(
        (s) => s.title == 'dart_plex video it',
      );
      sectionId = section.id;
      // The scan is asynchronous: wait for the clip.
      for (var i = 0; i < 60; i++) {
        final page = await plex.library.allByType(
          sectionId: sectionId,
          type: PlexMetadataType.movie,
        );
        if (page.items.isNotEmpty) {
          movieKey = page.items.first.ratingKey;
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      fail('the movie section never listed the clip');
    });

    tearDownAll(() async {
      final sections = await plex.library.sections();
      for (final s in sections.where((s) => s.title == 'dart_plex video it')) {
        await plex.library.deleteSection(sectionId: s.id);
      }
    });

    for (final protocol in PlexStreamingProtocol.values) {
      test('startVideoTranscode over ${protocol.name}', () async {
        final t = await plex.streaming.startVideoTranscode(
          ratingKey: movieKey,
          session: 'dart-plex-it-video-${protocol.name}',
          protocol: protocol,
          maxVideoBitrateKbps: 2000,
        );
        addTearDown(() => plex.streaming.stopUniversal(session: t.session));
        expect(t.decision.isPlayable, isTrue, reason: '${t.decision.raw}');
        final res = await plex.requestStream(t.url);
        // Read a little of the manifest or stream, then let go.
        final first = await res.stream.first;
        expect(first, isNotEmpty);
        expect(res.statusCode, 200);
      });
    }

    test('the media filters narrow the section', () async {
      Future<int> count(PlexFilter f) => plex.library.countByType(
        sectionId: sectionId,
        type: PlexMetadataType.movie,
        filters: [f],
      );
      expect(await count(PlexFilter.videoCodec(['h264'])), 1);
      expect(await count(PlexFilter.videoCodec(['hevc'])), 0);
      expect(await count(PlexFilter.atmos()), 0);
      expect(await count(PlexFilter.atmos(value: false)), 1);
      expect(await count(PlexFilter.dolbyVision()), 0);
      expect(await count(PlexFilter.hdr(value: false)), 1);
    });

    test('section details, folder, sort', () async {
      final details = await plex.library.sectionDetails(sectionId: sectionId);
      expect(details.views.map((v) => v.key), contains('all'));
      final root = await plex.library.folder(sectionId: sectionId);
      expect(root.items, isNotEmpty);
      final page = await plex.library.allByType(
        sectionId: sectionId,
        type: PlexMetadataType.movie,
        sort: PlexSort.addedAt.desc,
      );
      expect(page.items.single.ratingKey, movieKey);
    });

    test('item details with markers, chapters and images', () async {
      final item = await plex.library.item(
        ratingKey: movieKey,
        includeMarkers: true,
        includeChapters: true,
      );
      expect(item!.markers, isEmpty);
      expect(item.images.map((i) => i.type), contains('coverPoster'));
      expect(item.media.single.parts.single.streams.first.displayTitle, 'SD');
    });

    test('download queue: create, add, items', () async {
      final queue = await plex.downloadQueue.create();
      await plex.downloadQueue.add(queueId: queue.id, keys: [movieKey]);
      final items = await plex.downloadQueue.items(queueId: queue.id);
      expect(items.map((i) => i.key), contains(movieKey));
      for (final i in items) {
        await plex.downloadQueue.remove(queueId: queue.id, itemId: i.id);
      }
    });

    test('library tags are typed', () async {
      final tags = await plex.library.tags(type: PlexMetadataType.movie);
      expect(tags, isA<List<PlexTag>>());
    });
  }, skip: bootstrapSkipReason);
}
