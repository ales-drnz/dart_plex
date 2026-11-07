// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The download queue against PMS 1.43.2's answers.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/fixtures.dart';

void main() {
  group('download queue (PMS 1.43.2 answers)', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    test('create and items', () async {
      answer(realFixture('download_queue'));
      final q = await plex.downloadQueue.create();
      expect(adapter.last!.method, 'POST');
      expect((q.id, q.itemCount, q.status), (1, 0, 'done'));
      answer(realFixture('download_queue_items'));
      final items = await plex.downloadQueue.items(queueId: '1');
      expect(items.single.error, 'decisionError');
      expect(items.single.decision!.code, 2004);
      expect(items.single.decision!.isPlayable, isFalse);
      expect(
        plex.downloadQueue.itemMediaUrl(queueId: '1', itemId: '2'),
        'http://192.168.1.10:32400/downloadQueue/1/item/2/media?X-Plex-Token=tok',
      );
    });

    test('an answer without a queue is a parse error', () async {
      answer({'MediaContainer': <String, Object?>{}});
      await expectLater(
        plex.downloadQueue.get(queueId: '1'),
        throwsA(
          isA<PlexException>().having(
            (e) => e.type,
            'type',
            PlexErrorType.parse,
          ),
        ),
      );
    });
  });
}
