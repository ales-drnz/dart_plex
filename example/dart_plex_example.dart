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
  );

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

  final sections = await plex.library.sections();
  for (final s in sections) {
    print('${s.title} (${s.type})');
  }
}
