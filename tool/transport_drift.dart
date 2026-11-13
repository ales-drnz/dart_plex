// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Fails when the transport shared by dart_plex and dart_jellyfin has
/// drifted apart: a fix applied to one library and not the other.
///
/// ```sh
/// dart run tool/transport_drift.dart [path/to/dart_plex] [path/to/dart_jellyfin]
/// dart run tool/transport_drift.dart --update [plex] [jellyfin]
/// ```
///
/// Both default to the sibling checkouts. Each pair of files is compared
/// after the library names are replaced by one placeholder, and the lines
/// that still differ — the domain parts: the auth header, Jellyfin's user
/// id, the plex.tv token renewal, wording that names a server — must be
/// exactly the ones recorded in `tool/transport_drift.expected`. A change
/// made to one library only shows up as lines the record does not have,
/// and fails; so does a change that removes a recorded difference.
///
/// After a change that belongs to one server, or one applied to both
/// that moves a recorded line, read the report and run with `--update`.
/// The same script and the same record live in both repositories.
library;

import 'dart:io';

/// Files compared line for line once the names are normalised.
const _pairs = {
  'lib/src/plex_connection.dart': 'lib/src/jellyfin_connection.dart',
  'lib/src/plex_download.dart': 'lib/src/jellyfin_download.dart',
  'lib/src/transport/plex_cancel_token.dart':
      'lib/src/transport/jellyfin_cancel_token.dart',
  'lib/src/transport/plex_response.dart':
      'lib/src/transport/jellyfin_response.dart',
  'lib/src/transport/plex_retry_policy.dart':
      'lib/src/transport/jellyfin_retry_policy.dart',
  'lib/src/transport/platform_io.dart': 'lib/src/transport/platform_io.dart',
  'lib/src/transport/platform_web.dart': 'lib/src/transport/platform_web.dart',
  'lib/io.dart': 'lib/io.dart',
};

String _normalise(String source) => source
    .replaceAll('Jellyfin', 'X')
    .replaceAll('jellyfin', 'x')
    .replaceAll('Plex', 'X')
    .replaceAll('plex', 'x')
    .replaceAll('PMS', 'X');

Future<void> main(List<String> args) async {
  final update = args.contains('--update');
  final paths = args.where((a) => a != '--update').toList();
  final plex = paths.isNotEmpty ? paths[0] : '../dart_plex';
  final jellyfin = paths.length > 1 ? paths[1] : '../dart_jellyfin';
  final record = File.fromUri(
    Platform.script.resolve('transport_drift.expected'),
  );

  final actual = <String, List<String>>{};
  for (final MapEntry(key: p, value: j) in _pairs.entries) {
    final a = _normalise(File('$plex/$p').readAsStringSync()).split('\n');
    final b = _normalise(File('$jellyfin/$j').readAsStringSync()).split('\n');
    actual['$p ↔ $j'] = _diff(a, b);
  }

  if (update) {
    record.writeAsStringSync(_write(actual));
    stdout.writeln('Recorded ${record.path}');
    return;
  }

  final expected = record.existsSync()
      ? _read(record.readAsStringSync())
      : const <String, List<String>>{};
  var failed = false;
  for (final MapEntry(key: pair, value: lines) in actual.entries) {
    final recorded = expected[pair] ?? const <String>[];
    final extra = _minus(lines, recorded);
    final missing = _minus(recorded, lines);
    final ok = extra.isEmpty && missing.isEmpty;
    if (!ok) failed = true;
    stdout.writeln(
      '${ok ? 'ok  ' : 'FAIL'} $pair: ${lines.length} differing lines',
    );
    for (final l in extra) {
      stdout.writeln('       not recorded: $l');
    }
    for (final l in missing) {
      stdout.writeln('       recorded, gone: $l');
    }
  }
  if (failed) {
    stderr.writeln(
      '\nThe shared transport drifted: apply the change to both '
      'libraries, or, for a difference that belongs to one server, '
      'record it with --update (in both repositories).\n'
      'Lines start with "-" in dart_plex only, "+" in dart_jellyfin only.',
    );
    exit(1);
  }
}

/// The lines of [a] not in [b] (`- line`) and of [b] not in [a]
/// (`+ line`), in file order, by longest common subsequence.
List<String> _diff(List<String> a, List<String> b) {
  final n = a.length;
  final m = b.length;
  final lcs = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j]
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }
  final out = <String>[];
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      out.add('- ${a[i++]}');
    } else {
      out.add('+ ${b[j++]}');
    }
  }
  while (i < n) {
    out.add('- ${a[i++]}');
  }
  while (j < m) {
    out.add('+ ${b[j++]}');
  }
  return out;
}

/// The entries of [a] that [b] does not have, counting repeats.
List<String> _minus(List<String> a, List<String> b) {
  final left = <String, int>{};
  for (final l in b) {
    left[l] = (left[l] ?? 0) + 1;
  }
  final out = <String>[];
  for (final l in a) {
    final n = left[l] ?? 0;
    if (n == 0) {
      out.add(l);
    } else {
      left[l] = n - 1;
    }
  }
  return out;
}

String _write(Map<String, List<String>> diffs) {
  final out = StringBuffer(
    '# The differences between the shared transport of dart_plex and\n'
    '# dart_jellyfin, names normalised: "-" in dart_plex only, "+" in\n'
    '# dart_jellyfin only. Written by tool/transport_drift.dart --update.\n',
  );
  for (final MapEntry(key: pair, value: lines) in diffs.entries) {
    out.writeln('== $pair');
    lines.forEach(out.writeln);
  }
  return out.toString();
}

Map<String, List<String>> _read(String text) {
  final out = <String, List<String>>{};
  List<String>? current;
  for (final line in text.split('\n')) {
    if (line.startsWith('== ')) {
      current = out[line.substring(3)] = [];
    } else if (line.startsWith('- ') || line.startsWith('+ ')) {
      current?.add(line);
    }
  }
  return out;
}
