// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:dart_plex/dart_plex.dart';

Future<void> main() async {
  final plex = PlexClient(
    credentials: const PlexCredentials(
      clientIdentifier: 'example-client-id',
      product: 'MyApp',
      version: '1.0.0',
      device: 'CLI',
      deviceName: 'example',
      platform: 'macOS',
    ),
    // Opt in to resending GET/HEAD after network failures, 502/503/504/429.
    retryPolicy: const PlexRetryPolicy(),
  );

  try {
    final user = await plex.account.signInWithPassword(
      username: 'user',
      password: 'password',
    );
    plex.setToken(user.authToken);

    final resources = await plex.account.fetchResources();
    final server = resources.firstWhere((r) => r.owned && r.isServer);
    final connection = server.bestConnection();
    if (connection == null) {
      print('No reachable connection for ${server.name}');
      return;
    }
    plex.connect(connection.uri, accessToken: server.accessToken);

    final identity = await plex.server.identity();
    print('Connected to ${server.name} (PMS ${identity.version})');

    final sections = await plex.library.sections();
    for (final s in sections) {
      print('${s.title} (${s.type.name})');
    }

    final music = sections.where((s) => s.type == PlexLibraryType.music);
    if (music.isEmpty) return;

    // Walk the first 200 albums, 50 per request.
    final albums = PlexPaging.items(
      (start, size) async => (await plex.library.allByType(
        sectionId: music.first.id,
        type: PlexMetadataType.album,
        sort: 'titleSort',
        start: start,
        size: size,
      ))
          .items,
      pageSize: 50,
      limit: 200,
    );
    await for (final album in albums) {
      final count = album.leafCount ?? 0;
      print('${album.parentTitle} - ${album.title} ($count tracks)');
    }

    // Start a 128 kbps AAC transcode of a recently added album's first track.
    final recent = await plex.library.recentlyAdded(
      sectionId: music.first.id,
      size: 1,
    );
    if (recent.isEmpty) return;
    final tracks =
        await plex.library.children(ratingKey: recent.first.ratingKey);
    if (tracks.isEmpty) return;
    final transcode = await plex.streaming.startAudioTranscode(
      ratingKey: tracks.first.ratingKey,
      session: 'example-session',
      maxBitrateKbps: 128,
    );
    print('Playable: ${transcode.decision.isPlayable}\n${transcode.url}');
    await plex.streaming.stopUniversal(session: transcode.session);
  } on PlexException catch (e) {
    print('Plex call failed: $e (transient: ${e.isTransient})');
  } finally {
    plex.close();
  }
}
