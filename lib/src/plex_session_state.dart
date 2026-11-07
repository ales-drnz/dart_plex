// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The sign-in state a client and its sub-APIs share. Not exported.
library;

import 'package:meta/meta.dart';

import 'plex_jwt.dart';
import 'plex_models.dart';

/// What a `PlexClient`'s sub-APIs need to know about the sign-in beyond
/// the connection's own token: the plex.tv token, the JWT session that
/// renews it, and how the server is reached. One per client; its
/// `withCancelToken` views share it.
@internal
final class PlexSessionState {
  /// The token for plex.tv calls, when it differs from the server's.
  /// `null` means "the connection's token".
  String? accountToken;

  /// The JWT session renewing [accountToken], after `PlexClient.useJwt`.
  PlexJwtSession? jwt;

  /// The connection picked by `connectTo` / `connectToResource`; `null`
  /// after a plain `connect(url)`.
  PlexServerConnection? connection;
}
