// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Field-level assertions for every Plex DTO that ships in the
/// library. Each fixture below is a real response shape captured from
/// a Plex Media Server 1.43.x seeded by `bootstrap.dart`; the fixtures
/// are inlined as raw strings so the tests stay self-contained and
/// committable (no PII — only synthetic Test Artist / Test Album /
/// Track N payloads).
library;

import 'dart:convert';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

const _libSectionsJson = r'''
{
  "MediaContainer": {
    "size": 1,
    "allowSync": false,
    "title1": "Plex Library",
    "Directory": [
      {
        "allowSync": true,
        "filters": true,
        "refreshing": false,
        "key": "1",
        "type": "artist",
        "title": "Music",
        "agent": "tv.plex.agents.music",
        "scanner": "Plex Music",
        "language": "en-US",
        "uuid": "b288969a-4bd7-4544-850a-c4297b7c1697",
        "updatedAt": 1779639107,
        "createdAt": 1779639107,
        "scannedAt": 1779639109,
        "content": true,
        "directory": true,
        "contentChangedAt": 170,
        "hidden": 0,
        "Location": [
          {"id": 1, "path": "/data/Music"}
        ]
      }
    ]
  }
}
''';

const _trackMetadataJson = r'''
{
  "ratingKey": "3",
  "key": "/library/metadata/3",
  "parentRatingKey": "2",
  "grandparentRatingKey": "1",
  "guid": "local://3",
  "parentGuid": "local://2",
  "grandparentGuid": "local://1",
  "type": "track",
  "title": "Track 1",
  "titleSort": "0001 Track 1",
  "grandparentKey": "/library/metadata/1",
  "parentKey": "/library/metadata/2",
  "librarySectionTitle": "Music",
  "librarySectionID": 1,
  "grandparentTitle": "Test Artist",
  "parentTitle": "Test Album",
  "parentThumb": "/library/metadata/2/thumb/170",
  "grandparentThumb": "/library/metadata/1/thumb/170",
  "summary": "",
  "index": 1,
  "parentIndex": 1,
  "userRating": 10.0,
  "rating": 8.5,
  "viewCount": 4,
  "viewOffset": 1500,
  "lastViewedAt": 1779652564,
  "parentYear": 2020,
  "year": 2020,
  "duration": 3030,
  "addedAt": 1779638229,
  "updatedAt": 1779638230,
  "thumb": "/library/metadata/3/thumb/170",
  "art": "/library/metadata/1/art/170",
  "Media": [
    {
      "id": 1,
      "duration": 3030,
      "bitrate": 128,
      "audioChannels": 2,
      "audioCodec": "mp3",
      "container": "mp3",
      "audioSampleRate": 44100,
      "Part": [
        {
          "id": 1,
          "key": "/library/parts/1/1779638229/file.mp3",
          "duration": 3030,
          "file": "/data/Music/Test Artist/Test Album/01 - Track 1.mp3",
          "size": 49038,
          "container": "mp3",
          "Stream": [
            {
              "id": 1,
              "streamType": 2,
              "selected": true,
              "codec": "mp3",
              "index": 0,
              "channels": 2,
              "bitrate": 128
            }
          ]
        }
      ]
    }
  ],
  "Genre": [
    {"id": 1, "tag": "Rock", "filter": "genre=1"}
  ],
  "Mood": [
    {"id": 1, "tag": "Energetic"}
  ],
  "Style": []
}
''';

const _hubsSearchJson = r'''
{
  "MediaContainer": {
    "size": 2,
    "Hub": [
      {
        "title": "Tracks",
        "type": "track",
        "hubIdentifier": "track",
        "hubKey": "hubkey-track",
        "context": "",
        "size": 1,
        "more": false,
        "Metadata": [
          {
            "ratingKey": "3",
            "key": "/library/metadata/3",
            "type": "track",
            "title": "Track 1",
            "duration": 3030,
            "addedAt": 1779638229
          }
        ]
      },
      {
        "title": "Albums",
        "type": "album",
        "hubIdentifier": "album",
        "hubKey": "hubkey-album",
        "size": 0,
        "more": false
      }
    ]
  }
}
''';

