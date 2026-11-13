// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// What the sub-APIs do with their arguments before anything is sent: the
/// signed URLs of the device thumb, the live session and the download
/// queue; ids as path segments; arguments refused with an [ArgumentError].
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

const _server = 'http://192.168.1.10:32400';

final Matcher _throwsState = throwsA(
  isA<PlexException>().having((e) => e.type, 'type', PlexErrorType.state),
);

void main() {
  group('signed URLs', () {
    final builders = <String, (String Function(PlexClient), String)>{
      'devices.thumbUrl': (
        (p) => p.devices.thumbUrl(deviceId: '4', version: '3'),
        '/media/grabbers/devices/4/thumb/3',
      ),
      'liveTv.sessionPlaylistUrl': (
        (p) => p.liveTv.sessionPlaylistUrl(sessionId: 's1', consumerId: 'c1'),
        '/livetv/sessions/s1/c1/index.m3u8',
      ),
      'liveTv.sessionSegmentUrl': (
        (p) => p.liveTv.sessionSegmentUrl(
          sessionId: 's1',
          consumerId: 'c1',
          segmentId: '7.ts',
        ),
        '/livetv/sessions/s1/c1/7.ts',
      ),
      'downloadQueue.itemMediaUrl': (
        (p) => p.downloadQueue.itemMediaUrl(queueId: 1, itemId: 2),
        '/downloadQueue/1/item/2/media',
      ),
    };

    PlexClient offline() => PlexClient(
      credentials: testCredentials,
      httpClient: CapturingAdapter(),
    );

    for (final MapEntry(key: name, value: (build, path)) in builders.entries) {
      test('$name before connect is a state error, not "null/…"', () {
        expect(() => build(offline()), _throwsState);
      });

      test('$name form-encodes the token', () {
        final plex = offline()..connect(_server, accessToken: 'a b&c=d+e/f');
        expect(build(plex), '$_server$path?X-Plex-Token=a+b%26c%3Dd%2Be%2Ff');
      });

      test('$name without a token carries no X-Plex-Token', () {
        expect(build(offline()..connect(_server)), '$_server$path');
        final empty = offline()..connect(_server, accessToken: '');
        expect(build(empty), '$_server$path');
      });
    }

    test('their ids are path segments', () {
      final plex = offline()..connect(_server);
      expect(
        plex.devices.thumbUrl(deviceId: 'a/b', version: '1?x'),
        '$_server/media/grabbers/devices/a%2Fb/thumb/1%3Fx',
      );
      expect(
        plex.liveTv.sessionSegmentUrl(
          sessionId: 'a/b',
          consumerId: 'c#d',
          segmentId: '../x',
        ),
        '$_server/livetv/sessions/a%2Fb/c%23d/..%2Fx',
      );
      expect(
        () => plex.liveTv.sessionPlaylistUrl(sessionId: '..', consumerId: 'c'),
        throwsArgumentError,
      );
    });
  });

  group('an id is one path segment', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter(const {'MediaContainer': <String, Object?>{}});
      plex = testClient(adapter);
    });

    // Each call with the id `a/b?c`, and the path it must be sent to.
    final calls =
        <String, (Future<Object?> Function(PlexClient, String), String)>{
          'activities.cancel': (
            (p, id) => p.activities.cancel(activityId: id),
            '/activities/a%2Fb%3Fc',
          ),
          'butler.start': (
            (p, id) => p.butler.start(butlerTask: id),
            '/butler/a%2Fb%3Fc',
          ),
          'butler.stop': (
            (p, id) => p.butler.stop(butlerTask: id),
            '/butler/a%2Fb%3Fc',
          ),
          'devices.details': (
            (p, id) => p.devices.details(deviceId: id),
            '/media/grabbers/devices/a%2Fb%3Fc',
          ),
          'devices.startScan': (
            (p, id) => p.devices.startScan(deviceId: id),
            '/media/grabbers/devices/a%2Fb%3Fc/scan',
          ),
          'dvrs.get': (
            (p, id) => p.dvrs.get(dvrId: id),
            '/livetv/dvrs/a%2Fb%3Fc',
          ),
          'dvrs.tuneChannel': (
            (p, id) => p.dvrs.tuneChannel(dvrId: id, channel: id),
            '/livetv/dvrs/a%2Fb%3Fc/channels/a%2Fb%3Fc/tune',
          ),
          'dvrs.addDevice': (
            (p, id) => p.dvrs.addDevice(dvrId: '7', deviceId: id),
            '/livetv/dvrs/7/devices/a%2Fb%3Fc',
          ),
          'epg.regionLineups': (
            (p, id) => p.epg.regionLineups(country: id, epgId: id, region: id),
            '/livetv/epg/countries/a%2Fb%3Fc/a%2Fb%3Fc/regions/a%2Fb%3Fc/lineups',
          ),
          'liveTv.liveSession': (
            (p, id) => p.liveTv.liveSession(sessionId: id),
            '/livetv/sessions/a%2Fb%3Fc',
          ),
          'playlists.items': (
            (p, id) => p.playlists.items(playlistId: id),
            '/playlists/a%2Fb%3Fc/items',
          ),
          'playlists.moveItem': (
            (p, id) => p.playlists.moveItem(playlistId: id, playlistItemId: id),
            '/playlists/a%2Fb%3Fc/items/a%2Fb%3Fc/move',
          ),
          'playlists.reprocessGenerator': (
            (p, id) => p.playlists.reprocessGenerator(
              playlistId: '9',
              generatorId: 1,
              metadataId: id,
              action: id,
            ),
            '/playlists/9/items/1/a%2Fb%3Fc/a%2Fb%3Fc',
          ),
          'providers.delete': (
            (p, id) => p.providers.delete(provider: id),
            '/media/providers/a%2Fb%3Fc',
          ),
          'search.section': (
            (p, id) => p.search.section(
              sectionId: id,
              query: 'q',
              type: PlexMetadataType.track,
            ),
            '/library/sections/a%2Fb%3Fc/search',
          ),
          'sessions.historyItem': (
            (p, id) => p.sessions.historyItem(historyId: id),
            '/status/sessions/history/a%2Fb%3Fc',
          ),
          'subscriptions.get': (
            (p, id) => p.subscriptions.get(subscriptionId: id),
            '/media/subscriptions/a%2Fb%3Fc',
          ),
          'subscriptions.cancelGrab': (
            (p, id) => p.subscriptions.cancelGrab(operationId: id),
            '/media/grabbers/operations/a%2Fb%3Fc',
          ),
        };

    for (final MapEntry(key: name, value: (call, path)) in calls.entries) {
      test('$name encodes "/" and "?" in it', () async {
        await call(plex, 'a/b?c');
        expect(adapter.last!.uri.path, path);
        expect(adapter.last!.uri.queryParameters.containsKey('c'), isFalse);
      });

      test('$name refuses an empty id and ".."', () async {
        for (final id in ['', '..']) {
          await expectLater(
            Future<Object?>.sync(() => call(plex, id)),
            throwsArgumentError,
          );
        }
        expect(adapter.requests, isEmpty);
      });
    }

    test('a key the server gave goes as it is', () async {
      await plex.liveTv.dvrChannels(dvrKey: '/livetv/dvrs/7');
      expect(adapter.last!.uri.path, '/livetv/dvrs/7/channels');
      await plex.sessions.deleteHistoryEntry(
        historyKey: '/status/sessions/history/12',
      );
      expect(adapter.last!.uri.path, '/status/sessions/history/12');
    });

    test('an int id and a list of keys go as they are', () async {
      await plex.sessions.historyItem(historyId: 12);
      expect(adapter.last!.uri.path, '/status/sessions/history/12');
      await plex.playlists.items(playlistId: '1,2');
      expect(adapter.last!.uri.path, '/playlists/1,2/items');
    });
  });

  group('arguments refused before anything is sent', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter(const {'MediaContainer': <String, Object?>{}});
      plex = testClient(adapter);
    });

    test(
      'playQueues.addItems takes exactly one of uri and playlistId',
      () async {
        await expectLater(
          plex.playQueues.addItems(playQueueId: 1),
          throwsArgumentError,
        );
        await expectLater(
          plex.playQueues.addItems(playQueueId: 1, uri: 'u', playlistId: '2'),
          throwsArgumentError,
        );
        expect(adapter.requests, isEmpty);
        await plex.playQueues.addItems(playQueueId: 1, playlistId: '2');
        expect(adapter.last!.queryParameters, {'playlistID': '2'});
      },
    );

    test('epg.lineupChannels needs a lineup', () async {
      await expectLater(
        plex.epg.lineupChannels(lineup: const []),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });

    test('server.securityResources needs a source', () async {
      await expectLater(
        plex.server.securityResources(source: ''),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('optional parameters left out send no query', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter(const {'MediaContainer': <String, Object?>{}});
      plex = testClient(adapter);
    });

    test('no "?" on the wire', () async {
      await plex.devices.grabbers();
      expect(adapter.last!.uri.hasQuery, isFalse);
      await plex.devices.setChannelMap(deviceId: '4');
      expect(adapter.last!.uri.hasQuery, isFalse);
      await plex.devices.setPreferences(deviceId: '4');
      expect(adapter.last!.uri.hasQuery, isFalse);
      await plex.dvrs.setPreferences(dvrId: '7');
      expect(adapter.last!.uri.hasQuery, isFalse);
      await plex.subscriptions.editPreferences(subscriptionId: '1');
      expect(adapter.last!.uri.hasQuery, isFalse);
      await plex.subscriptions.reorder(subscriptionId: '1');
      expect(adapter.last!.uri.hasQuery, isFalse);
      await plex.playlists.moveItem(playlistId: '1', playlistItemId: '2');
      expect(adapter.last!.uri.hasQuery, isFalse);
    });

    test('the order on the wire is the one it was', () async {
      await plex.devices.setPreferences(
        deviceId: '4',
        name: 'Tuner',
        prefs: {'a': 1, 'name': 'Other'},
      );
      expect(adapter.last!.uri.query, 'name=Other&a=1');
      await plex.sessions.history(
        sort: PlexSort.lastViewedAt.desc,
        accountId: 1,
      );
      expect(adapter.last!.uri.queryParameters.keys, [
        'X-Plex-Container-Start',
        'X-Plex-Container-Size',
        'accountID',
        'sort',
      ]);
      await plex.playlists.list(smart: false, type: PlexMediaType.audio);
      expect(adapter.last!.uri.queryParameters.keys, [
        'X-Plex-Container-Start',
        'X-Plex-Container-Size',
        'playlistType',
        'smart',
      ]);
    });
  });
}
