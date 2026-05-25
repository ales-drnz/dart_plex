// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// One-time helper that walks a contributor through obtaining a
/// plex.tv auth token via the PIN flow.
///
/// Run from the library root:
///
///     dart run test/integration/get_plex_token.dart
///
/// The script prints a 4-character code and the URL
/// <https://plex.tv/link>. You open that URL in a browser, sign in
/// to the dedicated test account, and type the code. The script
/// polls plex.tv until it sees the link, then prints the resulting
/// auth token.
///
/// Copy the printed token into `.env.test` as `PLEX_TEST_TOKEN=...`.
/// The token survives until you revoke it (or until you sign out
/// from the test account at <https://plex.tv/devices>).
library;

import 'dart:io';

import 'package:dart_plex/dart_plex.dart';

Future<void> main() async {
  final client = PlexClient(
    credentials: const PlexCredentials(
      clientIdentifier: 'dart-plex-bootstrap',
      product: 'dart_plex bootstrap',
      version: '0.0.1',
      device: 'bootstrap',
      deviceName: 'dart_plex bootstrap',
      platform: 'Test',
    ),
  );

  print('');
  print('━━━ Plex token helper ━━━');
  print('');
  print('Requesting a one-shot PIN from plex.tv …');
  // `strong: false` asks for the classic 4-character PIN code.
  // `strong: true` would return a long opaque identifier (JWT-grade)
  // which is harder for a human to type at plex.tv/link.
  final pin = await client.account.createPin(strong: false);
  print('');
  print('  Code:   ${pin.code}');
  print('  Expires: ${pin.expiresAt.toLocal()}');
  print('');
  print('  1. Open https://plex.tv/link in a browser');
  print('  2. Sign in to the DEDICATED TEST ACCOUNT (not your real one)');
  print('  3. Enter the code: ${pin.code}');
  print('');
  print('Polling … (Ctrl-C to abort)');

  while (DateTime.now().isBefore(pin.expiresAt)) {
    await Future<void>.delayed(const Duration(seconds: 3));
    final current = await client.account.pollPin(pin.id);
    if (current.isAuthenticated) {
      print('');
      print('━━━ Token issued ━━━');
      print('');
      print('  PLEX_TEST_TOKEN=${current.authToken}');
      print('');
      print('Copy that line into test/integration/.env.test (gitignored).');
      print('Then run: dart run test/integration/bootstrap.dart');
      print('');
      return;
    }
    stdout.write('.');
  }
  stderr.writeln('');
  stderr.writeln('PIN expired. Re-run the helper to get a fresh code.');
  exit(1);
}