const _sessionWithPlayerAndUserJson = r'''
{
  "ratingKey": "3",
  "key": "/library/metadata/3",
  "type": "track",
  "title": "Track 1",
  "duration": 3030,
  "viewOffset": 1234,
  "addedAt": 1779638229,
  "Player": {
    "title": "iPhone",
    "product": "Plex for iOS",
    "platform": "iOS",
    "device": "iPhone15,2",
    "state": "playing",
    "local": true,
    "address": "192.168.1.5"
  },
  "User": {
    "id": "42",
    "title": "alex",
    "thumb": "https://plex.tv/users/avatar/42.png"
  },
  "Session": {
    "id": "session-uuid-1",
    "bandwidth": 480
  },
  "TranscodeSession": {
    "key": "transcode-key",
    "videoDecision": "copy",
    "audioDecision": "transcode",
    "protocol": "hls",
    "progress": 12.5
  }
}
''';

const _userJsonV2 = r'''
{
  "id": 1234567,
  "uuid": "user-uuid-xyz",
  "username": "alex",
  "email": "alex@example.test",
  "thumb": "https://plex.tv/users/avatar/1234567.png",
  "authToken": "tok-xyz",
  "subscription": {"active": true, "status": "Active"}
}
''';

const _userJsonLegacy = r'''
{
  "user": {
    "id": 1234567,
    "uuid": "user-uuid-xyz",
    "username": "alex",
    "email": "alex@example.test",
    "auth_token": "tok-legacy",
    "subscription": {"active": false, "status": "Inactive"}
  }
}
''';

const _playQueueJson = r'''
{
  "MediaContainer": {
    "size": 1,
    "playQueueID": 15,
    "playQueueSelectedItemID": 54,
    "playQueueSelectedItemOffset": 0,
    "playQueueSelectedMetadataItemID": "3",
    "playQueueShuffled": false,
    "playQueueVersion": 1,
    "Metadata": [
      {
        "playQueueItemID": 54,
        "ratingKey": "3",
        "key": "/library/metadata/3",
        "type": "track",
        "title": "Track 1",
        "duration": 3030,
        "addedAt": 1779638229
      }
    ]
  }
}
''';

const _ultraBlurJson = r'''
{
  "topLeft": "112233",
  "topRight": "445566",
  "bottomLeft": "778899",
  "bottomRight": "aabbcc"
}
''';

