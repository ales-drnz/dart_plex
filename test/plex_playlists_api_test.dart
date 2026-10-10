// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

(PlexClient, CapturingAdapter) _client() {
  final adapter = CapturingAdapter({
    'MediaContainer': {
      'size': 1,
      'Metadata': [
        {'ratingKey': '1', 'type': 'track', 'title': 'One'},
      ],
    },
  });
  final client = testClient(adapter);
  return (client, adapter);
}

void main() {
  group('playlists.items', () {
    test('without paging asks for the whole playlist', () async {
      final (client, adapter) = _client();
      final items = await client.playlists.items('42');

      expect(items, hasLength(1));
      final q = adapter.lastRequest!.uri.queryParameters;
      expect(adapter.lastRequest!.uri.path, '/playlists/42/items');
      expect(q.containsKey('X-Plex-Container-Start'), isFalse);
      expect(q.containsKey('X-Plex-Container-Size'), isFalse);
    });

    test('start and size travel as container paging', () async {
      final (client, adapter) = _client();
      await client.playlists.items('42', start: 0, size: 20);

      final q = adapter.lastRequest!.uri.queryParameters;
      expect(q['X-Plex-Container-Start'], '0');
      expect(q['X-Plex-Container-Size'], '20');
    });
  });
}
