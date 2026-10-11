// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Read-only checks against any Plex Media Server, for trying the package
/// on a real library without the Docker stack:
///
///     PLEX_URL=http://192.168.1.10:32400 PLEX_TOKEN=… dart test --tags live
///
/// Skipped when the variables are not set. Nothing is written: no
/// playlist, no rating, no play report.
@Tags(['live'])
library;

import 'dart:io';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

final _url = Platform.environment['PLEX_URL'];
final _token = Platform.environment['PLEX_TOKEN'];
final _skip = _url == null || _token == null
    ? 'set PLEX_URL and PLEX_TOKEN to run against a real server'
    : null;

void main() {
  group(
    'live PMS (read-only)',
    () {
      late PlexClient plex;
      late String sectionId;

      setUpAll(() async {
        plex = PlexClient(
          credentials: const PlexCredentials(
            clientIdentifier: 'dart-plex-live-tests',
            product: 'dart_plex live tests',
            version: '0.2.0',
            device: 'live-tests',
            deviceName: 'dart_plex live tests',
            platform: 'Generic',
          ),
          retryPolicy: const PlexRetryPolicy(),
        )..connect(_url!, accessToken: _token);
        final sections = await plex.library.sections();
        sectionId =
            sections.firstWhere((s) => s.type == PlexLibraryType.music).id;
      });

      tearDownAll(() => plex.close());

      test('identity', () async {
        final id = await plex.server.identity();
        expect(id.machineIdentifier, isNotEmpty);
      });

      test('an album page, its tracks and an artist count', () async {
        final albums = await plex.library.allByType(
          sectionId: sectionId,
          type: PlexMetadataType.album,
          size: 10,
        );
        expect(albums.items, isNotEmpty);
        final album = albums.items.first;
        final tracks = await plex.library.children(album.ratingKey, size: 50);
        expect(tracks, isNotEmpty);
        expect(
          await plex.library.countChildren(album.parentRatingKey!),
          greaterThan(0),
        );
        expect(
            tracks.first.parentThumbVersion ?? album.thumbVersion, isNotNull);
      });

      test('playlists narrow on the server', () async {
        final all = await plex.playlists.list(type: 'audio', size: 100);
        if (all.isEmpty) return markTestSkipped('no audio playlists');
        final word = all.first.title.split(' ').first.toLowerCase();
        final some = await plex.playlists.list(
          type: 'audio',
          filters: [PlexFilter.titleContains(word)],
          size: 100,
        );
        expect(some, isNotEmpty);
        expect(
          some.every((p) => p.title.toLowerCase().contains(word)),
          isTrue,
        );
      });

      test('search one section', () async {
        final albums = await plex.library.allByType(
          sectionId: sectionId,
          type: PlexMetadataType.track,
          size: 1,
        );
        final title = albums.items.single.title;
        final found = await plex.search.section(
          sectionId: sectionId,
          query: title,
          type: PlexMetadataType.track,
        );
        expect(found.any((t) => t.title == title), isTrue);
      });
    },
    skip: _skip,
  );
}
