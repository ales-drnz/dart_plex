// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_fixture.dart';

/// The 0.2 music surface against a live PMS seeded by `bootstrap.dart`
/// (one artist, one album, three tracks). Each test leaves the server as
/// it found it.
void main() {
  group(
    'Plex music surface',
    () {
      late PlexClient plex;
      late String sectionId;
      late PlexMetadata artist;
      late PlexMetadata album;
      late List<PlexMetadata> tracks;

      setUpAll(() async {
        plex = plexFromCache();
        final sections = await plex.library.sections();
        sectionId = sections.firstWhere((s) => s.title == 'Music').id;
        final albums = await plex.library.allByType(
          sectionId: sectionId,
          type: PlexMetadataType.album,
          filters: [PlexFilter.titleIs('Test Album')],
        );
        album = albums.items.single;
        artist = (await plex.library.item(album.parentRatingKey!))!;
        tracks = await plex.library.children(album.ratingKey);
      });

      test('children pages and sorts on the server', () async {
        expect(tracks, hasLength(3));
        final second = await plex.library.children(
          album.ratingKey,
          start: 1,
          size: 1,
        );
        expect(second.single.ratingKey, tracks[1].ratingKey);
        final reversed = await plex.library.children(
          album.ratingKey,
          sort: 'index:desc',
        );
        expect(
          reversed.map((t) => t.ratingKey),
          tracks.reversed.map((t) => t.ratingKey),
        );
      });

      test('grandchildren, recentlyAdded, section search, album fields',
          () async {
        final all = await plex.library.grandchildren(artist.ratingKey);
        expect(all.map((t) => t.ratingKey), tracks.map((t) => t.ratingKey));
        final page = await plex.library.grandchildren(
          artist.ratingKey,
          size: 1,
        );
        expect(page, hasLength(1));

        final recent = await plex.library.recentlyAdded(sectionId: sectionId);
        expect(recent.any((a) => a.ratingKey == album.ratingKey), isTrue);
        final global = await plex.library.recentlyAdded(size: 5);
        expect(global, isNotEmpty);

        final found = await plex.search.section(
          sectionId: sectionId,
          query: 'Track',
          type: PlexMetadataType.track,
        );
        expect(found.length, greaterThanOrEqualTo(3));
        expect(found.every((t) => t.type == PlexMetadataType.track), isTrue);

        final detail = (await plex.library.item(album.ratingKey))!;
        expect(detail.leafCount, 3);
        expect(detail.librarySectionId, sectionId);
        expect(
          recent.firstWhere((a) => a.ratingKey == album.ratingKey).leafCount,
          3,
        );
        expect(detail.originallyAvailableAt, isNotNull);
        expect(tracks.first.parentYear, detail.year);
      });

      test('server, history, butler and activities are typed', () async {
        final history = await plex.sessions.history(size: 5);
        expect(history.totalSize, greaterThanOrEqualTo(history.items.length));
        for (final e in history.items) {
          expect(e.historyKey, startsWith('/status/sessions/history/'));
          expect(e.viewedAt, isNotNull);
        }
        final tasks = await plex.butler.tasks();
        expect(tasks.any((t) => t.name == 'BackupDatabase'), isTrue);
        expect(await plex.activities.list(), isA<List<PlexActivity>>());
      });

      test('PlexPaging walks an artist two tracks at a time', () async {
        var requests = 0;
        final all = await PlexPaging.items(
          (start, size) {
            requests++;
            return plex.library.grandchildren(
              artist.ratingKey,
              start: start,
              size: size,
            );
          },
          pageSize: 2,
        ).toList();
        expect(all.map((t) => t.ratingKey), tracks.map((t) => t.ratingKey));
        expect(requests, 2);
      });

      test('countChildren moves no rows and still counts', () async {
        expect(await plex.library.countChildren(album.ratingKey), 3);
        expect(await plex.library.countChildren(artist.ratingKey), 1);
      });

      test('allLeaves pages', () async {
        final page = await plex.library.allLeaves(
          artist.ratingKey,
          start: 0,
          size: 2,
        );
        expect(page, hasLength(2));
      });

      test('playlists narrow on the server and expose entry ids', () async {
        final mid = PlexBootstrapCache.load().machineIdentifier;
        final mix = await plex.playlists.create(
          title: 'IT Probe Mix',
          type: 'audio',
          machineIdentifier: mid,
          itemRatingKeys: [tracks[0].ratingKey, tracks[1].ratingKey],
        );
        final other = await plex.playlists.create(
          title: 'IT Probe Other',
          type: 'audio',
          machineIdentifier: mid,
          itemRatingKeys: [tracks[2].ratingKey],
        );
        try {
          await plex.playback.rate(ratingKey: mix.ratingKey, rating: 10);

          final byTitle = await plex.playlists.list(
            type: 'audio',
            filters: [PlexFilter.titleContains('it probe mix')],
          );
          expect(byTitle.map((p) => p.ratingKey), [mix.ratingKey]);

          final rated = await plex.playlists.list(
            filters: [
              PlexFilter.titleContains('IT Probe'),
              PlexFilter.rated(),
            ],
          );
          expect(rated.map((p) => p.ratingKey), [mix.ratingKey]);
          expect(
            await plex.playlists.count(
              filters: [PlexFilter.titleContains('IT Probe')],
            ),
            2,
          );

          final entries = await plex.playlists.items(mix.ratingKey);
          expect(entries, hasLength(2));
          expect(entries.every((e) => e.playlistItemId != null), isTrue);
          await plex.playlists.removeItem(
            playlistId: mix.ratingKey,
            playlistItemId: entries.first.playlistItemId!,
          );
          final left = await plex.playlists.items(mix.ratingKey);
          expect(left.single.ratingKey, tracks[1].ratingKey);

          final page = await plex.playlists.items(other.ratingKey, size: 1);
          expect(page, hasLength(1));
        } finally {
          await plex.playlists.delete(mix.ratingKey);
          await plex.playlists.delete(other.ratingKey);
        }
      });

      test('a new poster changes the thumb version', () async {
        final before = (await plex.library.item(album.ratingKey))!;
        // A second must pass for the timestamp in the path to move.
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        await plex.library.setItemArtwork(
          ids: album.ratingKey,
          element: 'posters',
          data: base64.decode(_tinyJpeg),
        );
        late PlexMetadata after;
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          after = (await plex.library.item(album.ratingKey))!;
          if (after.thumbVersion != before.thumbVersion) break;
        }
        expect(after.thumbVersion, isNotNull);
        expect(after.thumbVersion, isNot(before.thumbVersion));
        final track = (await plex.library.item(tracks.first.ratingKey))!;
        expect(track.parentThumbVersion, after.thumbVersion);
      });

      test('timeline reports arrive as typed play-state events', () async {
        final socket = await plex.notifications.connectWebSocket();
        final seen = socket
            .events()
            .where((e) => e is PlexPlaySessionEvent)
            .cast<PlexPlaySessionEvent>()
            .where((e) => e.ratingKey == tracks.first.ratingKey)
            .first
            .timeout(const Duration(seconds: 10));
        try {
          await plex.playback.timeline(
            ratingKey: tracks.first.ratingKey,
            playState: PlexPlayState.playing,
            timeMs: 0,
            durationMs: tracks.first.durationMs!,
          );
          final event = await seen;
          expect(event.state, PlexPlayState.playing);
          expect(event.key, '/library/metadata/${tracks.first.ratingKey}');
        } finally {
          await plex.playback.timeline(
            ratingKey: tracks.first.ratingKey,
            playState: PlexPlayState.stopped,
            timeMs: 0,
            durationMs: tracks.first.durationMs!,
          );
          await plex.notifications.closeWebSocket();
        }
      });

      test('a library scan arrives as activity events', () async {
        final socket = await plex.notifications.connectWebSocket();
        final ended = socket
            .events()
            .where((e) => e is PlexActivityEvent)
            .cast<PlexActivityEvent>()
            .where((e) => e.isLibraryScan && e.isEnded)
            .first
            .timeout(const Duration(seconds: 30));
        try {
          await plex.library.refreshSection(sectionId: sectionId);
          final event = await ended;
          expect(event.uuid, isNotEmpty);
        } finally {
          await plex.notifications.closeWebSocket();
        }
      });

      test('startAudioTranscode makes the decision PMS requires', () async {
        Future<Set<String>> sessions() async {
          final res = await plex.request<Map<String, Object?>>(
            '/transcode/sessions',
          );
          final c = res.data!['MediaContainer']! as Map<String, Object?>;
          return {
            for (final s in (c['TranscodeSession'] as List<Object?>?) ?? [])
              ((s! as Map<String, Object?>)['key']! as String).split('/').last,
          };
        }

        // Fresh ids: a session left over from an interrupted run keeps the
        // decision it was started with.
        final run = DateTime.now().microsecondsSinceEpoch;
        final hlsId = 'it-hls-$run';
        final dashId = 'it-dash-$run';
        // A client of its own: other suites transcode as the shared test
        // client, and PMS ties a client's transcodes together.
        final cache = PlexBootstrapCache.load();
        final player = PlexClient(
          credentials: PlexCredentials(
            clientIdentifier: 'dart-plex-it-transcode-$run',
            product: 'dart_plex integration tests',
            version: '0.0.1',
            device: 'integration-tests',
            deviceName: 'dart_plex transcode test',
            platform: 'Test',
          ),
        )..connect(cache.baseUrl, accessToken: cache.token);
        final hls = await player.streaming.startAudioTranscode(
          ratingKey: tracks.first.ratingKey,
          session: hlsId,
          maxBitrateKbps: 96,
        );
        final dash = await player.streaming.startAudioTranscode(
          ratingKey: tracks.first.ratingKey,
          session: dashId,
          protocol: 'dash',
        );
        try {
          expect(hls.decision.isPlayable, isTrue);
          expect(hls.decision.isTranscode, isTrue);
          final playlist = await plex.request<String>(
            hls.url,
            absoluteUrl: true,
            responseType: PlexResponseType.plain,
          );
          expect(playlist.data, startsWith('#EXTM3U'));
          expect(playlist.data, contains('BANDWIDTH=96000'));
          final mpd = await plex.request<String>(
            dash.url,
            absoluteUrl: true,
            responseType: PlexResponseType.plain,
          );
          expect(mpd.data, contains('<MPD'));
          // DASH sessions start lazily, with the first segment; HLS at once.
          expect(await sessions(), contains(hlsId));
          await plex.streaming.pingUniversal(hlsId);
        } finally {
          await plex.streaming.stopUniversal(hlsId);
          await plex.streaming.stopUniversal(dashId);
        }
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(await sessions(), isNot(contains(hlsId)));
        // Stopping a session that is already gone is not an error.
        await plex.streaming.stopUniversal(hlsId);
      });

      test('a timeline report with no duration is refused locally', () {
        expect(
          () => plex.playback.timeline(
            ratingKey: tracks.first.ratingKey,
            playState: PlexPlayState.playing,
            timeMs: 0,
            durationMs: 0,
          ),
          throwsArgumentError,
        );
      });
    },
    skip: bootstrapSkipReason,
  );
}

/// An 8×8 green JPEG.
const _tinyJpeg =
    '/9j/4AAQSkZJRgABAgAAAQABAAD//gAPTGF2YzYzLjEuMTAyAP/bAEMACAQEBAQEBQUFBQUF'
    'BgYGBgYGBgYGBgYGBgcHBwgICAcHBwYGBwcICAgICQkJCAgICAkJCgoKDAwLCw4ODhERFP/E'
    'AEsAAQEAAAAAAAAAAAAAAAAAAAAGAQEAAAAAAAAAAAAAAAAAAAAGEAEAAAAAAAAAAAAAAAAA'
    'AAAAEQEAAAAAAAAAAAAAAAAAAAAA/8AAEQgACAAIAwEiAAIRAAMRAP/aAAwDAQACEQMRAD8A'
    'iwBQJf/Z';
