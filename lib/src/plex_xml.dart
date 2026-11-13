// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// A small reader for the XML some plex.tv endpoints still answer
/// (`/api/home/users`, `/api/users/`, the home-user switch) whatever the
/// `Accept` header says. Not exported.
///
/// It turns a document into the shape the same data has in Plex JSON, so
/// one `fromJson` reads both: an element is a map of its attributes, its
/// children are lists under their tag name, and the root is wrapped under
/// its own tag — `<MediaContainer size="1"><User id="7"/></MediaContainer>`
/// becomes `{MediaContainer: {size: "1", User: [{id: "7"}]}}`. Values stay
/// strings (the lenient readers in `plex_json.dart` take them).
///
/// A child with text and nothing else (`<email>a@b.c</email>`, as in
/// plex.tv's legacy `<user>`) is read as an attribute of its parent would
/// be: a string under its tag name. An attribute of the same name wins
/// over any child (the legacy `<user>` carries `username` and `email` as
/// both), and the first of two such children over the second. The text of
/// an element that has attributes or children, comments, processing
/// instructions and DTDs are skipped.
library;

/// The Plex-JSON shape of [xml]. Throws a [FormatException], and nothing
/// else, when it is not well-formed enough to read.
Map<String, Object?> plexXmlToJson(String xml) {
  final reader = _Reader(xml);
  final root = reader.readDocument();
  return {root.$1: root.$2};
}

/// Whether [text] looks like an XML document rather than JSON.
bool looksLikeXml(String text) => text.trimLeft().startsWith('<');

final class _Reader {
  /// Deeper than any Plex answer; past it the document is refused rather
  /// than left to overflow the stack.
  static const _maxDepth = 64;

  final String s;
  int i = 0;

  _Reader(this.s);

  (String, Map<String, Object?>) readDocument() {
    _skipMisc(prolog: true);
    if (i >= s.length) throw FormatException('No root element', s, i);
    final (name, map, _) = _element(1);
    _skipMisc(prolog: false);
    if (i < s.length) throw FormatException('Content after the root', s, i);
    return (name, map ?? <String, Object?>{});
  }

  /// Skips what may surround the root: white space, comments and
  /// processing instructions, and before it ([prolog]) a byte-order mark
  /// and a DTD. Stops at anything else.
  void _skipMisc({required bool prolog}) {
    if (prolog && s.startsWith('﻿', i)) i++;
    while (i < s.length) {
      if (s.startsWith('<?', i)) {
        i = _after('?>');
      } else if (s.startsWith('<!--', i)) {
        i = _after('-->');
      } else if (prolog && s.startsWith('<!DOCTYPE', i)) {
        // An internal subset (`[ … ]`) holds declarations with their own >.
        final gt = _after('>');
        final subset = s.indexOf('[', i);
        i = subset >= 0 && subset < gt ? _after(']>') : gt;
      } else if (_isSpace(s.codeUnitAt(i))) {
        i++;
      } else {
        return;
      }
    }
  }

  int _after(String end) {
    final at = s.indexOf(end, i);
    if (at < 0) throw FormatException('Unterminated markup', s, i);
    return at + end.length;
  }

  /// The element at [i]: its name and its map — or, when it has text and
  /// neither attributes nor children, no map and that text.
  (String, Map<String, Object?>?, String) _element(int depth) {
    if (depth > _maxDepth) {
      throw FormatException('Nested deeper than $_maxDepth elements', s, i);
    }
    if (s[i] != '<') throw FormatException('Expected an element', s, i);
    i++; // <
    final name = _name();
    final map = <String, Object?>{};
    while (true) {
      _spaces();
      if (i >= s.length) throw FormatException('Unterminated tag', s, i);
      if (s.startsWith('/>', i)) {
        i += 2;
        return (name, map, '');
      }
      if (s[i] == '>') {
        i++;
        break;
      }
      final attr = _name();
      _spaces();
      if (i >= s.length || s[i] != '=') {
        throw FormatException('Expected = after $attr', s, i);
      }
      i++;
      _spaces();
      if (i >= s.length) throw FormatException('Expected a value', s, i);
      final quote = s[i];
      if (quote != '"' && quote != "'") {
        throw FormatException('Expected a quoted value', s, i);
      }
      final end = s.indexOf(quote, i + 1);
      if (end < 0) throw FormatException('Unterminated value', s, i);
      if (map.containsKey(attr)) {
        throw FormatException('Duplicate attribute $attr', s, i);
      }
      map[attr] = _unescape(s.substring(i + 1, end));
      i = end + 1;
    }
    // Content: children and text, up to the closing tag. The text counts
    // only while the element has nothing else.
    var textOnly = map.isEmpty;
    final text = StringBuffer();
    while (true) {
      final lt = s.indexOf('<', i);
      if (lt < 0) throw FormatException('Missing </$name>', s, i);
      if (textOnly) text.write(_unescape(s.substring(i, lt)));
      i = lt;
      if (s.startsWith('</', i)) {
        i += 2;
        final at = i;
        if (_name() != name) throw FormatException('Expected </$name>', s, at);
        _spaces();
        if (i >= s.length || s[i] != '>') {
          throw FormatException('Unterminated </$name>', s, i);
        }
        i++;
        final value = textOnly ? text.toString().trim() : '';
        return (name, value.isEmpty ? map : null, value);
      }
      if (s.startsWith('<!--', i)) {
        i = _after('-->');
        continue;
      }
      if (s.startsWith('<?', i)) {
        i = _after('?>');
        continue;
      }
      if (s.startsWith('<![CDATA[', i)) {
        final end = _after(']]>');
        if (textOnly) text.write(s.substring(i + 9, end - 3));
        i = end;
        continue;
      }
      final (child, value, childText) = _element(depth + 1);
      textOnly = false;
      final had = map[child];
      if (value == null) {
        // Text alone: a string, unless the name is taken.
        if (had == null) map[child] = childText;
      } else if (had == null) {
        map[child] = <Object?>[value];
      } else if (had is List<Object?>) {
        had.add(value);
      }
      // Otherwise an attribute, or a text child, has the name and keeps it.
    }
  }

  String _name() {
    final start = i;
    while (i < s.length && !_isEnd(s.codeUnitAt(i))) {
      i++;
    }
    if (i == start) throw FormatException('Expected a name', s, i);
    return s.substring(start, i);
  }

  static bool _isSpace(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

  // White space and > / = <, none of which a name holds.
  static bool _isEnd(int c) =>
      _isSpace(c) || c == 0x3E || c == 0x2F || c == 0x3D || c == 0x3C;

  void _spaces() {
    while (i < s.length && _isSpace(s.codeUnitAt(i))) {
      i++;
    }
  }

  static String _unescape(String v) {
    if (!v.contains('&')) return v;
    return v.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|\w+);'), (m) {
      final e = m[1]!;
      if (e.startsWith('#')) {
        final code = e.startsWith('#x')
            ? int.tryParse(e.substring(2), radix: 16)
            : int.tryParse(e.substring(1));
        if (code == null || code < 0 || code > 0x10FFFF) {
          throw FormatException('Bad character reference ${m[0]}', v);
        }
        return String.fromCharCode(code);
      }
      return switch (e) {
        'amp' => '&',
        'lt' => '<',
        'gt' => '>',
        'quot' => '"',
        'apos' => "'",
        _ => m[0]!,
      };
    });
  }
}
