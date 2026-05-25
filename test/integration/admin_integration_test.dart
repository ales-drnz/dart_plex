// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

@Tags(['integration'])
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_fixture.dart';

/// Smoke tests for the Plex admin surface
/// ([PlexPreferencesApi], [PlexTranscoderApi], [PlexLogApi],
/// [PlexActivitiesApi], [PlexProvidersApi], [PlexUpdaterApi],
/// [PlexDevicesApi], [PlexButlerApi], [PlexNotificationsApi]).
void main() {
  group('Plex admin APIs', () {
    late PlexClient plex;

    setUpAll(() {
      plex = plexFromCache();
    });

    test('preferences.all returns the server preference list', () async {
      final prefs = await plex.preferences.all();
      expect(prefs, isNotEmpty);
    });

    test('preferences.byId returns one preference by id', () async {
      final all = await plex.preferences.all();
      final first = all.first['id']?.toString();
      expect(first, isNotNull);
      final one = await plex.preferences.byId(first!);
      expect(one, isA<Map<String, dynamic>>());
    });

    test('log.writeMessage accepts a message without throwing', () async {
      await plex.log.writeMessage(
        message: 'dart_plex integration smoke log entry',
        level: 6, // Info.
        source: 'dart_plex_test',
      );
    });

    test('activities.list returns the activities map', () async {
      final acts = await plex.activities.list();
      expect(acts, isA<Map<String, dynamic>>());
    });

    test('providers.list returns the metadata-providers map', () async {
      final ps = await plex.providers.list();
      expect(ps, isA<Map<String, dynamic>>());
    });

    test('updater.status returns the auto-updater status', () async {
      final s = await plex.updater.status();
      expect(s, isA<Map<String, dynamic>>());
    });

    test('butler.tasks returns the scheduled-task map', () async {
      final t = await plex.butler.tasks();
      expect(t, isA<Map<String, dynamic>>());
    });

    test('notifications WebSocket: connect -> close round trip', () async {
      expect(plex.notifications.isWebSocketConnected, isFalse);
      final stream = plex.notifications.connectWebSocket();
      expect(stream, isA<Stream<PlexNotification>>());
      // Give the socket a moment to actually open.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(plex.notifications.isWebSocketConnected, isTrue);
      await plex.notifications.closeWebSocket();
      expect(plex.notifications.isWebSocketConnected, isFalse);
    });
  }, skip: bootstrapSkipReason);
}
