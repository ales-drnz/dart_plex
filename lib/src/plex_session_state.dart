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

  /// Device JWTs signed for a JWT pin being polled, by pin id, each with
  /// the time it stops being reused. Here rather than in the account API
  /// because every `withCancelToken` view has an account API of its own.
  final Map<int, (String, DateTime)> _pinJwts = {};

  /// The device JWT kept for the pin [id], if it is still good at [now].
  /// Expired ones — of any pin, such as one nobody polls any more — are
  /// dropped on the way.
  String? pinJwt(int id, DateTime now) {
    _pinJwts.removeWhere((_, entry) => !now.isBefore(entry.$2));
    return _pinJwts[id]?.$1;
  }

  /// Keeps [jwt] for the pin [id], to be reused until [reuseUntil].
  void keepPinJwt(int id, String jwt, DateTime reuseUntil) =>
      _pinJwts[id] = (jwt, reuseUntil);

  /// Forgets the device JWT of the pin [id]: it was claimed, or expired.
  void dropPinJwt(int id) => _pinJwts.remove(id);

  /// How many device JWTs are kept.
  @visibleForTesting
  int get pinJwtCount => _pinJwts.length;
}
