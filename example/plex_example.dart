// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

// Smoke-test driver for dart_plex.
//
// Run against your own Plex server with:
//
//   dart run example/plex_example.dart \
//     --username=you@example.com --password=hunter2
//
// Or skip auth if you already have a token + URL:
//
//   dart run example/plex_example.dart \
//     --baseUrl=http://192.168.0.10:32400 --token=YOUR_X_PLEX_TOKEN

import 'package:dart_plex/dart_plex.dart';

Future<void> main(List<String> args) async {
  final flags = _parseFlags(args);

  final plex = PlexClient(
    credentials: const PlexCredentials(
      clientIdentifier: 'dart_plex-example-uuid',
      product: 'dart_plex example',
      version: '0.0.1',
      device: 'CLI',
      deviceName: 'dart_plex CLI',
      platform: 'CLI',
    ),
  );

  if (flags['baseUrl'] != null && flags['token'] != null) {
    plex.setToken(flags['token']!);
    plex.connect(flags['baseUrl']!);
    print('Using pre-configured server.');
  } else if (flags['username'] != null && flags['password'] != null) {
    print('Authenticating…');
    final user = await plex.account.signInWithPassword(
      username: flags['username']!,
      password: flags['password']!,
    );
    plex.setToken(user.authToken);
    print('Hello ${user.username}.');

    print('Discovering servers…');
    final servers = await plex.account.fetchResources();
    if (servers.isEmpty) {
      print('No servers visible to this account.');
      return;
    }
    final server = servers.firstWhere(
      (s) => s.owned,
      orElse: () => servers.first,
    );
    final conn = server.bestConnection();
    if (conn == null) {
      print('Server "${server.name}" has no connection candidates.');
      return;
    }
    plex.connect(conn.uri, accessToken: server.accessToken);
    print('Connected to "${server.name}" at ${conn.uri}');
  } else {
    print('Pass either --baseUrl + --token, or --username + --password.');
    return;
  }

  print('\nServer identity:');
  print('  ${await plex.server.identity()}');

  print('\nLibraries:');
  final sections = await plex.library.sections();
  for (final s in sections) {
    print('  [${s.type.name}] ${s.title}  (key=${s.id})');
  }

  final music = sections.where((s) => s.type == PlexLibraryType.music);
  if (music.isEmpty) return;
  final lib = music.first;

  print('\nFirst 5 albums in "${lib.title}":');
  final albums = await plex.library.allByType(
    sectionId: lib.id,
    type: PlexMetadataType.album,
    size: 5,
    sort: 'titleSort:asc',
  );
  for (final a in albums.items) {
    print('  ${a.title} — ${a.parentTitle ?? '?'}');
  }
}

Map<String, String> _parseFlags(List<String> args) {
  final out = <String, String>{};
  for (final a in args) {
    if (!a.startsWith('--')) continue;
    final eq = a.indexOf('=');
    if (eq < 0) continue;
    out[a.substring(2, eq)] = a.substring(eq + 1);
  }
  return out;
}
