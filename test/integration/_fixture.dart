// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Shared fixture for the dart_plex integration test suite.
///
/// Each `*_integration_test.dart` file calls [plexFromCache] from
/// `setUpAll` to obtain an authenticated [PlexClient]. The
/// credentials come from `test/integration/.bootstrap-cache.json`
/// written by `bootstrap.dart`, so we don't re-claim the server for
/// every test.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_plex/dart_plex.dart';

const String _cacheFile = 'test/integration/.bootstrap-cache.json';

class PlexBootstrapCache {
  final String baseUrl;
  final String token;
  final String machineIdentifier;
  final String serverName;
  final int? plexUserId;
  final String? plexUsername;

  const PlexBootstrapCache({
    required this.baseUrl,
    required this.token,
    required this.machineIdentifier,
    required this.serverName,
    this.plexUserId,
    this.plexUsername,
  });

  factory PlexBootstrapCache.load() {
    final file = File(_cacheFile);
    if (!file.existsSync()) {
      throw StateError(
        'Bootstrap cache missing at $_cacheFile. '
        'Run `dart run test/integration/bootstrap.dart` first.',
      );
    }
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return PlexBootstrapCache(
      baseUrl: json['baseUrl'] as String,
      token: json['token'] as String,
      machineIdentifier: json['machineIdentifier'] as String,
      serverName: json['serverName'] as String,
      plexUserId: json['plexUserId'] as int?,
      plexUsername: json['plexUsername'] as String?,
    );
  }
}

/// Build a [PlexClient] from the bootstrap cache, connected to the
/// local Docker stack with the test server's access token already
/// set.
///
/// When the cache is missing, returns an unconfigured client — the
/// surrounding `group(skip: bootstrapSkipReason)` guards the tests
/// from running, but `setUpAll` itself still executes on a skipped
/// group, so this must not throw.
PlexClient plexFromCache() {
  final client = PlexClient(
    credentials: const PlexCredentials(
      clientIdentifier: 'dart-plex-integration-tests',
      product: 'dart_plex integration tests',
      version: '0.0.1',
      device: 'integration-tests',
      deviceName: 'dart_plex integration tests',
      platform: 'Test',
    ),
  );
  if (!File(_cacheFile).existsSync()) return client;
  final cache = PlexBootstrapCache.load();
  client.connect(cache.baseUrl, accessToken: cache.token);
  return client;
}

/// Skip reason for the integration suite when the bootstrap hasn't
/// been run yet. Pass to `group(..., skip: bootstrapSkipReason)` so
/// `dart test` shows a clear message instead of failing.
String? get bootstrapSkipReason {
  if (File(_cacheFile).existsSync()) return null;
  return 'Bootstrap cache missing at $_cacheFile. '
      'Run `dart run test/integration/bootstrap.dart` first.';
}
