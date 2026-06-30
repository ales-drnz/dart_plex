// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Integration test bootstrap for dart_plex.
///
/// Run from the library root:
///
///     dart run test/integration/bootstrap.dart
///
/// What it does (idempotent — safe to re-run any time):
/// 1. Reads `test/integration/.env.test`.
/// 2. Generates a minimal royalty-free seed library in
///    `test/integration/seed/plex/` (silence MP3s + a 5s blue video)
///    via `ffmpeg`. If `ffmpeg` is not on PATH, skips this step.
/// 3. Authenticates to plex.tv using the dedicated test account
///    in `.env.test` and checks whether the disposable Docker
///    container has already been claimed.
/// 4. If not claimed yet: requests a fresh one-shot claim token
///    from plex.tv (expires in 4 minutes), exports it as
///    `PLEX_CLAIM`, and brings up the docker-compose stack. Plex
///    consumes the token on first start and persists the resulting
///    server token in the config volume.
/// 5. Connects to the local PMS, creates a "Music" library section
///    if needed, triggers a scan, waits for it to settle.
/// 6. Writes a JSON bootstrap cache to
///    `test/integration/.bootstrap-cache.json`.
///
/// The cache file is gitignored. Tearing the stack down with
/// `docker compose down` keeps the volumes; `docker compose down -v`
/// wipes them so the next bootstrap rebuilds and re-claims from
/// scratch (a fresh claim token will be requested).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_plex/dart_plex.dart';
import 'package:http/http.dart' as http;

const String _integrationDir = 'test/integration';
const String _envFile = '$_integrationDir/.env.test';
const String _composeFile = '$_integrationDir/docker-compose.yml';
const String _seedDir = '$_integrationDir/seed/plex';
const String _cacheFile = '$_integrationDir/.bootstrap-cache.json';

Future<void> main(List<String> args) async {
  final force = args.contains('--force') || args.contains('-f');

  _section('dart_plex integration bootstrap');

  final env = _loadEnv(_envFile);
  final envUsername = env['PLEX_TEST_USERNAME'] ?? '';
  final envPassword = env['PLEX_TEST_PASSWORD'] ?? '';
  final envToken = env['PLEX_TEST_TOKEN'] ?? '';
  if ((envUsername.isEmpty || envPassword.isEmpty) && envToken.isEmpty) {
    stderr.writeln();
    stderr.writeln(
      'Plex auth is required in .env.test — either PLEX_TEST_USERNAME + '
      'PLEX_TEST_PASSWORD or PLEX_TEST_TOKEN.',
    );
    stderr.writeln();
    stderr.writeln(
      'PLEX_TEST_USERNAME is the auto-assigned plex.tv handle (NOT your '
      'email\'s local part). Find it at the top right of plex.tv after '
      'logging in.',
    );
    stderr.writeln();
    stderr.writeln(
      'For 2FA accounts run `dart run test/integration/get_plex_token.dart` '
      'and set PLEX_TEST_TOKEN instead.',
    );
    exit(2);
  }
  final hostPort = int.tryParse(env['PLEX_HOST_PORT'] ?? '') ?? 42400;
  final baseUrl = 'http://127.0.0.1:$hostPort';

  // 1. Seed media
  _step('Preparing seed media in $_seedDir/');
  await _ensureSeedMedia(_seedDir, force: force);

  // 2. plex.tv auth — sign in with username/password, or fall back
  // to a stored token if that's all .env.test has.
  const clientId = 'dart-plex-bootstrap';
  final client = PlexClient(
    credentials: PlexCredentials(
      clientIdentifier: clientId,
      product: 'dart_plex bootstrap',
      version: '0.0.1',
      device: 'bootstrap',
      deviceName: 'dart_plex bootstrap',
      platform: Platform.operatingSystem,
    ),
  );

  PlexUser user;
  if (envUsername.isNotEmpty && envPassword.isNotEmpty) {
    _step('Signing in to plex.tv as $envUsername');
    user = await client.account.signInWithPassword(
      username: envUsername,
      password: envPassword,
    );
    client.setToken(user.authToken);
  } else {
    _step('Talking to plex.tv with PLEX_TEST_TOKEN');
    client.setToken(envToken);
    user = await client.account.currentUser();
  }
  print('   ✓ plex.tv user ${user.username} (id=${user.id})');

  // Find any pre-existing claimed server with our bootstrap client
  // identifier. If found, this volume has already been claimed.
  final resources = await client.account.fetchResources();
  final existingClaim = resources.where(_isOurTestServer).firstOrNull;
  String? claimToken;
  if (existingClaim != null && !force) {
    print(
      '   ✓ Existing claimed server found '
      '(machineId=${existingClaim.clientIdentifier})',
    );
  } else {
    _step('Requesting one-shot claim token from plex.tv (expires in 4 min)');
    claimToken = await _requestClaimToken(user.authToken, clientId);
    print('   ✓ Claim token ${claimToken.substring(0, 12)}…');
  }

  // 3. Docker stack
  _step('Starting Docker stack (Plex ${env['PLEX_IMAGE_TAG'] ?? '1.41.x'})');
  await _composeUp(
    extraEnv: {
      if (claimToken != null) 'PLEX_CLAIM': claimToken,
    },
  );

  // 4. Wait for PMS to respond
  _step('Waiting for $baseUrl/identity to respond');
  await _waitForHttp('$baseUrl/identity');

  // 5. Re-fetch resources (server appears on plex.tv after claim)
  PlexResource? server;
  if (claimToken != null) {
    _step('Waiting for plex.tv to register the claimed server');
    server = await _waitForClaimedServer(client);
  } else {
    server = existingClaim!;
  }
  final conn = server.bestConnection();
  if (conn == null) {
    throw StateError('Plex server has no usable connection');
  }
  // We always talk to the container via 127.0.0.1:hostPort, not the
  // connection plex.tv discovers (which may be a LAN IP). The
  // server's accessToken is what we need though.
  client.connect(baseUrl, accessToken: server.accessToken);
  print('   ✓ Connected to ${server.name} '
      '(machineId=${server.clientIdentifier})');

  // 6. Ensure Music library
  _step('Ensuring "Music" library exists');
  final sections = await client.library.sections();
  if (sections
      .any((s) => s.title == 'Music' && s.type == PlexLibraryType.music)) {
    print('   ✓ Music library already configured');
  } else {
    print('   ▶ Adding Music library (location=/data/Music)');
    await client.library.addSection(
      name: 'Music',
      type: 'artist',
      scanner: 'Plex Music',
      agent: 'tv.plex.agents.music',
      language: 'en-US',
      locations: const ['/data/Music'],
    );
    _step('Scanning library');
    await _waitForScan(client);
  }

  // 7. Cache
  _step('Saving bootstrap cache to $_cacheFile');
  await File(_cacheFile).writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'baseUrl': baseUrl,
      'token': server.accessToken,
      'machineIdentifier': server.clientIdentifier,
      'serverName': server.name,
      'plexUserId': user.id,
      'plexUsername': user.username,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
    }),
  );

  _section('Bootstrap complete');
  print('Run integration tests with:');
  print('  dart test --tags integration');
}

