// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:io';

import 'package:yaml/yaml.dart';

/// Compute approximate static coverage of the pinned Plex spec by
/// the library's typed wrappers. Returns `(matched, total)` where
/// `matched` is the count of spec paths whose canonical form appears
/// somewhere in a `lib/src/api/*.dart` string literal or dartdoc.
///
/// This is INFORMATIONAL, not a strict conformance check. The real
/// correctness guarantee comes from the integration tests in
/// `test/integration/`, which exercise the library against a real
/// Plex Media Server running in Docker.
({int matched, int total}) computePlexLocalCoverage() {
  final specRaw = File('docs/plex-api-spec.yaml').readAsStringSync();
  final spec = loadYaml(specRaw);
  if (spec is! Map) return (matched: 0, total: 0);
  final paths = spec['paths'];
  if (paths is! Map) return (matched: 0, total: 0);

  final specPaths = <String>{};
  paths.forEach((path, ops) {
    if (path is! String || ops is! Map) return;
    for (final method in ops.keys) {
      if (method is String &&
          {'get', 'post', 'put', 'delete', 'patch'}.contains(method.toLowerCase())) {
        specPaths.add(path);
      }
    }
  });

  final libCanon = _scanLibraryPaths('lib/src/api');

  var matched = 0;
  for (final p in specPaths) {
    if (libCanon.contains(_canonicalize(p))) matched++;
  }
  return (matched: matched, total: specPaths.length);
}

Set<String> _scanLibraryPaths(String dir) {
  final out = <String>{};
  final root = Directory(dir);
  if (!root.existsSync()) return out;
  final literal = RegExp(r'''['"](?:\$\w+)?(\/[^'"\n]*)['"]''');
  final docPath = RegExp(
    r'''///[^\n]*`(?:GET|POST|PUT|DELETE|PATCH)\s+(\/[^\s`]+)`''',
  );
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final content = entity.readAsStringSync();
    for (final m in literal.allMatches(content)) {
      final raw = m.group(1)!;
      if (raw.isEmpty) continue;
      out.add(_canonicalize(raw.split('?').first));
    }
    for (final m in docPath.allMatches(content)) {
      out.add(_canonicalize(m.group(1)!.split('?').first));
    }
  }
  return out;
}

String _canonicalize(String path) {
  var r = path;
  r = r.replaceAll(RegExp(r'\$\{[^}]+\}'), '<P>');
  r = r.replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), '<P>');
  r = r.replaceAll(RegExp(r'\{[^/}]+\}'), '<P>');
  r = r.replaceAll(RegExp(r'(<P>)+'), '<P>');
  return r.toLowerCase();
}
