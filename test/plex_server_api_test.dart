// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Server-level answers: updater, providers, security resources and
/// background jobs.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/fixtures.dart';

void main() {
  group('server answers', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    test('updater status (PMS 1.43.2: checkedAt -1 is never)', () async {
      answer(realFixture('updater_status'));
      final s = await plex.updater.status();
      expect(s.canInstall, isFalse);
      expect(s.checkedAt, isNull);
      expect(s.releases, isEmpty);
    });

    test('providers (PMS 1.43.2 shape)', () async {
      answer(realFixture('providers'));
      final p = (await plex.providers.list()).single;
      expect(p.types, ['video', 'audio', 'photo']);
      expect(p.features.map((f) => f.type), ['content', 'playlist']);
    });

    test('security resources and background jobs', () async {
      answer({
        'MediaContainer': {
          'Device': {
            'name': 'srv',
            'accessToken': 't',
            'Connection': [
              {'uri': 'https://a:32400', 'local': true},
            ],
          },
        },
      });
      final r = await plex.server.securityResources(source: 'server://x');
      expect(r.accessToken, 't');
      expect(r.connections.single.local, isTrue);
      answer({
        'MediaContainer': {
          'TranscodeJob': [
            {'title': 'Movie', 'progress': 42.5, 'generatorID': 3},
          ],
        },
      });
      final jobs = await plex.server.backgroundTasks();
      expect((jobs.single.progress, jobs.single.generatorId), (42.5, 3));
    });
  });
}
