// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// When a wrong argument is reported: through the Future by a call that
/// returns one, at once by a URL builder.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

void main() {
  late CapturingAdapter adapter;
  late PlexClient plex;

  setUp(() {
    adapter = CapturingAdapter();
    plex = testClient(adapter);
  });

  final calls = <String, Future<Object?> Function(PlexClient)>{
    'library.item': (p) => p.library.item(ratingKey: '..'),
    'library.children': (p) => p.library.children(ratingKey: ''),
    'library.allLeaves': (p) => p.library.allLeaves(ratingKey: '.'),
    'library.grandchildren': (p) => p.library.grandchildren(ratingKey: ''),
    'library.recentlyAdded': (p) => p.library.recentlyAdded(sectionId: ''),
    'library.sectionDetails': (p) => p.library.sectionDetails(sectionId: ''),
    'library.person': (p) => p.library.person(personId: '..'),
    'library.deleteMetadataItem': (p) => p.library.deleteMetadataItem(ids: ''),
    'playlists.items': (p) => p.playlists.items(playlistId: ''),
    'playlists.generators': (p) => p.playlists.generators(playlistId: '..'),
    'devices.details': (p) => p.devices.details(deviceId: ''),
    'dvrs.get': (p) => p.dvrs.get(dvrId: ''),
    'subscriptions.get': (p) => p.subscriptions.get(subscriptionId: ''),
    'liveTv.liveSession': (p) => p.liveTv.liveSession(sessionId: ''),
    'search.section': (p) => p.search.section(
      sectionId: '',
      query: 'x',
      type: PlexMetadataType.track,
    ),
    'playQueues.addItems': (p) => p.playQueues.addItems(playQueueId: 1),
    'playback.timeline': (p) => p.playback.timeline(
      ratingKey: '1',
      playState: PlexPlayState.playing,
      timeMs: -1,
      durationMs: 1000,
    ),
  };

  for (final MapEntry(key: name, value: call) in calls.entries) {
    test('$name reports a wrong argument through its Future', () async {
      late Future<Object?> pending;
      // Calling must not throw: the error belongs to the Future.
      expect(() => pending = call(plex), returnsNormally);
      await expectLater(pending, throwsArgumentError);
      expect(adapter.requests, isEmpty);
    });
  }

  test('a URL builder throws at once', () {
    expect(
      () => plex.library.chapterImageUrl(mediaId: '..', chapter: 1),
      throwsArgumentError,
    );
    expect(
      () => plex.devices.thumbUrl(deviceId: '', version: '1'),
      throwsArgumentError,
    );
  });
}
