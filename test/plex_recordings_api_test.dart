// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Recording subscriptions beyond their map parameters (those are in
/// `plex_subscriptions_api_test.dart`): the plain calls, the subscription
/// and the scheduled recordings read from the answers. PMS 1.43.2 without
/// a Plex Pass answers these 401, so the shapes follow the pinned API
/// document.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/wire_calls.dart';

const _subscription = {
  'key': '/media/subscriptions/9',
  'title': 'News',
  'type': 2,
  'airingsType': 'New Airings Only',
  'createdAt': 1700000000,
  'targetLibrarySectionID': 3,
  'targetSectionLocationID': 7,
  'librarySectionTitle': 'TV Shows',
  'locationPath': '/data/TV',
  'durationTotal': 3600000,
  'storageTotal': 123456789,
  'Directory': {'ratingKey': '77', 'type': 'show', 'title': 'News'},
  'Setting': [
    {'id': 'minVideoQuality', 'value': 720},
  ],
  'MediaGrabOperation': [
    {
      'id': 'g1',
      'key': '/media/grabbers/operations/g1',
      'status': 'inprogress',
      'percent': 42.5,
      'currentSize': 1048576,
      'grabberIdentifier': 'tv.plex.grabbers.hdhomerun',
      'grabberProtocol': 'livetv',
      'mediaSubscriptionID': 9,
      'provider': '/tv.plex.providers.epg.cloud:2',
      'Metadata': {
        'ratingKey': '78',
        'type': 'episode',
        'title': 'News at Nine',
        'grandparentTitle': 'News',
      },
    },
  ],
};

