// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of '../plex_models.dart';

// ---------------------------------------------------------------------------
// Lyrics
// ---------------------------------------------------------------------------

/// A track's lyrics as [PlexStreamingApi.lyrics] reads them: the text as
/// the server sent it, and its lines.
///
/// Plex serves a lyrics stream as the file it found — an `.lrc` with
/// timestamps, or plain text — so [lines] are read from the LRC syntax:
/// `[mm:ss.xx]` line times (several on one line repeat it), `<mm:ss.xx>`
/// word times of enhanced LRC ([PlexLyricLine.cues]), the ID tags `ar`,
/// `ti`, `al`, `au`, `by`, `length`, `offset`, `re`, `ve` and `#`
/// ([metadata]), and `[offset:±ms]`, which is applied to every time. Any
/// other bracketed line, such as `[Chorus: Jay-Z]`, is text. Plain text
/// gives lines without times.
///
/// {@category Playback and play queues}
final class PlexLyrics {
  /// The text as decoded, unchanged.
  final String text;

  /// The lines, in time order when [isSynced], in file order otherwise.
  final List<PlexLyricLine> lines;

  /// The ID tags (`ar`, `ti`, `al`, `au`, `by`, `length`, `offset`,
  /// `re`, `ve`, `#`), lowercased keys.
  final Map<String, String> metadata;

  /// Builds lyrics from already-parsed parts.
  const PlexLyrics({
    required this.text,
    required this.lines,
    this.metadata = const {},
  });

  /// Reads [text] as LRC (plain text is LRC without times).
  factory PlexLyrics.parse(String text) {
    final metadata = <String, String>{};
    final timed = <PlexLyricLine>[];
    final untimed = <PlexLyricLine>[];
    var offset = Duration.zero;
    final stamp = RegExp(r'^\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
    final tag = RegExp(
      r'^\[(ar|ti|al|au|by|length|offset|re|ve|#):(.*)\]\s*$',
      caseSensitive: false,
    );
    for (final raw in const LineSplitter().convert(text)) {
      var line = raw.trimRight();
      final starts = <Duration>[];
      while (true) {
        final m = stamp.firstMatch(line);
        if (m == null) break;
        starts.add(_time(m[1]!, m[2]!, m[3]));
        line = line.substring(m.end);
      }
      if (starts.isEmpty) {
        final t = tag.firstMatch(line);
        if (t != null) {
          final key = t[1]!.toLowerCase();
          final value = t[2]!.trim();
          metadata[key] = value;
          if (key == 'offset') {
            offset = Duration(milliseconds: int.tryParse(value) ?? 0);
          }
          continue;
        }
        if (line.trim().isEmpty) continue;
        untimed.add(PlexLyricLine(text: line.trim()));
        continue;
      }
      final (words, cues) = _cues(line);
      for (final start in starts) {
        timed.add(PlexLyricLine(text: words, start: start, cues: cues));
      }
    }
    // LRC's offset: a positive value shows the lyrics earlier.
    Duration shift(Duration d) {
      final v = d - offset;
      return v.isNegative ? Duration.zero : v;
    }

    final lines = timed.isEmpty
        ? untimed
        : ([
            for (final l in timed)
              PlexLyricLine(
                text: l.text,
                start: shift(l.start!),
                cues: [
                  for (final c in l.cues)
                    PlexLyricCue(
                      position: c.position,
                      endPosition: c.endPosition,
                      start: shift(c.start),
                      end: c.end == null ? null : shift(c.end!),
                    ),
                ],
              ),
          ]..sort((a, b) => a.start!.compareTo(b.start!)));
    return PlexLyrics(text: text, lines: lines, metadata: metadata);
  }

  /// Whether the lines carry times.
  bool get isSynced => lines.any((l) => l.start != null);

  /// Whether some line carries word times.
  bool get hasCues => lines.any((l) => l.cues.isNotEmpty);

  /// The lines as LRC, one per line; with [enhanced], word times too.
  String toLrc({bool enhanced = false}) =>
      lines.map((l) => l.toLrcLine(enhanced: enhanced)).join('\n');

  /// The words alone, one line per line.
  String toPlainText() => lines.map((l) => l.text).join('\n');

  static Duration _time(String m, String s, String? frac) {
    final ms = frac == null
        ? 0
        : switch (frac.length) {
            1 => int.parse(frac) * 100,
            2 => int.parse(frac) * 10,
            _ => int.parse(frac.substring(0, 3)),
          };
    return Duration(
      minutes: int.parse(m),
      seconds: int.parse(s),
      milliseconds: ms,
    );
  }

  /// The text of [line] without its `<mm:ss.xx>` word times, and the
  /// cues they mark.
  static (String, List<PlexLyricCue>) _cues(String line) {
    final word = RegExp(r'<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>');
    if (!word.hasMatch(line)) return (line.trim(), const []);
    final out = StringBuffer();
    final marks = <(int, Duration)>[];
    var last = 0;
    for (final m in word.allMatches(line)) {
      out.write(line.substring(last, m.start));
      marks.add((out.length, _time(m[1]!, m[2]!, m[3])));
      last = m.end;
    }
    out.write(line.substring(last));
    final raw = out.toString();
    final text = raw.trim();
    final lead = raw.length - raw.trimLeft().length;
    int at(int i) => (i - lead).clamp(0, text.length);
    final cues = <PlexLyricCue>[];
    for (var i = 0; i < marks.length; i++) {
      final position = at(marks[i].$1);
      // A closing tag after the last word marks its end, not a word.
      if (position >= text.length) break;
      final next = i + 1 < marks.length ? marks[i + 1] : null;
      cues.add(
        PlexLyricCue(
          position: position,
          endPosition: next == null ? text.length : at(next.$1),
          start: marks[i].$2,
          end: next?.$2,
        ),
      );
    }
    return (text, cues);
  }
}

/// One line of [PlexLyrics], shaped like dart_jellyfin's
/// `JellyfinLyricLine`.
///
/// {@category Playback and play queues}
final class PlexLyricLine {
  /// When the line starts; `null` for an unsynced line.
  final Duration? start;

