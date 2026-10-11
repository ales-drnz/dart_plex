// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

/// Builds a [PlexSessionsApi] wired to a [CapturingAdapter] that returns
/// [responseBody] for every request.
({PlexSessionsApi api, CapturingAdapter adapter}) _makeApi(
  Map<String, dynamic> responseBody,
) {
  final adapter = CapturingAdapter(responseBody);
  final conn = testConnection(adapter);
  return (api: PlexSessionsApi(conn), adapter: adapter);
}

void main() {
  group('PlexSessionsApi.active', () {
    test('issues GET /status/sessions and decodes List<PlexSession>', () async {
      final ctx = _makeApi({
        'MediaContainer': {
          'size': 1,
          'Metadata': [
            {
              'ratingKey': '67890',
              'title': 'Now Playing Track',
              'type': 'track',
              'viewOffset': 5000,
              'Session': {
                'id': 'sess-1',
                'bandwidth': 1200,
              },
            },
          ],
        },
      });

      final sessions = await ctx.api.active();

      final req = ctx.adapter.lastRequest!;
      expect(req.method, 'GET');
      expect(req.path, 'http://192.168.1.10:32400/status/sessions');
      expect(sessions, isA<List<PlexSession>>());
      expect(sessions, hasLength(1));
      expect(sessions.single.sessionId, 'sess-1');
      expect(sessions.single.metadata.title, 'Now Playing Track');
    });
  });

  group('PlexSessionsApi.history', () {
    test('issues GET /status/sessions/history/all and decodes the list',
        () async {
      final ctx = _makeApi({
        'MediaContainer': {
          'size': 1,
          'Metadata': [
            {
              'historyKey': '/status/sessions/history/55',
              'ratingKey': '67890',
              'title': 'Watched Movie',
              'type': 'movie',
              'viewedAt': 1700000000,
            },
          ],
        },
      });

      final history = await ctx.api.history(size: 10);

      final req = ctx.adapter.lastRequest!;
      expect(req.method, 'GET');
      expect(req.path, 'http://192.168.1.10:32400/status/sessions/history/all');
      expect(history.items, hasLength(1));
      expect(history.items.single.title, 'Watched Movie');
    });

    test('uses inclusive viewedAt>= / viewedAt<= operators for date bounds',
        () async {
      final ctx = _makeApi(const {'MediaContainer': <String, dynamic>{}});

      await ctx.api.history(mindate: 1000, maxdate: 2000);

      final qp = ctx.adapter.lastRequest!.queryParameters;
      expect(qp['viewedAt>='], '1000');
      expect(qp['viewedAt<='], '2000');
      // The exclusive variants must not be emitted.
      expect(qp.containsKey('viewedAt>'), isFalse);
      expect(qp.containsKey('viewedAt<'), isFalse);
    });

    test('returns an empty page when the MediaContainer has no Metadata',
        () async {
      final ctx = _makeApi(const {'MediaContainer': <String, dynamic>{}});

      final history = await ctx.api.history();

      expect(history.items, isEmpty);
      expect(history.totalSize, 0);
    });
  });

  group('PlexSessionsApi.historyItem', () {
    test('issues GET /status/sessions/history/{id} and returns first entry',
        () async {
      final ctx = _makeApi({
        'MediaContainer': {
          'size': 1,
          'Metadata': [
            {
              'historyKey': '/status/sessions/history/55',
              'ratingKey': '67890',
              'title': 'Watched Movie',
              'type': 'movie',
              'viewedAt': 1700000000,
            },
            {
              'ratingKey': '99999',
              'title': 'Should Be Ignored',
              'type': 'movie',
            },
          ],
        },
      });

      final item = await ctx.api.historyItem(historyId: 55);

      final req = ctx.adapter.lastRequest!;
      expect(req.method, 'GET');
      expect(req.path, 'http://192.168.1.10:32400/status/sessions/history/55');
      expect(item, isNotNull);
      expect(item!['title'], 'Watched Movie');
    });

    test('returns null when the MediaContainer is missing', () async {
      final ctx = _makeApi(const <String, dynamic>{});

      final item = await ctx.api.historyItem(historyId: '55');

      expect(item, isNull);
    });

    test('returns null when the Metadata list is empty', () async {
      final ctx = _makeApi(const {
        'MediaContainer': {'size': 0, 'Metadata': <dynamic>[]},
      });

      final item = await ctx.api.historyItem(historyId: 55);

      expect(item, isNull);
    });
  });
}