void main() {
  group('subscription requests', () {
    testWireCalls([
      (
        'list (default)',
        (p) => p.subscriptions.list(),
        'GET',
        '/media/subscriptions',
        {'includeGrabs': '0', 'includeStorage': '0'},
      ),
      (
        'list (grabs and storage)',
        (p) => p.subscriptions.list(includeGrabs: true, includeStorage: true),
        'GET',
        '/media/subscriptions',
        {'includeGrabs': '1', 'includeStorage': '1'},
      ),
      (
        'get (default)',
        (p) => p.subscriptions.get(subscriptionId: '9'),
        'GET',
        '/media/subscriptions/9',
        {'includeGrabs': '0', 'includeStorage': '0'},
      ),
      (
        'get (grabs only)',
        (p) => p.subscriptions.get(subscriptionId: '9', includeGrabs: true),
        'GET',
        '/media/subscriptions/9',
        {'includeGrabs': '1', 'includeStorage': '0'},
      ),
      (
        'create (the section only)',
        (p) => p.subscriptions.create(targetLibrarySectionID: 3),
        'POST',
        '/media/subscriptions',
        {'targetLibrarySectionID': '3'},
      ),
      (
        'create (location and type)',
        (p) => p.subscriptions.create(
          targetLibrarySectionID: 3,
          targetSectionLocationID: 7,
          type: 2,
        ),
        'POST',
        '/media/subscriptions',
        {
          'targetLibrarySectionID': '3',
          'targetSectionLocationID': '7',
          'type': '2',
        },
      ),
      (
        'editPreferences (nothing to set)',
        (p) => p.subscriptions.editPreferences(subscriptionId: '9'),
        'PUT',
        '/media/subscriptions/9',
        {},
      ),
      (
        'delete',
        (p) => p.subscriptions.delete(subscriptionId: '9'),
        'DELETE',
        '/media/subscriptions/9',
        {},
      ),
      (
        'processAll',
        (p) => p.subscriptions.processAll(),
        'POST',
        '/media/subscriptions/process',
        {},
      ),
      (
        'scheduledRecordings',
        (p) => p.subscriptions.scheduledRecordings(),
        'GET',
        '/media/subscriptions/scheduled',
        {},
      ),
      (
        'reorder (to the top)',
        (p) => p.subscriptions.reorder(subscriptionId: '9'),
        'PUT',
        '/media/subscriptions/9/move',
        {},
      ),
      (
        'reorder (after another)',
        (p) => p.subscriptions.reorder(subscriptionId: '9', after: '4'),
        'PUT',
        '/media/subscriptions/9/move',
        {'after': '4'},
      ),
      (
        'cancelGrab',
        (p) => p.subscriptions.cancelGrab(operationId: 'g1'),
        'DELETE',
        '/media/grabbers/operations/g1',
        {},
      ),
      (
        'template',
        (p) => p.subscriptions.template(guid: 'plex://show/5d9c086c?a=1&b=2'),
        'GET',
        '/media/subscriptions/template',
        {'guid': 'plex://show/5d9c086c?a=1&b=2'},
      ),
    ]);
  });

  group('answers', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    void expectSubscription(PlexMediaSubscription s) {
      expect(
        (s.key, s.title, s.type, s.airingsType),
        ('/media/subscriptions/9', 'News', 2, 'New Airings Only'),
      );
      expect(s.createdAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect((s.targetLibrarySectionId, s.targetSectionLocationId), (3, 7));
      expect((s.librarySectionTitle, s.locationPath), ('TV Shows', '/data/TV'));
      expect((s.durationTotal, s.storageTotal), (3600000, 123456789));
      expect((s.item!.ratingKey, s.item!.type), ('77', PlexMetadataType.show));
      expect(s.settings.single, {'id': 'minVideoQuality', 'value': 720});
      final grab = s.grabs.single;
      expect(
        (grab.id, grab.key, grab.status),
        ('g1', '/media/grabbers/operations/g1', 'inprogress'),
      );
      expect((grab.percent, grab.currentSize), (42.5, 1048576));
      expect(
        (grab.grabberIdentifier, grab.grabberProtocol),
        ('tv.plex.grabbers.hdhomerun', 'livetv'),
      );
      expect(
        (grab.mediaSubscriptionId, grab.provider),
        (9, '/tv.plex.providers.epg.cloud:2'),
      );
      expect(
        (grab.metadata!.ratingKey, grab.metadata!.title),
        ('78', 'News at Nine'),
      );
    }

    test('list, get and create read the subscription with its grabs', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'MediaSubscription': [_subscription],
        },
      });
      expectSubscription((await plex.subscriptions.list()).single);
      expectSubscription((await plex.subscriptions.get(subscriptionId: '9'))!);
      expectSubscription(
        (await plex.subscriptions.create(targetLibrarySectionID: 3))!,
      );
    });

    test('a subscription to a single airing carries it under Video', () async {
      answer({
        'MediaContainer': {
          'MediaSubscription': [
            {
              'key': '/media/subscriptions/10',
              'type': 1,
              'Video': {'ratingKey': '90', 'type': 'movie', 'title': 'Film'},
            },
          ],
        },
      });
      final s = (await plex.subscriptions.list()).single;
      expect((s.item!.title, s.item!.type), ('Film', PlexMetadataType.movie));
      expect(s.grabs, isEmpty);
      expect(s.settings, isEmpty);
    });

    test('get and create are null, list is empty, when the answer holds no '
        'subscription', () async {
      answer({
        'MediaContainer': {'size': 0},
      });
      expect(await plex.subscriptions.list(), isEmpty);
      expect(await plex.subscriptions.get(subscriptionId: '9'), isNull);
      expect(
        await plex.subscriptions.create(targetLibrarySectionID: 3),
        isNull,
      );
      expect(await plex.subscriptions.scheduledRecordings(), isEmpty);
      expect(await plex.subscriptions.template(guid: 'g'), isEmpty);
    });

    test('scheduledRecordings reads the grab operations', () async {
      answer({
        'MediaContainer': {
          'size': 2,
          'MediaGrabOperation': [
            {
              'id': 'g2',
              'status': 'scheduled',
              'percent': '0',
              'mediaSubscriptionID': '9',
              'Metadata': {'ratingKey': '80', 'type': 'episode', 'title': 'E'},
            },
            {'id': 'g3', 'status': 'error'},
          ],
        },
      });
      final grabs = await plex.subscriptions.scheduledRecordings();
      expect(
        grabs.map((g) => (g.id, g.status, g.percent, g.mediaSubscriptionId)),
        [('g2', 'scheduled', 0.0, 9), ('g3', 'error', null, null)],
      );
      expect(grabs.first.metadata!.type, PlexMetadataType.episode);
      expect(grabs.last.metadata, isNull);
      expect(grabs.last.raw, {'id': 'g3', 'status': 'error'});
    });

    test('without a Plex Pass the server refuses (PMS 1.43.2 answers '
        '401 with an HTML body)', () async {
      adapter.respond = (_) => CannedResponse(
        401,
        '<html><head><title>Unauthorized</title></head></html>'.codeUnits,
        contentType: 'text/html',
      );
      await expectLater(
        plex.subscriptions.list(),
        throwsA(
          isA<PlexException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      await expectLater(
        plex.subscriptions.scheduledRecordings(),
        throwsA(
          isA<PlexException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });
}