// ─── Plex-specific helpers ──────────────────────────────────────────

bool _isOurTestServer(PlexResource r) {
  if (!r.owned) return false;
  if (!r.isServer) return false;
  // The dedicated test account is unlikely to own any "real" servers.
  // Match by client-identifier prefix to be extra safe in case the
  // user has another server claimed under the same account.
  return r.name.toLowerCase().contains('dart-plex-test') ||
      r.product.toLowerCase().contains('plex media server');
}

Future<String> _requestClaimToken(String authToken, String clientId) async {
  // plex.tv issues a one-shot claim token for the given account.
  // Format: `claim-xxxxxxxxxxxxxxxx`. Expires in ~4 minutes.
  final res = await http.get(
    Uri.parse('https://plex.tv/api/claim/token.json'),
    headers: {
      'Accept': 'application/json',
      'X-Plex-Token': authToken,
      'X-Plex-Client-Identifier': clientId,
    },
  ).timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw StateError(
      'plex.tv refused claim token request: HTTP ${res.statusCode} ${res.body}',
    );
  }
  final decoded = jsonDecode(res.body);
  if (decoded is Map && decoded['token'] is String) {
    return decoded['token'] as String;
  }
  throw StateError('Unexpected claim token response: ${res.body}');
}

Future<PlexResource> _waitForClaimedServer(
  PlexClient client, {
  int maxSeconds = 90,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: maxSeconds));
  while (DateTime.now().isBefore(deadline)) {
    final resources = await client.account.fetchResources();
    final hit = resources.where(_isOurTestServer).firstOrNull;
    if (hit != null) {
      print('   ✓ plex.tv knows about ${hit.name}');
      return hit;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  throw StateError(
    'plex.tv did not register the claimed server within ${maxSeconds}s. '
    'Check `docker logs dart-plex-test` for claim errors.',
  );
}

// ─── Shared steps ───────────────────────────────────────────────────

Future<void> _ensureSeedMedia(String dir, {required bool force}) async {
  final root = Directory(dir);
  if (root.existsSync() && !force) {
    final existing = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => _mediaExts.any((e) => f.path.endsWith(e)))
        .length;
    if (existing > 0) {
      print('   ✓ Seed media already present ($existing files)');
      return;
    }
  }
  await root.create(recursive: true);

  final hasFfmpeg = await _hasCommand('ffmpeg');
  if (!hasFfmpeg) {
    print('   ⚠ ffmpeg not on PATH — skipping seed generation.');
    print('     Integration tests will run against an empty library.');
    return;
  }

  final musicDir = '$dir/Music/Test Artist/Test Album';
  await Directory(musicDir).create(recursive: true);
  print('   ▶ ffmpeg: generating 3 silence MP3s');
  for (var i = 1; i <= 3; i++) {
    final path = '$musicDir/${i.toString().padLeft(2, '0')} - Track $i.mp3';
    final r = await Process.run('ffmpeg', [
      '-y',
      '-loglevel',
      'error',
      '-f',
      'lavfi',
      '-i',
      'anullsrc=channel_layout=stereo:sample_rate=44100',
      '-t',
      '3',
      '-c:a',
      'libmp3lame',
      '-b:a',
      '128k',
      '-metadata',
      'title=Track $i',
      '-metadata',
      'artist=Test Artist',
      '-metadata',
      'album=Test Album',
      '-metadata',
      'track=$i',
      '-metadata',
      'date=2020',
      path,
    ]);
    if (r.exitCode != 0) {
      print('     ✗ ffmpeg failed for $path: ${r.stderr}');
    }
  }

  final movieDir = '$dir/Movies/Test Movie (2020)';
  await Directory(movieDir).create(recursive: true);
  print('   ▶ ffmpeg: generating 5s blue video');
  final mvR = await Process.run('ffmpeg', [
    '-y',
    '-loglevel',
    'error',
    '-f',
    'lavfi',
    '-i',
    'color=c=blue:s=320x240:d=5:r=24',
    '-c:v',
    'libx264',
    '-pix_fmt',
    'yuv420p',
    '$movieDir/Test Movie (2020).mp4',
  ]);
  if (mvR.exitCode != 0) {
    print('     ✗ ffmpeg failed for movie: ${mvR.stderr}');
  }
  print('   ✓ Seed media generated');
}

