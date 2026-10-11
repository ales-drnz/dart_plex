// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Wire-contract tests for the music surface added in 0.2: paging and sort
/// of `/children` and `/allLeaves`, playlist narrowing, the timeline
/// contract, scrobble/rate verbs, and the models they read.
///
/// Plex ignores parameters it does not understand and answers wider, so
/// these assert on the request that left the client, not on parsing.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

const _metadataBody = {
  'MediaContainer': {
    'size': 1,
    'totalSize': 7,
    'Metadata': [
      {'ratingKey': '1', 'type': 'track', 'title': 'One'},
    ],
  },
};

void main() {
  late CapturingAdapter adapter;
  late PlexClient plex;

  setUp(() {
    adapter = CapturingAdapter(_metadataBody);
    plex = testClient(adapter);
  });

  Map<String, String> query() => adapter.lastRequest!.queryParameters;

  group('library.children', () {
    test('without paging asks for every child', () async {
      await plex.library.children('42');
      expect(adapter.lastRequest!.uri.path, '/library/metadata/42/children');
      expect(adapter.lastRequest!.uri.query, isEmpty);
    });

    test('a page sends Start and Size together, plus the sort', () async {
      await plex.library.children('42', start: 50, size: 25, sort: 'year:desc');
      expect(query(), {
        'X-Plex-Container-Start': '50',
        'X-Plex-Container-Size': '25',
        'sort': 'year:desc',
      });
    });

    test('size alone still sends Start (PMS ignores Size on its own)',
        () async {
      await plex.library.children('42', size: 25);
      expect(query()['X-Plex-Container-Start'], '0');
      expect(query()['X-Plex-Container-Size'], '25');
    });

    test('start without size is refused instead of being ignored upstream', () {
      expect(() => plex.library.children('42', start: 10), throwsArgumentError);
    });

    test('countChildren reads totalSize of an empty page', () async {
      final n = await plex.library.countChildren('42');
      expect(n, 7);
      expect(query(), {
        'X-Plex-Container-Start': '0',
        'X-Plex-Container-Size': '0',
      });
    });
  });

  group('library.allLeaves', () {
    test('pages with Start and Size', () async {
      await plex.library.allLeaves('9', start: 100, size: 100);
      expect(adapter.lastRequest!.uri.path, '/library/metadata/9/allLeaves');
      expect(query(), {
        'X-Plex-Container-Start': '100',
        'X-Plex-Container-Size': '100',
      });
    });
  });

  group('library: grandchildren, recentlyAdded, section search', () {
    test('grandchildren pages', () async {
      await plex.library.grandchildren('1', size: 100);
      expect(
        adapter.lastRequest!.uri.path,
        '/library/metadata/1/grandchildren',
      );
      expect(query(), {
        'X-Plex-Container-Start': '0',
        'X-Plex-Container-Size': '100',
      });
    });

    test('recentlyAdded is global or per section', () async {
      await plex.library.recentlyAdded();
      expect(adapter.lastRequest!.uri.path, '/library/recentlyAdded');
      expect(adapter.lastRequest!.uri.query, isEmpty);
      await plex.library.recentlyAdded(sectionId: '1', size: 20);
      expect(
        adapter.lastRequest!.uri.path,
        '/library/sections/1/recentlyAdded',
      );
      expect(query()['X-Plex-Container-Size'], '20');
    });

    test('search.section sends the type it needs', () async {
      await plex.search.section(
        sectionId: '1',
        query: 'Rock & Roll',
        type: PlexMetadataType.track,
        limit: 10,
      );
      expect(adapter.lastRequest!.uri.path, '/library/sections/1/search');
      expect(query(), {'query': 'Rock & Roll', 'type': '10', 'limit': '10'});
    });
  });

  group('library.nearestToTrack', () {
    test('excludes by ratingKey strings', () async {
      await plex.library.nearestToTrack(
        ratingKey: '5',
        limit: 20,
        maxDistance: 0.25,
        excludeParentRatingKey: '2',
        excludeGrandparentRatingKey: '1',
      );
      expect(adapter.lastRequest!.uri.path, '/library/metadata/5/nearest');
      expect(query(), {
        'limit': '20',
        'maxDistance': '0.25',
        'excludeParentID': '2',
        'excludeGrandparentID': '1',
      });
    });

    test('the deprecated int forms send the same parameters', () async {
      await plex.library.nearestToTrack(
        ratingKey: '5',
        // ignore: deprecated_member_use_from_same_package
        excludeParentID: 2,
      );
      expect(query()['excludeParentID'], '2');
    });

    test('both forms at once are refused', () {
      expect(
        () => plex.library.nearestToTrack(
          ratingKey: '5',
          excludeParentRatingKey: '2',
          // ignore: deprecated_member_use_from_same_package
          excludeParentID: 2,
        ),
        throwsArgumentError,
      );
    });
  });

  group('playlists', () {
    test('list narrows on the server with PlexFilter', () async {
      await plex.playlists.list(
        type: 'audio',
        filters: [PlexFilter.titleContains('mix'), PlexFilter.rated()],
        sort: 'titleSort',
        size: 100,
      );
      expect(adapter.lastRequest!.uri.path, '/playlists');
      expect(query(), {
        'X-Plex-Container-Start': '0',
        'X-Plex-Container-Size': '100',
        'playlistType': 'audio',
        'sort': 'titleSort',
        'title': 'mix',
        'userRating>>': '0',
      });
    });

    test('count takes the same narrowing and asks for no rows', () async {
      final n = await plex.playlists.count(
        type: 'audio',
        filters: [PlexFilter.rated()],
      );
      expect(n, 7);
      expect(query()['X-Plex-Container-Size'], '0');
      expect(query()['userRating>>'], '0');
    });

    test('items with only a size still sends Start', () async {
      await plex.playlists.items('42', size: 50);
      expect(query(), {
        'X-Plex-Container-Start': '0',
        'X-Plex-Container-Size': '50',
      });
    });

    test('entries expose playlistItemId for per-entry edits', () async {
      adapter.responseBody = {
        'MediaContainer': {
          'size': 2,
          'Metadata': [
            {'ratingKey': '3', 'type': 'track', 'playlistItemID': 101},
            {'ratingKey': '3', 'type': 'track', 'playlistItemID': 102},
          ],
        },
      };
      final entries = await plex.playlists.items('42');
      expect(entries.map((e) => e.playlistItemId), ['101', '102']);
      await plex.playlists.removeItem(
        playlistId: '42',
        playlistItemId: entries.last.playlistItemId!,
      );
      expect(adapter.lastRequest!.method, 'DELETE');
      expect(adapter.lastRequest!.uri.path, '/playlists/42/items/102');
    });
  });

  group('playback', () {
    test('timeline sends the report with a real duration', () async {
      await plex.playback.timeline(
        ratingKey: '541',
        state: PlexPlaybackApi.statePlaying,
        timeMs: 12000,
        durationMs: 60029,
        playQueueItemID: 7,
      );
      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.uri.path, '/:/timeline');
      expect(query(), {
        'ratingKey': '541',
        'key': '/library/metadata/541',
        'state': 'playing',
        'time': '12000',
        'duration': '60029',
        'continuing': '0',
        'playQueueItemID': '7',
      });
    });

    test('timeline sends no playQueueItemID unless given', () async {
      await plex.playback.timeline(
        ratingKey: '541',
        state: PlexPlaybackApi.statePaused,
        timeMs: 0,
        durationMs: 1000,
      );
      expect(query().containsKey('playQueueItemID'), isFalse);
    });

    test('timeline refuses a duration PMS cannot count', () async {
      for (final d in [0, -1]) {
        expect(
          () => plex.playback.timeline(
            ratingKey: '1',
            state: 'playing',
            timeMs: 0,
            durationMs: d,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => plex.playback.timeline(
          ratingKey: '1',
          state: 'playing',
          timeMs: -5,
          durationMs: 1000,
        ),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });

    test('scrobble, unscrobble and rate are PUTs', () async {
      await plex.playback.scrobble('9');
      expect(adapter.lastRequest!.method, 'PUT');
      expect(adapter.lastRequest!.uri.path, '/:/scrobble');
      expect(
        query(),
        {'key': '9', 'identifier': 'com.plexapp.plugins.library'},
      );
      await plex.playback.unscrobble('9');
      expect(adapter.lastRequest!.method, 'PUT');
      await plex.playback.rate(ratingKey: '9', rating: 8);
      expect(adapter.lastRequest!.method, 'PUT');
      expect(query()['rating'], '8.0');
    });
  });

  group('models', () {
    test('PlexStream reads the loudness analysis', () {
      final s = PlexStream.fromJson(const {
        'streamType': 2,
        'gain': '-6.2',
        'albumGain': -8.5,
        'peak': 0.98,
        'albumPeak': 0.95,
        'loudness': -14,
        'lra': 8.5,
      });
      expect(s.gain, -6.2);
      expect(s.albumGain, -8.5);
      expect(s.peak, 0.98);
      expect(s.albumPeak, 0.95);
      expect(s.loudness, -14.0);
      expect(s.lra, 8.5);
      expect(s.hasLoudness, isTrue);
      expect(PlexStream.fromJson(const {}).hasLoudness, isFalse);
    });

    test('audioStream picks the selected audio stream', () {
      final m = PlexMetadata.fromJson(const {
        'ratingKey': '1',
        'type': 'track',
        'Media': [
          {
            'Part': [
              {
                'Stream': [
                  {'streamType': 2, 'id': 1},
                  {'streamType': 2, 'id': 2, 'selected': true, 'gain': -3},
                  {'streamType': 4, 'id': 3},
                ],
              },
            ],
          },
        ],
      });
      expect(m.audioStream?.id, 2);
      expect(m.audioStream?.gain, -3.0);
    });

    test('artwork versions come from the thumb paths', () {
      final m = PlexMetadata.fromJson(const {
        'ratingKey': '3',
        'type': 'track',
        // Shapes captured from PMS 1.43.2 after a poster upload.
        'thumb': '/library/metadata/2/thumb/1791659978',
        'parentThumb': '/library/metadata/2/thumb/1791659978',
        'grandparentThumb': '/library/metadata/1/thumb/1791650000',
        'art': '/library/metadata/1/art/1791650001',
      });
      expect(m.thumbVersion, '1791659978');
      expect(m.parentThumbVersion, '1791659978');
      expect(m.grandparentThumbVersion, '1791650000');
      expect(m.artVersion, '1791650001');
    });

    test('album and track fields from PMS 1.43.2 responses', () {
      final album = PlexMetadata.fromJson(const {
        'ratingKey': '2',
        'type': 'album',
        'leafCount': 3,
        'viewedLeafCount': 1,
        'originallyAvailableAt': '2020-01-01',
        'librarySectionID': 1,
        'librarySectionTitle': 'Music',
        'parentGuid': 'local://1',
        'score': '0.72000',
        'UltraBlurColors': {'topLeft': '003900', 'bottomRight': '067203'},
      });
      expect(album.leafCount, 3);
      expect(album.viewedLeafCount, 1);
      expect(album.originallyAvailableAt, DateTime.utc(2020));
      expect(album.librarySectionId, '1');
      expect(album.librarySectionTitle, 'Music');
      expect(album.parentGuid, 'local://1');
      expect(album.score, 0.72);
      expect(album.ultraBlurColors?.topLeft, '003900');

      final track = PlexMetadata.fromJson(const {
        'ratingKey': '3',
        'type': 'track',
        'parentYear': 2020,
        'lastRatedAt': 1791659455,
        'skipCount': 2,
        'distance': 0.12,
        'grandparentGuid': 'local://1',
      });
      expect(track.parentYear, 2020);
      expect(track.lastRatedAt?.year, 2026);
      expect(track.skipCount, 2);
      expect(track.distance, 0.12);
      expect(track.grandparentGuid, 'local://1');
    });

    test('PlexArtwork.versionOf ignores paths without a version', () {
      expect(PlexArtwork.versionOf(null), isNull);
      expect(PlexArtwork.versionOf('/library/metadata/2/thumb'), isNull);
      expect(PlexArtwork.versionOf('https://img.example/x.jpg'), isNull);
      expect(
        PlexArtwork.versionOf('/library/metadata/2/thumb/abc'),
        isNull,
      );
      expect(
        PlexArtwork.versionOf('/library/metadata/2/art/17?x=1'),
        '17',
      );
    });
  });

  group('notification events (frames captured from PMS 1.43.2)', () {
    List<PlexEvent> decode(String name) {
      final json = jsonDecode(
        File('test/fixtures/notifications/$name.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      return PlexNotification.fromJson(json).events;
    }

    test('play state', () {
      for (final (name, state) in [
        ('playing_playing', PlexPlayState.playing),
        ('playing_paused', PlexPlayState.paused),
        ('playing_stopped', PlexPlayState.stopped),
      ]) {
        final e = decode(name).single as PlexPlaySessionEvent;
        expect(e.state, state, reason: name);
        expect(e.ratingKey, '541');
        expect(e.key, '/library/metadata/541');
        expect(e.clientIdentifier, 'ws-player');
        expect(e.sessionKey, isNotNull);
      }
      final paused = decode('playing_paused').single as PlexPlaySessionEvent;
      expect(paused.viewOffsetMs, 2000);
    });

    test('library item lifecycle', () {
      final created = decode('timeline_created').single as PlexLibraryItemEvent;
      expect(created.isCreated, isTrue);
      expect(created.isReady, isFalse);
      expect(created.type, PlexMetadataType.track);
      expect(created.parentItemId, isNotNull);
      expect(created.rootItemId, isNotNull);
      expect(created.sectionId, '1');

      final analyzing =
          decode('timeline_analyzing').single as PlexLibraryItemEvent;
      expect(analyzing.mediaState, 'analyzing');
      expect(analyzing.isReady, isFalse);

      final artwork = decode('timeline_artwork').single as PlexLibraryItemEvent;
      expect(artwork.itemId, '2');
      expect(artwork.type, PlexMetadataType.album);
      expect(artwork.isReady, isTrue);
      expect(artwork.updatedAt, isNotNull);

      final deleted = decode('timeline_deleted').single as PlexLibraryItemEvent;
      expect(deleted.isDeleted, isTrue);
    });

    test('library scan activity', () {
      final started = decode('activity_started').single as PlexActivityEvent;
      expect(started.event, 'started');
      expect(started.activityType, 'library.update.section');
      expect(started.isLibraryScan, isTrue);
      expect(started.isEnded, isFalse);

      final ended = decode('activity_ended').single as PlexActivityEvent;
      expect(ended.isEnded, isTrue);
      expect(ended.progress, 100);
      expect(ended.librarySectionId, '1');
      expect(ended.uuid, isNotEmpty);
    });

    test('status and untyped frames', () {
      final status = decode('status').single as PlexStatusEvent;
      expect(status.notificationName, 'LIBRARY_UPDATE');
      final progress = decode('progress').single;
      expect(progress, isA<PlexUnknownEvent>());
      expect((progress as PlexUnknownEvent).type, 'progress');
    });

    test('the stream extension flattens frames into events', () async {
      final frames = Stream.fromIterable([
        for (final n in ['playing_playing', 'activity_ended', 'progress'])
          PlexNotification.fromJson(
            jsonDecode(
              File('test/fixtures/notifications/$n.json').readAsStringSync(),
            ) as Map<String, dynamic>,
          ),
      ]);
      final events = await frames.events().toList();
      expect(events.map((e) => e.runtimeType), [
        PlexPlaySessionEvent,
        PlexActivityEvent,
        PlexUnknownEvent,
      ]);
    });
  });
}
