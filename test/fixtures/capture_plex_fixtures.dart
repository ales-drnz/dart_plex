// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Captures real JSON responses from a running PMS into
/// `test/fixtures/captured/` so we can hand-craft committable fixtures
/// for the field-level DTO tests.
///
/// Usage:
///   1. Run `bootstrap.dart` first (so the cache is populated).
///   2. `dart run test/fixtures/capture_plex_fixtures.dart`
///
/// Output is gitignored — captured payloads carry server-local ids
/// that aren't useful in shared fixtures. The point of this script is
/// to inspect real shapes; the actual unit-test fixtures get written
/// by hand against the captured JSON.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_plex/dart_plex.dart';
import 'package:dio/dio.dart';

const _cachePath = 'test/integration/.bootstrap-cache.json';
const _outDir = 'test/fixtures/captured';

Future<void> main() async {
  if (!File(_cachePath).existsSync()) {
    stderr.writeln(
      'Bootstrap cache missing — run `dart run test/integration/bootstrap.dart` first.',
    );
    exit(1);
  }
  final cache = jsonDecode(File(_cachePath).readAsStringSync())
      as Map<String, dynamic>;
  final baseUrl = cache['baseUrl'] as String;
  final token = cache['token'] as String;

  final dio = Dio()
    ..options.headers['Accept'] = 'application/json'
    ..options.headers['X-Plex-Token'] = token;

  Directory(_outDir).createSync(recursive: true);

  Future<void> get(String name, String path,
      [Map<String, dynamic>? qp]) async {
    try {
      final res = await dio.get<dynamic>('$baseUrl$path', queryParameters: qp);
      _save(name, res.data);
    } on DioException catch (e) {
      stderr.writeln('  ✗ $name ($path) — ${e.response?.statusCode}');
    }
  }

  await get('sections.json', '/library/sections');
  await get('section_music_all.json', '/library/sections/1/all',
      {'type': 10, 'X-Plex-Container-Size': 3});
  // Section 1 is Music (we just created it in bootstrap). type=10 = track.

  final tracksRes = await dio.get<Map<String, dynamic>>(
    '$baseUrl/library/sections/1/all',
    queryParameters: {'type': 10, 'X-Plex-Container-Size': 1},
  );
  final firstTrack = ((tracksRes.data?['MediaContainer'] as Map?)?['Metadata']
      as List?)?.first as Map<String, dynamic>?;
  if (firstTrack != null) {
    final rk = firstTrack['ratingKey'] as String;
    await get('metadata_track.json', '/library/metadata/$rk');
    await get('metadata_track_children.json', '/library/metadata/$rk/children');
  }

  await get('sessions.json', '/status/sessions');
  await get('hubs_global.json', '/hubs', {'count': 3});
  await get('hubs_search.json', '/hubs/search',
      {'query': 'Track', 'limit': 3});
  await get('preferences.json', '/:/prefs');
  await get('account.json', '/myplex/account');
  await get('butler_tasks.json', '/butler');
  await get('updater_status.json', '/updater/status');
  await get('activities.json', '/activities');
  await get('providers.json', '/media/providers');

  // Create a tiny playqueue via the dart_plex client (which gets the
  // URI encoding right) and capture the raw envelope by also fetching
  // /playQueues/{id} once we know the id.
  final machineId = cache['machineIdentifier'] as String;
  if (firstTrack != null) {
    final plex = PlexClient(
      credentials: const PlexCredentials(
        clientIdentifier: 'dart-plex-capture',
        product: 'capture-tool',
        version: '0.0.1',
        device: 'capture',
        deviceName: 'capture',
        platform: 'Test',
      ),
    );
    plex.connect(baseUrl, accessToken: token);
    try {
      final queue = await plex.playQueues.create(
        type: 'audio',
        uri: PlexPlayQueuesApi.seedFromItems(
          machineIdentifier: machineId,
          ratingKeys: [firstTrack['ratingKey'] as String],
        ),
      );
      await get('play_queue.json', '/playQueues/${queue.id}');
    } catch (e) {
      stderr.writeln('  ✗ play_queue.json — $e');
    }
  }

  stdout.writeln('Captured ${Directory(_outDir).listSync().length} fixtures '
      'to $_outDir/');
}

void _save(String name, dynamic data) {
  File('$_outDir/$name').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(data),
  );
  stdout.writeln('  ✓ $name');
}
