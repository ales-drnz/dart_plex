// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// One dispatched Server-Sent Event.
typedef SseEvent = ({String? event, String data});

/// Incremental `text/event-stream` parser.
///
/// Follows the WHATWG framing: lines end with `\n`, `\r\n` or a lone
/// `\r`, a blank line dispatches the event, a line starting with `:` is
/// a comment, and several `data:` lines join with `\n`. Only the `event`
/// and `data` fields are kept; `id` and `retry` are ignored.
///
/// Text is consumed as it arrives and each character is looked at once,
/// however the stream is split into chunks.
final class SseParser {
  /// The most characters one event may hold before it is dropped.
  final int maxEventLength;

  /// Called for an event dropped for exceeding [maxEventLength].
  final void Function()? onOverflow;

  final _line = StringBuffer();
  final _data = StringBuffer();
  String? _event;
  bool _hasData = false;

  /// Characters held for the event being assembled.
  int _held = 0;

  /// The previous chunk ended with `\r`: a leading `\n` belongs to it.
  bool _afterCr = false;

  /// The stream has not produced a character yet (a BOM may lead it).
  bool _atStart = true;

  /// Dropping an oversized event, up to the blank line that ends it.
  bool _skipping = false;

  /// A parser that drops events longer than [maxEventLength] characters.
  SseParser({this.maxEventLength = 8 * 1024 * 1024, this.onOverflow});

  /// Feeds [chunk] and returns the events it completed, oldest first.
  List<SseEvent> add(String chunk) {
    if (chunk.isEmpty) return const [];
    final out = <SseEvent>[];
    var start = 0;
    if (_atStart) {
      _atStart = false;
      if (chunk.codeUnitAt(0) == 0xFEFF) start = 1;
    }
    if (_afterCr) {
      _afterCr = false;
      if (start < chunk.length && chunk.codeUnitAt(start) == 0x0A) start++;
    }
    for (var i = start; i < chunk.length; i++) {
      final c = chunk.codeUnitAt(i);
      if (c != 0x0A && c != 0x0D) continue;
      _hold(chunk, start, i);
      _endLine(out);
      if (c == 0x0D) {
        if (i + 1 == chunk.length) {
          _afterCr = true;
        } else if (chunk.codeUnitAt(i + 1) == 0x0A) {
          i++;
        }
      }
      start = i + 1;
    }
    _hold(chunk, start, chunk.length);
    return out;
  }

  /// Appends `chunk[start, end)` to the line being assembled.
  void _hold(String chunk, int start, int end) {
    if (end <= start) return;
    if (!_skipping) {
      _held += end - start;
      if (_held <= maxEventLength) {
        _line.write(chunk.substring(start, end));
        return;
      }
      _overflow();
    }
    // A skipped line still has to read as non-blank when it ends.
    if (_line.isEmpty) _line.write(' ');
  }

  void _overflow() {
    _skipping = true;
    _line.clear();
    _data.clear();
    _hasData = false;
    _event = null;
    _held = 0;
    onOverflow?.call();
  }

  void _endLine(List<SseEvent> out) {
    final line = _line.toString();
    _line.clear();
    if (line.isEmpty) {
      if (_hasData) out.add((event: _event, data: _data.toString()));
      _data.clear();
      _hasData = false;
      _event = null;
      _held = 0;
      _skipping = false;
      return;
    }
    if (_skipping || line.startsWith(':')) {
      if (!_skipping) _held -= line.length;
      return;
    }
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'data':
        if (_hasData) _data.write('\n');
        _data.write(value);
        _hasData = true;
      case 'event':
        _event = value;
      default:
        // `id`, `retry` and unknown fields hold nothing we keep.
        _held -= line.length;
    }
  }
}