  /// The words.
  final String text;

  /// Word times of an enhanced LRC line; empty otherwise.
  final List<PlexLyricCue> cues;

  /// Builds a line.
  const PlexLyricLine({required this.text, this.start, this.cues = const []});

  /// The line as LRC — `[mm:ss.xx]text`, or the bare text when unsynced.
  /// With [enhanced] and [cues], each word carries its `<mm:ss.xx>` time.
  String toLrcLine({bool enhanced = false}) {
    final at = start;
    if (at == null) return text;
    if (!enhanced || cues.isEmpty) return '[${_stamp(at)}]$text';
    final out = StringBuffer('[${_stamp(at)}]');
    var consumed = 0;
    for (final cue in cues) {
      final position = cue.position.clamp(0, text.length);
      if (position < consumed) continue;
      out.write(text.substring(consumed, position));
      out.write('<${_stamp(cue.start)}>');
      consumed = position;
    }
    out.write(text.substring(consumed));
    final end = cues.last.end;
    if (end != null && cues.last.endPosition >= text.length) {
      out.write('<${_stamp(end)}>');
    }
    return out.toString();
  }

  /// `mm:ss.xx`, truncated to the centisecond.
  static String _stamp(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final centis = (d.inMilliseconds % 1000 ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$centis';
  }

  @override
  String toString() => toLrcLine(enhanced: true);
}

/// A word of an enhanced LRC [PlexLyricLine]: where it sits in the line's
/// text and when it is sung.
///
/// {@category Playback and play queues}
final class PlexLyricCue {
  /// Index in [PlexLyricLine.text] where the word starts.
  final int position;

  /// Index where the next word starts (or the end of the text); the space
  /// after a word belongs to it.
  final int endPosition;

  /// When the word starts.
  final Duration start;

  /// When the word ends: the next word's start, or the closing time after
  /// the last word. `null` for a last word without one.
  final Duration? end;

  /// Builds a cue.
  const PlexLyricCue({
    required this.position,
    required this.endPosition,
    required this.start,
    this.end,
  });
}
