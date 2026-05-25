// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

void main() {
  group('PlexCredentials', () {
    test('toHeaders includes all required X-Plex-* fields', () {
      const c = PlexCredentials(
        clientIdentifier: 'abc-uuid',
        product: 'Finova',
        version: '1.2.3',
        device: 'iPhone',
        deviceName: "Alex's iPhone",
        platform: 'iOS',
        platformVersion: '17.4',
        clientProfileExtra: 'add-transcode-target(type=musicProfile)',
      );
      final h = c.toHeaders();
      expect(h['X-Plex-Client-Identifier'], 'abc-uuid');
      expect(h['X-Plex-Product'], 'Finova');
      expect(h['X-Plex-Version'], '1.2.3');
      expect(h['X-Plex-Device'], 'iPhone');
      expect(h['X-Plex-Device-Name'], "Alex's iPhone");
      expect(h['X-Plex-Platform'], 'iOS');
      expect(h['X-Plex-Platform-Version'], '17.4');
      expect(h['X-Plex-Client-Profile-Extra'],
          'add-transcode-target(type=musicProfile)');
      expect(h['Accept'], 'application/json');
    });

    test('platformVersion and clientProfileExtra are omitted when null', () {
      const c = PlexCredentials(
        clientIdentifier: 'u',
        product: 'p',
        version: '1',
        device: 'd',
        deviceName: 'n',
        platform: 'pl',
      );
      final h = c.toHeaders();
      expect(h.containsKey('X-Plex-Platform-Version'), isFalse);
      expect(h.containsKey('X-Plex-Client-Profile-Extra'), isFalse);
    });
  });

  group('PlexErrorType', () {
    test('fromHttpStatus maps as expected', () {
      expect(PlexErrorType.fromHttpStatus(401), PlexErrorType.auth);
      expect(PlexErrorType.fromHttpStatus(403), PlexErrorType.auth);
      expect(PlexErrorType.fromHttpStatus(404), PlexErrorType.notFound);
      expect(PlexErrorType.fromHttpStatus(418), PlexErrorType.badRequest);
      expect(PlexErrorType.fromHttpStatus(503), PlexErrorType.serverError);
      expect(PlexErrorType.fromHttpStatus(200), PlexErrorType.unknown);
    });

    test('classification helpers', () {
      expect(PlexErrorType.connection.isRetriable, isTrue);
      expect(PlexErrorType.timeout.isRetriable, isTrue);
      expect(PlexErrorType.auth.isAuthError, isTrue);
      expect(PlexErrorType.notFound.isRetriable, isFalse);
    });
  });

  group('PlexMetadataType', () {
    test('numeric and wire mapping', () {
      expect(PlexMetadataType.fromValue(9), PlexMetadataType.album);
      expect(PlexMetadataType.fromValue(10), PlexMetadataType.track);
      expect(PlexMetadataType.fromValue(999), PlexMetadataType.unknown);
      expect(PlexMetadataType.fromWire('album'), PlexMetadataType.album);
      expect(PlexMetadataType.fromWire('bogus'), PlexMetadataType.unknown);
    });
  });

  group('PlexMediaContainer.fromJson', () {
    test('extracts items and totals from a Metadata envelope', () {
      final json = {
        'MediaContainer': {
          'size': 2,
          'totalSize': 17,
          'Metadata': [
            {
              'ratingKey': '12345',
              'key': '/library/metadata/12345',
              'type': 'album',
              'title': 'Test Album',
              'parentRatingKey': '111',
              'parentTitle': 'Test Artist',
              'year': 2024,
              'duration': 360000,
              'userRating': 10,
              'thumb': '/library/metadata/12345/thumb/1700000000',
              'Genre': [
                {'tag': 'Rock'},
                {'tag': 'Indie'},
              ],
              'Media': [
                {
                  'id': 1,
                  'duration': 360000,
                  'bitrate': 320,
                  'audioCodec': 'flac',
                  'container': 'flac',
                  'audioSampleRate': 44100,
                  'Part': [
                    {
                      'id': 99,
                      'file': '/data/Music/album/track.flac',
                      'container': 'flac',
                      'Stream': [
                        {'streamType': 2, 'codec': 'flac', 'selected': true},
                      ],
                    },
                  ],
                },
              ],
            },
            {
              'ratingKey': '12346',
              'type': 'album',
              'title': 'Other Album',
            },
          ],
        },
      };

      final c = PlexMediaContainer.fromJson(
        json,
        'Metadata',
        PlexMetadata.fromJson,
      );

      expect(c.totalSize, 17);
      expect(c.size, 2);
      expect(c.items, hasLength(2));
      final m = c.items.first;
      expect(m.ratingKey, '12345');
      expect(m.title, 'Test Album');
      expect(m.type, PlexMetadataType.album);
      expect(m.year, 2024);
      expect(m.durationMs, 360000);
      expect(m.isFavorite, isTrue);
      expect(m.genres, ['Rock', 'Indie']);
      expect(m.media, hasLength(1));
      expect(m.media.first.audioCodec, 'flac');
      expect(m.media.first.parts, hasLength(1));
      expect(m.media.first.parts.first.streams.single.isAudio, isTrue);
    });

    test('throws PlexException(parse) when MediaContainer is missing', () {
      expect(
        () => PlexMediaContainer.fromJson(
          {'foo': 'bar'},
          'Metadata',
          PlexMetadata.fromJson,
        ),
        throwsA(
          isA<PlexException>().having(
            (e) => e.type,
            'type',
            PlexErrorType.parse,
          ),
        ),
      );
    });
  });

  group('PlexResource.bestConnection', () {
    test('prefers local non-relay first', () {
      final r = PlexResource.fromJson({
        'name': 'Home',
        'clientIdentifier': 'machine-id',
        'product': 'Plex Media Server',
        'productVersion': '1.40.0',
        'platform': 'macOS',
        'provides': 'server',
        'accessToken': 'tok',
        'owned': true,
        'connections': [
          {
            'protocol': 'https',
            'address': '1.2.3.4',
            'port': 32400,
            'uri': 'https://relay.example.com',
            'local': false,
            'relay': true,
          },
          {
            'protocol': 'https',
            'address': '192.168.0.10',
            'port': 32400,
            'uri': 'https://192-168-0-10.plex.direct:32400',
            'local': true,
            'relay': false,
          },
        ],
      });
      expect(r.isServer, isTrue);
      expect(r.bestConnection()!.uri,
          'https://192-168-0-10.plex.direct:32400');
    });
  });

  group('PlexPin', () {
    test('detects authenticated state', () {
      final unverified = PlexPin.fromJson({
        'id': 1,
        'code': 'ABCD',
        'clientIdentifier': 'cid',
        'createdAt': '2026-01-01T00:00:00Z',
        'expiresAt': '2099-01-01T00:00:00Z',
      });
      expect(unverified.isAuthenticated, isFalse);
      expect(unverified.isExpired, isFalse);

      final verified = PlexPin.fromJson({
        'id': 1,
        'code': 'ABCD',
        'clientIdentifier': 'cid',
        'authToken': 'tok-xyz',
        'createdAt': '2026-01-01T00:00:00Z',
        'expiresAt': '2099-01-01T00:00:00Z',
      });
      expect(verified.isAuthenticated, isTrue);
      expect(verified.authToken, 'tok-xyz');
    });
  });
}
