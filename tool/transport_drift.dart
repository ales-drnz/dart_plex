// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Fails when the transport shared by dart_plex and dart_jellyfin has
/// drifted apart: a fix applied to one library and not the other.
///
/// ```sh
/// dart run tool/transport_drift.dart [path/to/dart_plex] [path/to/dart_jellyfin]
/// ```
///
/// Both default to the sibling checkouts. Each pair of files is compared
/// after the library names are replaced by one placeholder; the known,
/// intended differences (the auth header, Jellyfin's user id, wording
/// that names a server) are listed in [_allowed] and ignored. The same
/// script lives in both repositories.
library;

import 'dart:io';

/// Files that must match line for line once the names are normalised.
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

/// How many differing lines each pair has today: the domain parts, no
/// more. A change made to one library only moves the count and fails;
/// update a number only for a difference that belongs to one server.
const _allowed = {
  'lib/src/plex_connection.dart': 95,
  'lib/src/transport/plex_cancel_token.dart': 7,
};

String _normalise(String source) => source
    .replaceAll('Jellyfin', 'X')
    .replaceAll('jellyfin', 'x')
    .replaceAll('Plex', 'X')
    .replaceAll('plex', 'x')
    .replaceAll('PMS', 'X');

Future<void> main(List<String> args) async {
  final plex = args.isNotEmpty ? args[0] : '../dart_plex';
  final jellyfin = args.length > 1 ? args[1] : '../dart_jellyfin';
  var failed = false;
  for (final MapEntry(key: p, value: j) in _pairs.entries) {
    final a = _normalise(File('$plex/$p').readAsStringSync()).split('\n');
    final b = _normalise(File('$jellyfin/$j').readAsStringSync()).split('\n');
    final diff = _diffCount(a, b);
    final allowed = _allowed[p] ?? 0;
    final ok = diff <= allowed;
    if (!ok) failed = true;
    stdout.writeln('${ok ? 'ok  ' : 'FAIL'} $p ↔ $j: '
        '$diff differing lines (allowed $allowed)');
  }
  if (failed) {
    stderr.writeln('\nThe shared transport drifted: apply the change to both '
        'libraries (diff the files above).');
    exit(1);
  }
}

/// Lines in one file and not the other, by longest common subsequence.
int _diffCount(List<String> a, List<String> b) {
  final prev = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    var diag = 0;
    for (var j = 1; j <= b.length; j++) {
      final up = prev[j];
      prev[j] = a[i - 1] == b[j - 1]
          ? diag + 1
          : (prev[j] > prev[j - 1] ? prev[j] : prev[j - 1]);
      diag = up;
    }
  }
  final common = prev[b.length];
  return (a.length - common) + (b.length - common);
}
