// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:dart_plex/src/notifications/sse_parser.dart';
import 'package:test/test.dart';

/// Feeds [chunks] to a fresh parser and returns everything it dispatched.
List<SseEvent> _parse(List<String> chunks, {SseParser? parser}) {
  final p = parser ?? SseParser();
  return [for (final chunk in chunks) ...p.add(chunk)];
}

void main() {
  group('SseParser line endings', () {
    for (final (name, eol) in [('LF', '\n'), ('CRLF', '\r\n'), ('CR', '\r')]) {
      test('$name ends lines and a blank line dispatches', () {
        final first = 'event: playing${eol}data: {"a":1}$eol$eol';
        final second = 'event: status${eol}data: {"b":2}$eol$eol';
        final events = _parse([first + second]);

        expect(events, [
          (event: 'playing', data: '{"a":1}'),
          (event: 'status', data: '{"b":2}'),
        ]);
      });

      test('$name survives a split at every offset', () {
        final text = 'event: playing${eol}data: one${eol}data: two$eol$eol';
        for (var at = 1; at < text.length; at++) {
          expect(_parse([text.substring(0, at), text.substring(at)]), [
            (event: 'playing', data: 'one\ntwo'),
          ], reason: 'split at $at');
        }
      });
    }

    test('mixed endings in one stream', () {
      final events = _parse(['data: a\r\n\ndata: b\r\rdata: c\n\r\n']);

      expect(events.map((e) => e.data), ['a', 'b', 'c']);
    });

    test('a CRLF split between two chunks is one line ending', () {
      // Read as CR then LF it would be a blank line, and dispatch early.
      final events = _parse(['data: a\r', '\ndata: b\r', '\n\r', '\n']);

      expect(events, [(event: null, data: 'a\nb')]);
    });

    test('one character per chunk', () {
      const text = 'event: x\r\ndata: y\r\n\r\n';

      expect(_parse(text.split('')), [(event: 'x', data: 'y')]);
    });
  });

  group('SseParser fields', () {
    test('comment lines are ignored', () {
      final events = _parse([': keepalive\n\n:\ndata: a\n: mid\n\n']);

      expect(events, [(event: null, data: 'a')]);
    });

    test('only one space after the colon is dropped', () {
      final events = _parse(['data:a\n\ndata:  b\n\n']);

      expect(events.map((e) => e.data), ['a', ' b']);
    });

    test('a colon inside the value is kept', () {
      expect(_parse(['data: {"a":"b:c"}\n\n']).single.data, '{"a":"b:c"}');
    });

    test('id, retry and unknown fields do not reach the event', () {
      final events = _parse(['id: 7\nretry: 100\nfoo: bar\ndata: a\n\n']);

      expect(events, [(event: null, data: 'a')]);
    });

    test('a field with no colon has an empty value', () {
      expect(_parse(['data\n\n']), [(event: null, data: '')]);
    });

    test('an event with no data is not dispatched, and its name is reset', () {
      final events = _parse(['event: orphan\n\ndata: a\n\n']);

      expect(events, [(event: null, data: 'a')]);
    });

    test('a leading byte order mark is dropped', () {
      expect(_parse(['\uFEFFdata: a\n\n']).single.data, 'a');
    });

    test('an unterminated event is held back', () {
      final parser = SseParser();

      expect(parser.add('data: a\n'), isEmpty);
      expect(parser.add('\n'), [(event: null, data: 'a')]);
    });
  });

  group('SseParser size cap', () {
    test('an oversized event is dropped and the next one is read', () {
      var overflows = 0;
      final parser = SseParser(
        maxEventLength: 64,
        onOverflow: () => overflows++,
      );

      final events = _parse([
        'data: ${'x' * 100}\n',
        'data: tail of the same event\n\n',
        'event: ok\ndata: small\n\n',
      ], parser: parser);

      expect(events, [(event: 'ok', data: 'small')]);
      expect(overflows, 1);
    });

    test('a line that never ends does not grow the buffer', () {
      var overflows = 0;
      final parser = SseParser(
        maxEventLength: 64,
        onOverflow: () => overflows++,
      );

      for (var i = 0; i < 1000; i++) {
        expect(parser.add('x' * 100), isEmpty);
      }
      expect(overflows, 1);
      // Still mid-line: the blank line is what resumes parsing.
      expect(parser.add('\n\ndata: a\n\n'), [(event: null, data: 'a')]);
    });

    test('comments and ignored fields do not count towards the cap', () {
      final parser = SseParser(maxEventLength: 32);
      final events = _parse([
        for (var i = 0; i < 20; i++) ': a long keepalive comment line\n',
        'id: ${'9' * 20}\n',
        'retry: ${'9' * 20}\n',
        'data: a\n\n',
      ], parser: parser);

      expect(events, [(event: null, data: 'a')]);
    });

    test('a large event fed in small chunks arrives whole', () {
      final payload = 'y' * 200000;
      final text = 'data: $payload\n\n';
      final chunks = [
        for (var i = 0; i < text.length; i += 1000)
          text.substring(i, (i + 1000).clamp(0, text.length)),
      ];

      expect(_parse(chunks).single.data, payload);
    });
  });
}
