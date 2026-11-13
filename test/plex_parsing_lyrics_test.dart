// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The order of LRC lines that share a time.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

String _stamp(int seconds) =>
    '[${'${seconds ~/ 60}'.padLeft(2, '0')}:'
    '${'${seconds % 60}'.padLeft(2, '0')}.00]';

void main() {
  // List.sort switches from an insertion sort, which is stable, to a
  // quicksort past 32 elements: hence the sizes.
  test('lines with the same time keep the order of the file', () {
    final lrc = [
      for (var i = 0; i < 60; i++) ...[
        '${_stamp(i)}original $i',
        '${_stamp(i)}translation $i',
        '${_stamp(i)}romanised $i',
      ],
    ].join('\n');
    expect(PlexLyrics.parse(lrc).lines.map((l) => l.text), [
      for (var i = 0; i < 60; i++) ...[
        'original $i',
        'translation $i',
        'romanised $i',
      ],
    ]);
  });

  test('a hundred lines at one time', () {
    final lrc = [for (var i = 0; i < 100; i++) '[00:10.00]line $i'].join('\n');
    expect(PlexLyrics.parse(lrc).lines.map((l) => l.text), [
      for (var i = 0; i < 100; i++) 'line $i',
    ]);
  });

  test('out-of-order and repeated times are still sorted, stably', () {
    // The chorus repeats at 0:05 and 0:01; each time has a translation.
    final lrc = [
      for (var i = 0; i < 40; i++) ...[
        '[00:05.00][00:01.00]chorus $i',
        '[00:05.00][00:01.00]ritornello $i',
      ],
      '[00:03.00]verse',
    ].join('\n');
    final lines = PlexLyrics.parse(lrc).lines;
    final pairs = [
      for (var i = 0; i < 40; i++) ...['chorus $i', 'ritornello $i'],
    ];
    expect(lines.map((l) => l.text), [...pairs, 'verse', ...pairs]);
    expect(lines.first.start, const Duration(seconds: 1));
    expect(lines.last.start, const Duration(seconds: 5));
  });

  test('an offset that clamps several times to zero keeps their order', () {
    final lrc = [
      '[offset:60000]',
      for (var i = 0; i < 50; i++) '${_stamp(i)}line $i',
    ].join('\n');
    final lines = PlexLyrics.parse(lrc).lines;
    expect(lines.every((l) => l.start == Duration.zero), isTrue);
    expect(lines.map((l) => l.text), [for (var i = 0; i < 50; i++) 'line $i']);
  });
}
