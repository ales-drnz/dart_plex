// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The one builder of signed URLs and the encoding of path segments.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:dart_plex/src/plex_connection.dart';
import 'package:dart_plex/src/plex_urls.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

void main() {
  group('signedUrl', () {
    late PlexConnection http;

    setUp(() => http = testConnection(CapturingAdapter())..token = 'to k&n');

    test('path, query and the token last, all form-encoded', () {
      final url = http.signedUrl('/photo/:/transcode', {
        'url': '/library/metadata/1/thumb/2',
        'width': 300,
        'absent': null,
      });
      expect(
        url,
        'http://192.168.1.10:32400/photo/:/transcode'
        '?url=%2Flibrary%2Fmetadata%2F1%2Fthumb%2F2&width=300'
        '&X-Plex-Token=to+k%26n',
      );
      expect(Uri.parse(url).queryParameters['X-Plex-Token'], 'to k&n');
    });

    test('no token, no X-Plex-Token; no query, no question mark', () {
      http.token = null;
      expect(http.signedUrl('/a/b'), 'http://192.168.1.10:32400/a/b');
      http.token = '';
      expect(http.signedUrl('/a/b'), 'http://192.168.1.10:32400/a/b');
    });

    test('a query that names the token keeps its own, once', () {
      final url = http.signedUrl('/a', {'X-Plex-Token': 'other', 'b': 1});
      expect(url, 'http://192.168.1.10:32400/a?X-Plex-Token=other&b=1');
    });

    test('before a server is set it is a state error, not "null/…"', () {
      http.baseUrl = null;
      expect(
        () => http.signedUrl('/a'),
        throwsA(
          isA<PlexException>().having(
            (e) => e.type,
            'type',
            PlexErrorType.state,
          ),
        ),
      );
    });
  });

  group('seg', () {
    test('ids and key lists pass as they are', () {
      expect(seg(42), '42');
      expect(seg('1,2,3'), '1,2,3');
      expect(seg('com.plexapp.agents.none'), 'com.plexapp.agents.none');
      expect(seg('tv.plex.provider.epg:1'), 'tv.plex.provider.epg:1');
    });

    test('what would name another route is encoded', () {
      expect(seg('1/../2'), '1%2F..%2F2');
      expect(seg('1?x=y#z'), '1%3Fx=y%23z');
      expect(seg('a b'), 'a%20b');
      expect(seg('50%'), '50%25');
      expect(seg(r'a\b'), 'a%5Cb');
      expect(
        PlexConnection.buildUri(
          'http://h/library/metadata/${seg('1/../2')}',
          null,
        ).pathSegments,
        ['library', 'metadata', '1/../2'],
      );
    });

    test('an empty id, "." and ".." are refused', () {
      for (final bad in ['', '.', '..']) {
        expect(() => seg(bad), throwsArgumentError, reason: '"$bad"');
      }
    });
  });
}
