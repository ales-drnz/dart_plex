// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The small administrative surfaces on the wire — butler, updater,
/// providers, download queue, collections, playlist generators, history,
/// the transcoder fallback — and the models they read.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/fixtures.dart';
import '_helpers/wire_calls.dart';

const _serverId = '0000000000000000000000000000000000000000';
const _libraryUri =
    'server://$_serverId/com.plexapp.plugins.library/library/metadata';

void main() {
  group('requests', () {
    testWireCalls([
      ('butler.startAll', (p) => p.butler.startAll(), 'POST', '/butler', {}),
      ('butler.stopAll', (p) => p.butler.stopAll(), 'DELETE', '/butler', {}),
      (
        'butler.start',
        (p) => p.butler.start(butlerTask: 'BackupDatabase'),
        'POST',
        '/butler/BackupDatabase',
        {},
      ),
      (
        'butler.stop',
        (p) => p.butler.stop(butlerTask: 'BackupDatabase'),
        'DELETE',
        '/butler/BackupDatabase',
        {},
      ),
      (
        'updater.check (default)',
        (p) => p.updater.check(),
        'PUT',
        '/updater/check',
        {'download': '0'},
      ),
      (
        'updater.check (download)',
        (p) => p.updater.check(download: true),
        'PUT',
        '/updater/check',
        {'download': '1'},
      ),
      (
        'updater.apply (default)',
        (p) => p.updater.apply(),
        'PUT',
        '/updater/apply',
        {'tonight': '0', 'skip': '0'},
      ),
      (
        'updater.apply (tonight)',
        (p) => p.updater.apply(tonight: true),
        'PUT',
        '/updater/apply',
        {'tonight': '1', 'skip': '0'},
      ),
      (
        'updater.apply (skip)',
        (p) => p.updater.apply(skip: true),
        'PUT',
        '/updater/apply',
        {'tonight': '0', 'skip': '1'},
      ),
      (
        'providers.add',
        (p) => p.providers.add(url: 'https://example.com/provider?a=1&b=2'),
        'POST',
        '/media/providers',
        {'url': 'https://example.com/provider?a=1&b=2'},
      ),
      (
        'providers.refresh',
        (p) => p.providers.refresh(),
        'POST',
        '/media/providers/refresh',
        {},
      ),
      (
        'providers.delete',
        (p) => p.providers.delete(provider: 'tv.plex.provider.x'),
        'DELETE',
        '/media/providers/tv.plex.provider.x',
        {},
      ),
      (
        'downloadQueue.add',
        (p) => p.downloadQueue.add(
          queueId: 2,
          keys: ['/library/metadata/3', '/library/metadata/4'],
        ),
        'POST',
        '/downloadQueue/2/add',
        {'keys': '/library/metadata/3,/library/metadata/4'},
      ),
      (
        'downloadQueue.remove',
        (p) => p.downloadQueue.remove(queueId: 2, itemId: 7),
        'DELETE',
        '/downloadQueue/2/items/7',
        {},
      ),
      (
        'downloadQueue.restart',
        (p) => p.downloadQueue.restart(queueId: 2, itemId: 7),
        'POST',
        '/downloadQueue/2/items/7/restart',
        {},
      ),
      (
        'downloadQueue.itemDecision',
        (p) => p.downloadQueue.itemDecision(queueId: 2, itemId: 7),
        'GET',
        '/downloadQueue/2/item/7/decision',
        {},
      ),
      (
        'collections.addItems',
        (p) => p.collections.addItems(
          collectionId: '914',
          uri: '$_libraryUri/3,4',
        ),
        'PUT',
        '/library/collections/914/items',
        {'uri': '$_libraryUri/3,4'},
      ),
      (
        'collections.moveItem',
        (p) => p.collections.moveItem(
          collectionId: '914',
          itemId: '5',
          afterItemId: '3',
        ),
        'PUT',
        '/library/collections/914/items/5/move',
        {'after': '3'},
      ),
      (
        'playlists.addItems',
        (p) => p.playlists.addItems(
          playlistId: '20',
          machineIdentifier: _serverId,
          itemRatingKeys: ['3', '4'],
        ),
        'PUT',
        '/playlists/20/items',
        {'uri': '$_libraryUri/3,4'},
      ),
      (
        'playlists.rename',
        (p) => p.playlists.rename(playlistId: '20', title: 'Rock & Roll'),
        'PUT',
        '/playlists/20',
        {'title': 'Rock & Roll'},
      ),
      (
        'playlists.moveItem (to the top)',
        (p) => p.playlists.moveItem(playlistId: '20', playlistItemId: '9'),
        'PUT',
        '/playlists/20/items/9/move',
        {},
      ),
      (
        'playlists.moveItem (after another)',
        (p) => p.playlists.moveItem(
          playlistId: '20',
          playlistItemId: '9',
          afterPlaylistItemId: '8',
        ),
        'PUT',
        '/playlists/20/items/9/move',
        {'after': '8'},
      ),
      (
        'playlists.reprocessGenerator',
        (p) => p.playlists.reprocessGenerator(
          playlistId: '20',
          generatorId: 4,
          metadataId: '3',
          action: 'reprocess',
        ),
        'PUT',
        '/playlists/20/items/4/3/reprocess',
        {},
      ),
      (
        'sessions.deleteHistoryEntry',
        (p) => p.sessions.deleteHistoryEntry(
          historyKey: '/status/sessions/history/12',
        ),
        'DELETE',
        '/status/sessions/history/12',
        {'identifier': 'com.plexapp.plugins.library'},
      ),
      (
        'transcoder.triggerFallback (audio)',
        (p) => p.transcoder.triggerFallback(transcodeType: 'audio'),
        'POST',
        '/audio/:/transcode/universal/fallback',
        {},
      ),
      (
        'transcoder.triggerFallback (video)',
        (p) => p.transcoder.triggerFallback(transcodeType: 'video'),
        'POST',
        '/video/:/transcode/universal/fallback',
        {},
      ),
    ]);

    test('playlists.addItems with nothing to add sends nothing', () async {
      final adapter = CapturingAdapter();
      await testClient(adapter).playlists.addItems(
        playlistId: '20',
        machineIdentifier: _serverId,
        itemRatingKeys: const [],
      );
      expect(adapter.requests, isEmpty);
    });

    test(
      'collections.removeItem deletes the item from the collection',
      () async {
        // PMS 1.43.2: `PUT /library/collections/{id}/items/{itemId}` is 404
        // and removes nothing; `DELETE` answers 200 with the collection and
        // removes the item (checked on a temporary collection).
        final adapter = CapturingAdapter();
        await testClient(
          adapter,
        ).collections.removeItem(collectionId: '914', itemId: '4');
        expect(adapter.last!.method, 'DELETE');
        expect(adapter.last!.uri.path, '/library/collections/914/items/4');
        expect(adapter.last!.uri.query, isEmpty);
      },
    );
  });

  group('answers', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    test('butler.tasks reads the tasks (PMS 1.43.2), and none from an '
        'answer without them', () async {
      answer(realFixture('butler'));
      final tasks = await plex.butler.tasks();
      expect(adapter.last!.uri.path, '/butler');
      expect(tasks.map((t) => t.name), contains('BackupDatabase'));
      answer({
        'MediaContainer': {'size': 0},
      });
      expect(await plex.butler.tasks(), isEmpty);
      adapter.respond = (_) => CannedResponse(200, const []);
      expect(await plex.butler.tasks(), isEmpty);
    });

    test('providers.add reads the providers and PlexProviderFeature '
        '(PMS 1.43.2 shape)', () async {
      answer(realFixture('providers'));
      final provider = (await plex.providers.add(url: 'https://x')).single;
      expect(
        (provider.identifier, provider.title),
        ('com.plexapp.plugins.library', 'Library'),
      );
      expect(provider.types, ['video', 'audio', 'photo']);
      expect(provider.protocols, ['stream', 'download']);
      expect(
        provider.features.map((f) => (f.type, f.key, f.flavor)),
        containsAll([
          ('content', '/library/sections', null),
          ('playlist', '/playlists', 'universal'),
        ]),
      );
      expect(provider.features.first.raw['type'], provider.features.first.type);
    });

    test('providers: the older Provider key, and none', () async {
      answer({
        'MediaContainer': {
          'Provider': [
            {
              'identifier': 'tv.plex.provider.x',
              'title': 'X',
              'Feature': [<String, Object?>{}],
            },
          ],
        },
      });
      final provider = (await plex.providers.list()).single;
      expect(provider.identifier, 'tv.plex.provider.x');
      expect(provider.types, isEmpty);
      expect(provider.protocols, isEmpty);
      final feature = provider.features.single;
      expect((feature.type, feature.key, feature.flavor), ('', null, null));
      answer({
        'MediaContainer': {'size': 0},
      });
      expect(await plex.providers.add(url: 'https://x'), isEmpty);
    });

    test('downloadQueue.itemDecision reads the decision codes', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'generalDecisionCode': 1001,
          'generalDecisionText': 'Direct play OK.',
          'directPlayDecisionCode': 1000,
          'directPlayDecisionText': 'Direct play OK.',
          'Metadata': [
            {'ratingKey': '3', 'type': 'track'},
          ],
        },
      });
      final d = await plex.downloadQueue.itemDecision(queueId: 2, itemId: 7);
      expect(
        (d.code, d.isPlayable, d.isDirect, d.isTranscode),
        (1001, true, true, false),
      );
      expect(d.raw['generalDecisionText'], 'Direct play OK.');
    });

    test('downloadQueue.itemDecision: a transcode, a refusal, and an '
        'answer without a decision', () async {
      answer({
        'MediaContainer': {
          'generalDecisionCode': 1001,
          'directPlayDecisionCode': 3000,
          'transcodeDecisionCode': 1001,
        },
      });
      var d = await plex.downloadQueue.itemDecision(queueId: 2, itemId: 7);
      expect((d.isPlayable, d.isDirect, d.isTranscode), (true, false, true));
      answer({
        'MediaContainer': {'generalDecisionCode': 2000},
      });
      d = await plex.downloadQueue.itemDecision(queueId: 2, itemId: 7);
      expect(
        (d.code, d.isPlayable, d.isDirect, d.isTranscode),
        (2000, false, false, false),
      );
      answer({
        'MediaContainer': {'size': 0},
      });
      d = await plex.downloadQueue.itemDecision(queueId: 2, itemId: 7);
      expect((d.code, d.isPlayable), (null, false));
    });

    test('playlists.generators reads PlexPlayQueueGenerator in full', () async {
      answer({
        'MediaContainer': {
          'size': 2,
          'PlayQueueGenerator': [
            {
              'id': 4,
              'playlistID': 20,
              'type': 42,
              'uri': '$_libraryUri/3',
              'createdAt': 1700000000,
              'updatedAt': '1700000060',
              'changedAt': 1700000120,
            },
            {'playlistID': '21'},
          ],
        },
      });
      final generators = await plex.playlists.generators(playlistId: '20');
      final first = generators.first;
      expect((first.id, first.playlistId, first.type), (4, 20, 42));
      expect(first.uri, '$_libraryUri/3');
      expect(first.createdAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect(first.updatedAt, DateTime.utc(2023, 11, 14, 22, 14, 20));
      expect(first.changedAt, DateTime.utc(2023, 11, 14, 22, 15, 20));
      expect(first.raw['type'], 42);
      final bare = generators.last;
      expect(
        (bare.id, bare.playlistId, bare.type, bare.uri),
        (0, 21, null, null),
      );
      expect(
        (bare.createdAt, bare.updatedAt, bare.changedAt),
        (null, null, null),
      );
    });

    test('PlexSecurityResource: a single Device object, a list, or the '
        'container itself', () {
      const device = {
        'name': 'Server',
        'clientIdentifier': _serverId,
        'accessToken': 'transient',
        'Connection': [
          {
            'protocol': 'https',
            'address': '192.0.2.10',
            'port': 32400,
            'uri': 'https://192-0-2-10.x.plex.direct:32400',
            'local': true,
          },
        ],
      };
      for (final json in [
        {
          'MediaContainer': {'Device': device},
        },
        {
          'MediaContainer': {
            'Device': [device, <String, Object?>{}],
          },
        },
        {'MediaContainer': device},
        device,
      ]) {
        final r = PlexSecurityResource.fromJson(json);
        expect(
          (r.name, r.clientIdentifier, r.accessToken),
          ('Server', _serverId, 'transient'),
        );
        final c = r.connections.single;
        expect(
          (c.protocol, c.address, c.port, c.local),
          ('https', '192.0.2.10', 32400, true),
        );
        expect(c.uri, 'https://192-0-2-10.x.plex.direct:32400');
      }
    });

    test('PlexSecurityResource of a source the server does not know is '
        'empty (PMS 1.43.2 answers {"MediaContainer":{"size":0}})', () async {
      answer({
        'MediaContainer': {'size': 0},
      });
      final r = await plex.server.securityResources(
        source: 'server://x/com.plexapp.plugins.library',
        refresh: true,
      );
      expect(adapter.last!.uri.path, '/security/resources');
      expect(adapter.last!.queryParameters, {
        'source': 'server://x/com.plexapp.plugins.library',
        'refresh': '1',
      });
      expect((r.name, r.clientIdentifier, r.accessToken), (null, null, null));
      expect(r.connections, isEmpty);
    });
  });

  test('collections.compositeImageUrl points at the cover and its '
      'version', () {
    final url = testClient(
      CapturingAdapter(),
    ).collections.compositeImageUrl(collectionId: '914', updatedAt: 1794079152);
    expect(Uri.parse(url).origin, 'http://192.168.1.10:32400');
    expect(pathAndToken(url), (
      '/library/collections/914/composite/1794079152',
      'tok',
    ));
  });
}