void main() {
  group('PlexLibrarySection.fromJson', () {
    test('lifts every promoted field + flattens Location.path', () {
      final container = jsonDecode(_libSectionsJson) as Map<String, dynamic>;
      final mc = PlexMediaContainer.fromJson(
        container,
        'Directory',
        PlexLibrarySection.fromJson,
      );
      expect(mc.items, hasLength(1));
      final s = mc.items.single;
      expect(s.id, '1');
      expect(s.title, 'Music');
      expect(s.type, PlexLibraryType.music);
      expect(s.agent, 'tv.plex.agents.music');
      expect(s.scanner, 'Plex Music');
      expect(s.language, 'en-US');
      expect(s.uuid, 'b288969a-4bd7-4544-850a-c4297b7c1697');
      expect(s.scannedAt, isNotNull);
      // 1779639109 unix → 2026-05-24 epoch
      expect(s.scannedAt!.year, 2026);
      expect(s.createdAt, isNotNull);
      expect(s.locations, ['/data/Music']);
    });
  });

  group('PlexMetadata.fromJson', () {
    test('parses a track item with media + parts + streams + tag lists', () {
      final m = PlexMetadata.fromJson(
        jsonDecode(_trackMetadataJson) as Map<String, dynamic>,
      );

      // Identity / hierarchy
      expect(m.ratingKey, '3');
      expect(m.key, '/library/metadata/3');
      expect(m.guid, 'local://3');
      expect(m.type, PlexMetadataType.track);
      expect(m.title, 'Track 1');
      expect(m.titleSort, '0001 Track 1');
      expect(m.parentRatingKey, '2');
      expect(m.parentKey, '/library/metadata/2');
      expect(m.parentTitle, 'Test Album');
      expect(m.parentThumb, '/library/metadata/2/thumb/170');
      expect(m.parentIndex, 1);
      expect(m.grandparentRatingKey, '1');
      expect(m.grandparentTitle, 'Test Artist');
      expect(m.grandparentThumb, '/library/metadata/1/thumb/170');
      expect(m.thumb, '/library/metadata/3/thumb/170');
      expect(m.art, '/library/metadata/1/art/170');

      // Index / ordering / duration
      expect(m.index, 1);
      expect(m.durationMs, 3030);
      expect(m.year, 2020);

      // Ratings / views
      expect(m.userRating, 10.0);
      expect(m.rating, 8.5);
      expect(m.viewCount, 4);
      expect(m.viewOffsetMs, 1500);
      expect(m.isFavorite, isTrue);

      // Dates (Plex uses unix seconds, not milliseconds)
      expect(m.lastViewedAt, isNotNull);
      expect(m.lastViewedAt!.year, 2026);
      expect(m.addedAt, isNotNull);
      expect(m.updatedAt, isNotNull);

      // Media → Part → Stream tree
      expect(m.media, hasLength(1));
      expect(m.media.single.audioCodec, 'mp3');
      expect(m.media.single.bitrate, 128);
      expect(m.media.single.audioChannels, 2);
      expect(m.media.single.sampleRate, 44100);
      expect(m.media.single.parts, hasLength(1));
      expect(m.media.single.parts.single.file,
          '/data/Music/Test Artist/Test Album/01 - Track 1.mp3');
      expect(m.media.single.parts.single.size, 49038);
      expect(m.media.single.parts.single.streams, hasLength(1));
      expect(m.media.single.parts.single.streams.single.codec, 'mp3');
      expect(m.media.single.parts.single.streams.single.isAudio, isTrue);

      // Tag lists (Genre/Mood/Style come as `{tag: ...}` maps, not strings)
      expect(m.genres, ['Rock']);
      expect(m.moods, ['Energetic']);
      expect(m.styles, isEmpty);
    });

    test('isFavorite is false when userRating below 10', () {
      final m = PlexMetadata.fromJson({
        'ratingKey': '1',
        'key': '/x',
        'type': 'track',
        'title': 'x',
        'userRating': 5.0,
      });
      expect(m.isFavorite, isFalse);
    });

    test('handles a minimal item without crashing on missing fields', () {
      final m = PlexMetadata.fromJson({
        'ratingKey': '99',
        'key': '/library/metadata/99',
        'type': 'track',
        'title': 'minimal',
      });
      expect(m.media, isEmpty);
      expect(m.genres, isEmpty);
      expect(m.year, isNull);
      expect(m.userRating, isNull);
      expect(m.lastViewedAt, isNull);
      expect(m.isFavorite, isFalse);
    });
  });

  group('PlexHub.fromJson', () {
    test('parses container with Hub → Metadata nesting', () {
      final container = jsonDecode(_hubsSearchJson) as Map<String, dynamic>;
      final mc = PlexMediaContainer.fromJson(
        container,
        'Hub',
        PlexHub.fromJson,
      );
      expect(mc.items, hasLength(2));

      final tracksHub = mc.items.first;
      expect(tracksHub.title, 'Tracks');
      expect(tracksHub.hubIdentifier, 'track');
      expect(tracksHub.hubKey, 'hubkey-track');
      expect(tracksHub.type, 'track');
      expect(tracksHub.size, 1);
      expect(tracksHub.more, isFalse);
      expect(tracksHub.items, hasLength(1));
      expect(tracksHub.items.first.ratingKey, '3');

      final emptyHub = mc.items.last;
      expect(emptyHub.title, 'Albums');
      expect(emptyHub.items, isEmpty);
    });
  });

  group('PlexSession.fromJson', () {
    test('flattens Metadata + Player + User + TranscodeSession', () {
      final s = PlexSession.fromJson(
        jsonDecode(_sessionWithPlayerAndUserJson) as Map<String, dynamic>,
      );
      expect(s.metadata.ratingKey, '3');
      expect(s.metadata.title, 'Track 1');
      expect(s.viewOffsetMs, 1234);

      expect(s.player, isNotNull);
      expect(s.player!.title, 'iPhone');
      expect(s.player!.product, 'Plex for iOS');
      expect(s.player!.platform, 'iOS');
      expect(s.player!.device, 'iPhone15,2');
      expect(s.player!.state, 'playing');
      expect(s.player!.local, isTrue);
      expect(s.player!.address, '192.168.1.5');

      expect(s.user, isNotNull);
      expect(s.user!.id, '42');
      expect(s.user!.title, 'alex');
      expect(s.user!.thumb, 'https://plex.tv/users/avatar/42.png');

      expect(s.sessionId, 'session-uuid-1');
      expect(s.bandwidth, 480);

      expect(s.transcodeSession, isNotNull);
      expect(s.transcodeSession!['videoDecision'], 'copy');
      expect(s.transcodeSession!['audioDecision'], 'transcode');
    });

    test('handles missing Player/User/TranscodeSession gracefully', () {
      final s = PlexSession.fromJson({
        'ratingKey': '1',
        'key': '/x',
        'type': 'track',
        'title': 'bare',
      });
      expect(s.player, isNull);
      expect(s.user, isNull);
      expect(s.sessionId, isNull);
      expect(s.transcodeSession, isNull);
    });
  });

  group('PlexUser.fromJson', () {
    test('parses the modern flat v2 shape', () {
      final u = PlexUser.fromJson(
        jsonDecode(_userJsonV2) as Map<String, dynamic>,
      );
      expect(u.id, 1234567);
      expect(u.uuid, 'user-uuid-xyz');
      expect(u.username, 'alex');
      expect(u.email, 'alex@example.test');
      expect(u.authToken, 'tok-xyz');
      expect(u.hasPlexPass, isTrue);
    });

    test('unwraps the legacy { user: { ... } } envelope', () {
      final u = PlexUser.fromJson(
        jsonDecode(_userJsonLegacy) as Map<String, dynamic>,
      );
      expect(u.username, 'alex');
      expect(u.authToken, 'tok-legacy');
      expect(u.hasPlexPass, isFalse);
    });
  });

  group('PlexPlayQueue.fromJson', () {
    test('lifts container-level fields + items', () {
      final q = PlexPlayQueue.fromJson(
        jsonDecode(_playQueueJson) as Map<String, dynamic>,
      );
      expect(q.id, 15);
      expect(q.selectedItemId, 54);
      expect(q.shuffled, isFalse);
      expect(q.version, 1);
      expect(q.items, hasLength(1));
      expect(q.items.single.ratingKey, '3');
      expect(q.raw['playQueueSelectedMetadataItemID'], '3');
    });

    test('throws PlexException(parse) when MediaContainer is missing', () {
      expect(
        () => PlexPlayQueue.fromJson(const {}),
        throwsA(isA<PlexException>().having(
          (e) => e.type,
          'type',
          PlexErrorType.parse,
        )),
      );
    });
  });

  group('PlexUltraBlurColors.fromJson', () {
    test('parses the four corner colours', () {
      final c = PlexUltraBlurColors.fromJson(
        jsonDecode(_ultraBlurJson) as Map<String, dynamic>,
      );
      expect(c.topLeft, '112233');
      expect(c.topRight, '445566');
      expect(c.bottomLeft, '778899');
      expect(c.bottomRight, 'aabbcc');
    });
  });

  group('PlexNotification.fromJson', () {
    test('parses a playing frame with size + type', () {
      const json = r'''
{
  "type": "playing",
  "size": 1,
  "PlaySessionStateNotification": [
    {"sessionKey": "1", "guid": "local://3", "ratingKey": "3", "state": "playing"}
  ]
}
''';
      final n = PlexNotification.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(n.type, 'playing');
      expect(n.size, 1);
      expect(n.raw['PlaySessionStateNotification'], isA<List<dynamic>>());
    });

    test('parses a transcodeSession.update frame', () {
      const json = r'''
{
  "type": "transcodeSession.update",
  "size": 1,
  "TranscodeSession": [
    {"key": "ts-1", "videoDecision": "copy", "audioDecision": "transcode", "progress": 12.5}
  ]
}
''';
      final n = PlexNotification.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(n.type, 'transcodeSession.update');
      expect(n.size, 1);
    });

    test('handles size delivered as string (real frame quirk)', () {
      final n = PlexNotification.fromJson(const {
        'type': 'activity',
        'size': '3',
      });
      expect(n.type, 'activity');
      expect(n.size, 3);
    });

    test('falls back to "unknown" when type is missing', () {
      final n = PlexNotification.fromJson(const {});
      expect(n.type, 'unknown');
      expect(n.size, isNull);
    });
  });

  group('PlexMetadataType.fromWire / numeric', () {
    test('round-trips the canonical names', () {
      expect(PlexMetadataType.track.wire, 'track');
      expect(PlexMetadataType.fromWire('track'), PlexMetadataType.track);
      expect(PlexMetadataType.album.wire, 'album');
      expect(PlexMetadataType.fromWire('album'), PlexMetadataType.album);
      expect(PlexMetadataType.fromWire('unknown-type'),
          PlexMetadataType.unknown);
    });
  });
}
