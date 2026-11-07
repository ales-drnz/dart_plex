// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The renewal of a refused token. Plex only, so it lives apart from the
/// transport shared with dart_jellyfin. Not exported.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import 'plex_client.dart';
import 'plex_connection.dart';
import 'plex_exception.dart';

/// Retries a request refused with `401` or `498` once, with the token
/// [renewer] returns. One per connection; its scoped views share it.
@internal
final class PlexTokenRenewal {
  /// Gets the refused token and returns the one to retry with, or `null`.
  PlexTokenRenewer? renewer;

  Future<String?>? _pending;

  /// Marks the zone [renewer] runs in: its own requests are never renewed,
  /// so a refusal there cannot wait on the renewal it is part of.
  static final Object _inside = Object();

  /// [attempt], retried once with a renewed token after a `401` or `498`.
  ///
  /// A request that names `X-Plex-Token` in [extraHeaders] (to send
  /// another token, or none) is left alone: the renewer replaces the
  /// connection's token, not that one. So is a request made by the
  /// renewer itself.
  Future<T> Function() guard<T>(
    PlexConnection connection,
    Map<String, String>? extraHeaders,
    Future<T> Function() attempt,
  ) {
    final explicit =
        extraHeaders?.keys.any((k) => k.toLowerCase() == 'x-plex-token') ??
        false;
    if (explicit || Zone.current[_inside] == true) return attempt;
    var renewed = false;
    return () async {
      final sent = connection.token;
      try {
        return await attempt();
      } on PlexException catch (e) {
        if (renewed ||
            (e.statusCode != 401 && e.statusCode != 498) ||
            !await _renew(connection, sent)) {
          rethrow;
        }
        renewed = true;
        return attempt();
      }
    };
  }

  /// Asks [renewer] for a token to replace [rejected]; true when there is
  /// a different one to retry with.
  Future<bool> _renew(PlexConnection connection, String? rejected) async {
    final renew = renewer;
    if (renew == null) return false;
    if (connection.token != rejected) return true;
    final String? fresh;
    try {
      fresh = await (_pending ??= runZoned(
        () => renew(rejected),
        zoneValues: {_inside: true},
      ).whenComplete(() => _pending = null));
    } catch (_) {
      return false;
    }
    if (fresh == null || fresh == rejected) return false;
    if (connection.token == rejected) connection.token = fresh;
    return true;
  }
}