Future<void> _composeUp({Map<String, String> extraEnv = const {}}) async {
  // `--wait` blocks until every service's healthcheck reports
  // healthy. The PLEX_CLAIM env var is passed via `extraEnv` (one-
  // shot, consumed by the container on first start).
  final processEnv = {
    ...Platform.environment,
    ...extraEnv,
  };
  final r = await Process.run(
    'docker',
    [
      'compose',
      '--env-file',
      _envFile,
      '-f',
      _composeFile,
      'up',
      '-d',
      '--wait',
    ],
    environment: processEnv,
    includeParentEnvironment: false,
    workingDirectory: Directory.current.path,
  );
  if (r.exitCode != 0) {
    stderr.writeln('docker compose up failed:');
    stderr.writeln(r.stdout);
    stderr.writeln(r.stderr);
    exit(1);
  }
}

Future<void> _waitForHttp(String url, {int maxSeconds = 120}) async {
  final deadline = DateTime.now().add(Duration(seconds: maxSeconds));
  while (DateTime.now().isBefore(deadline)) {
    try {
      final res = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 3),
          );
      if (res.statusCode == 200) {
        print('   ✓ Server reachable');
        return;
      }
    } catch (_) {
      // not yet — keep polling
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  throw StateError('Timed out waiting for $url after ${maxSeconds}s');
}

Future<void> _waitForScan(
  PlexClient client, {
  int maxSeconds = 60,
}) async {
  // Find the Music section we just created.
  final sections = await client.library.sections();
  final music = sections.firstWhere(
    (s) => s.title == 'Music' && s.type == PlexLibraryType.music,
  );
  final deadline = DateTime.now().add(Duration(seconds: maxSeconds));
  var lastCount = -1;
  var stableTicks = 0;
  while (DateTime.now().isBefore(deadline)) {
    final count = await client.library.countByType(
      sectionId: music.id,
      type: PlexMetadataType.track,
    );
    if (count != lastCount) {
      lastCount = count;
      stableTicks = 0;
    } else {
      stableTicks++;
    }
    if (count > 0 && stableTicks >= 3) {
      print('   ✓ Scan settled with $count tracks');
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  print('   ⚠ Scan didn\'t settle within ${maxSeconds}s — '
      'final count: $lastCount tracks');
}

// ─── Generic helpers ────────────────────────────────────────────────

const Set<String> _mediaExts = {
  '.mp3',
  '.flac',
  '.m4a',
  '.ogg',
  '.wav',
  '.aac',
  '.mp4',
  '.mkv',
  '.mov',
  '.avi',
  '.webm',
};

Map<String, String> _loadEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing $path. Copy .env.test.example to .env.test first.');
    exit(2);
  }
  final out = <String, String>{};
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq < 0) continue;
    out[line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
  }
  return out;
}

Future<bool> _hasCommand(String cmd) async {
  try {
    final probe = Platform.isWindows ? 'where' : 'which';
    final r = await Process.run(probe, [cmd]);
    return r.exitCode == 0;
  } catch (_) {
    return false;
  }
}

void _section(String title) {
  print('');
  print('━━━ $title ━━━');
  print('');
}

void _step(String msg) {
  print('▶ $msg');
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
