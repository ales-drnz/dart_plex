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
/// strings (the lenient readers in `plex_json.dart` take them). Text
/// content, comments, processing instructions and DTDs are skipped.
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
  final String s;
  int i = 0;

  _Reader(this.s);

  (String, Map<String, Object?>) readDocument() {
    _skipMisc();
    if (i >= s.length || s[i] != '<') {
      throw FormatException('No root element', s, i);
    }
    return _element();
  }

  void _skipMisc() {
    while (i < s.length) {
      if (s.startsWith('<?', i)) {
        i = _after('?>');
      } else if (s.startsWith('<!--', i)) {
        i = _after('-->');
      } else if (s.startsWith('<!', i)) {
        i = _after('>');
      } else if (s[i] == '<') {
        return;
      } else {
        i++;
      }
    }
  }

  int _after(String end) {
    final at = s.indexOf(end, i);
    if (at < 0) throw FormatException('Unterminated markup', s, i);
    return at + end.length;
  }

  (String, Map<String, Object?>) _element() {
    i++; // <
    final name = _name();
    final map = <String, Object?>{};
    while (true) {
      _spaces();
      if (i >= s.length) throw FormatException('Unterminated tag', s, i);
      if (s.startsWith('/>', i)) {
        i += 2;
        return (name, map);
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
    // Content: children and text, up to the closing tag.
    while (true) {
      final lt = s.indexOf('<', i);
      if (lt < 0) throw FormatException('Missing </$name>', s, i);
      i = lt;
      if (s.startsWith('</', i)) {
        i = _after('>');
        return (name, map);
      }
      if (s.startsWith('<!--', i) || s.startsWith('<?', i)) {
        _skipMisc();
        continue;
      }
      if (s.startsWith('<![CDATA[', i)) {
        i = _after(']]>');
        continue;
      }
      final at = i;
      final (child, value) = _element();
      final list = map[child] ??= <Object?>[];
      if (list is! List<Object?>) {
        throw FormatException('<$child> clashes with an attribute', s, at);
      }
      list.add(value);
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

  static bool _isEnd(int c) =>
      c == 0x20 ||
      c == 0x09 ||
      c == 0x0A ||
      c == 0x0D || //
      c == 0x3E ||
      c == 0x2F ||
      c == 0x3D; // > / =

  void _spaces() {
    while (i < s.length && ' \t\r\n'.contains(s[i])) {
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
