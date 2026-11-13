// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Play-queue editing, the server log, preferences, the flat and voice
/// searches, the server identity and the transient token on the wire.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/fixtures.dart';
import '_helpers/wire_calls.dart';

const _uri =
    'server://0000000000000000000000000000000000000000/'
    'com.plexapp.plugins.library/library/metadata/3,4';

void main() {
  group('requests', () {
    testWireCalls([
      (
        'playQueues.addItems (at the end)',
        (p) => p.playQueues.addItems(playQueueId: 12, uri: _uri),
        'PUT',
        '/playQueues/12',
        {'uri': _uri},
      ),
      (
        'playQueues.addItems (a playlist, next)',
        (p) => p.playQueues.addItems(
          playQueueId: 12,
          playlistId: '20',
          playNext: true,
        ),
        'PUT',
        '/playQueues/12',
        {'playlistID': '20', 'next': '1'},
      ),
      (
        'playQueues.moveItem (to the top)',
        (p) => p.playQueues.moveItem(playQueueId: 12, playQueueItemId: 101),
        'PUT',
        '/playQueues/12/items/101/move',
        {},
      ),
      (
        'playQueues.moveItem (after another)',
        (p) => p.playQueues.moveItem(
          playQueueId: 12,
          playQueueItemId: 101,
          afterPlaylistItemId: 100,
        ),
        'PUT',
        '/playQueues/12/items/101/move',
        {'after': '100'},
      ),
      (
        'playQueues.shuffle',
        (p) => p.playQueues.shuffle(playQueueId: 12),
        'PUT',
        '/playQueues/12/shuffle',
        {},
      ),
      (
        'playQueues.unshuffle',
        (p) => p.playQueues.unshuffle(playQueueId: 12),
        'PUT',
        '/playQueues/12/unshuffle',
        {},
      ),
      (
        'playQueues.reset',
        (p) => p.playQueues.reset(playQueueId: 12),
        'PUT',
        '/playQueues/12/reset',
        {},
      ),
      (
        'streaming.pingUniversal',
        (p) => p.streaming.pingUniversal(session: 'sess-1'),
        'GET',
        '/video/:/transcode/universal/ping',
        {'session': 'sess-1'},
      ),
      (
        'log.writeMessage',
        (p) => p.log.writeMessage(
          level: 3,
          message: 'Playback failed: 50% & rising',
          source: 'my app',
        ),
        'PUT',
        '/log',
        {
          'level': '3',
          'message': 'Playback failed: 50% & rising',
          'source': 'my app',
        },
      ),
      (
        'log.enablePapertrail',
        (p) => p.log.enablePapertrail(minutes: 30),
        'POST',
        '/log/networked',
        {'minutes': '30'},
      ),
      ('preferences.all', (p) => p.preferences.all(), 'GET', '/:/prefs', {}),
      (
        'preferences.byId',
        (p) => p.preferences.byId(id: 'FriendlyName'),
        'GET',
        '/:/prefs/get',
        {'id': 'FriendlyName'},
      ),
      (
        'search.flat (default limit)',
        (p) => p.search.flat(query: 'Rock & Roll'),
        'GET',
        '/search',
        {'query': 'Rock & Roll', 'limit': '30'},
      ),
      (
        'search.voice (default)',
        (p) => p.search.voice(query: 'play jazz'),
        'GET',
        '/hubs/search/voice',
        {'query': 'play jazz', 'limit': '10'},
      ),
      (
        'search.voice (type, limit)',
        (p) => p.search.voice(
          query: 'play jazz',
          type: PlexMetadataType.album,
          limit: 3,
        ),
        'GET',
        '/hubs/search/voice',
        {'query': 'play jazz', 'limit': '3', 'type': '9'},
      ),
      (
        'server.transientToken',
        (p) => p.server.transientToken(),
        'POST',
        '/security/token',
        {'type': 'delegation', 'scope': 'all'},
      ),
    ]);

    test('playback.setFavorite rates 10, or 0 to clear', () async {
      final adapter = CapturingAdapter();
      final plex = testClient(adapter);
      await plex.playback.setFavorite(ratingKey: '3', isFavorite: true);
      var request = adapter.last!;
      expect(request.method, 'PUT');
      expect(request.uri.path, '/:/rate');
      expect(request.queryParameters['key'], '3');
      expect(
        request.queryParameters['identifier'],
        'com.plexapp.plugins.library',
      );
      expect(double.parse(request.queryParameters['rating']!), 10);
      await plex.playback.setFavorite(ratingKey: '3', isFavorite: false);
      request = adapter.last!;
      expect(double.parse(request.queryParameters['rating']!), 0);
    });

    test('log.writeBlock posts the bytes with their content type', () async {
      final adapter = CapturingAdapter();
      final body = Uint8List.fromList(utf8.encode('line 1\nlìne 2\n'));
      await testClient(adapter).log.writeBlock(body: body);
      var request = adapter.last!;
      expect(request.method, 'POST');
      expect(request.uri.path, '/log');
      expect(request.uri.query, isEmpty);
      expect(request.body, body);
      expect(request.headers['Content-Type'], startsWith('text/plain'));
      await testClient(
        adapter,
      ).log.writeBlock(body: body, contentType: 'application/x-ndjson');
      request = adapter.last!;
      expect(request.headers['Content-Type'], 'application/x-ndjson');
      expect(request.body, body);
    });
  });

  group('answers', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    test('identity and info read the server (PMS 1.43.2)', () async {
      answer(realFixture('identity'));
      final id = await plex.server.identity();
      expect(adapter.last!.uri.path, '/identity');
      expect(id.machineIdentifier, hasLength(40));
      expect((id.claimed, id.apiVersion), (true, '1.2.2'));
      expect(id.version, startsWith('1.43.2'));
      answer(realFixture('server_info'));
      final info = await plex.server.info();
      expect(adapter.last!.uri.path, '/');
      expect(info.version, startsWith('1.43.'));
    });

    test('ping is true when the server answers, false when it does '
        'not', () async {
      answer(realFixture('identity'));
      expect(await plex.server.ping(), isTrue);
      expect(adapter.last!.uri.path, '/identity');
      adapter.respond = (_) =>
          CannedResponse(503, const [], contentType: 'text/html');
      expect(await plex.server.ping(), isFalse);
    });

    test('transientToken reads the token, or null without one', () async {
      answer({
        'MediaContainer': {'size': 0, 'token': 'transient-abc'},
      });
      expect(await plex.server.transientToken(), 'transient-abc');
      answer({
        'MediaContainer': {'size': 0},
      });
      expect(await plex.server.transientToken(), isNull);
      adapter.respond = (_) => CannedResponse(200, const []);
      expect(await plex.server.transientToken(), isNull);
    });

    test('preferences read the settings; byId is null when the server '
        'knows none', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'Setting': [
            {
              'id': 'FriendlyName',
              'label': 'Friendly name',
              'summary': 'The name of this server.',
              'type': 'text',
              'default': '',
              'value': 'Test server',
              'hidden': false,
              'advanced': false,
              'group': 'general',
            },
          ],
        },
      });
      final all = await plex.preferences.all();
      expect((all.single.id, all.single.group), ('FriendlyName', 'general'));
      expect((all.single.hidden, all.single.advanced), (false, false));
      expect(all.single.raw['value'], 'Test server');
      expect((await plex.preferences.byId(id: 'FriendlyName'))!.id, all[0].id);
      answer({
        'MediaContainer': {'size': 0},
      });
      expect(await plex.preferences.all(), isEmpty);
      expect(await plex.preferences.byId(id: 'Nope'), isNull);
    });

    test('search.flat reads items and search.voice reads hubs', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'Metadata': [
            {'ratingKey': '3', 'type': 'track', 'title': 'Track 1'},
          ],
        },
      });
      final flat = await plex.search.flat(query: 'Track', limit: 5);
      expect(adapter.last!.queryParameters['limit'], '5');
      expect((flat.single.ratingKey, flat.single.title), ('3', 'Track 1'));
      answer({
        'MediaContainer': {
          'size': 1,
          'Hub': [
            {
              'hubIdentifier': 'track',
              'title': 'Tracks',
              'type': 'track',
              'size': 1,
              'Metadata': [
                {'ratingKey': '3', 'type': 'track', 'title': 'Track 1'},
              ],
            },
          ],
        },
      });
      final voice = await plex.search.voice(query: 'Track');
      expect(
        (voice.single.hubIdentifier, voice.single.items.single.title),
        ('track', 'Track 1'),
      );
      answer({
        'MediaContainer': {'size': 0},
      });
      expect(await plex.search.flat(query: 'zzz'), isEmpty);
      expect(await plex.search.voice(query: 'zzz'), isEmpty);
    });
  });
}
