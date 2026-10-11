// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

void main() {
  /// A fake endpoint over [rows] that records each page it was asked for.
  (Future<List<int>> Function(int, int), List<(int, int)>) source(int rows) {
    final asked = <(int, int)>[];
    Future<List<int>> fetch(int start, int size) async {
      asked.add((start, size));
      final end = start + size > rows ? rows : start + size;
      return start >= rows ? <int>[] : [for (var i = start; i < end; i++) i];
    }

    return (fetch, asked);
  }

  test('reads until a short page', () async {
    final (fetch, asked) = source(250);
    final pages = await PlexPaging.pages(fetch).toList();
    expect(pages.map((p) => p.length), [100, 100, 50]);
    expect(asked, [(0, 100), (100, 100), (200, 100)]);
  });

  test('an exact multiple costs one empty read to learn the end', () async {
    final (fetch, asked) = source(200);
    final rows = await PlexPaging.items(fetch).toList();
    expect(rows, hasLength(200));
    expect(asked, hasLength(3));
  });

  test('limit caps rows and the last request asks for what is left', () async {
    final (fetch, asked) = source(1000);
    final rows = await PlexPaging.items(fetch, limit: 130, start: 10).toList();
    expect(rows.first, 10);
    expect(rows, hasLength(130));
    expect(asked, [(10, 100), (110, 30)]);
  });

  test('cancelling the subscription stops further requests', () async {
    final (fetch, asked) = source(1000);
    await PlexPaging.pages(fetch, pageSize: 10).take(2).toList();
    expect(asked, hasLength(2));
  });

  test('pageSize must be positive', () {
    final (fetch, _) = source(1);
    expect(
      () => PlexPaging.pages(fetch, pageSize: 0).toList(),
      throwsArgumentError,
    );
  });
}
