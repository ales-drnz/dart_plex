// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Subscriptions on the wire: their map parameters nest as `key[sub]`,
/// and their typed answers.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

void main() {
  test('create sends hints, prefs and params as key[sub]=value', () async {
    final adapter = CapturingAdapter();
    await testClient(adapter).subscriptions.create(
      targetLibrarySectionID: 3,
      hints: {'title': 'A & B'},
      prefs: {'minVideoQuality': 720, 'oneShot': true},
      params: {'mediaProviderID': '1'},
    );
    expect(adapter.last!.uri.query, contains('hints%5Btitle%5D=A+%26+B'));
    expect(adapter.last!.queryParameters, {
      'targetLibrarySectionID': '3',
      'hints[title]': 'A & B',
      'prefs[minVideoQuality]': '720',
      'prefs[oneShot]': 'true',
      'params[mediaProviderID]': '1',
    });
  });

  test('editPreferences sends prefs[key]=value', () async {
    final adapter = CapturingAdapter();
    await testClient(adapter).subscriptions.editPreferences(
      subscriptionId: '9',
      prefs: {'lineupChannel': '4.1'},
    );
    expect(adapter.last!.method, 'PUT');
    expect(adapter.last!.queryParameters, {'prefs[lineupChannel]': '4.1'});
  });

  group('typed answers', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    test('subscriptions and their template', () async {
      answer({
        'MediaContainer': {
          'SubscriptionTemplate': [
            {
              'MediaSubscription': [
                {
                  'title': 'Show',
                  'type': 2,
                  'airingsType': 'New Airings Only',
                  'Setting': [
                    {'id': 'minVideoQuality', 'value': 0},
                  ],
                  'MediaGrabOperation': [
                    {'id': 'g1', 'status': 'scheduled', 'percent': 0},
                  ],
                },
              ],
            },
          ],
        },
      });
      final subs = await plex.subscriptions.template(guid: 'plex://show/1');
      expect(subs.single.airingsType, 'New Airings Only');
      expect(subs.single.grabs.single.id, 'g1');
      expect(subs.single.settings.single['id'], 'minVideoQuality');
    });
  });
}
