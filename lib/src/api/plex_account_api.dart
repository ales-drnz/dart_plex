// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';
import '../plex_models.dart';

/// Talks to <https://plex.tv/api/v2> for everything that lives outside a
/// specific Plex Media Server: authentication, server discovery, user
/// profile.
class PlexAccountApi {
  static const String _plexTv = 'https://plex.tv/api/v2';
  static const String _plexTvLegacy = 'https://plex.tv';

  final PlexConnection _http;

  PlexAccountApi(this._http);

  // -------------------------------------------------------------------------
  // Legacy username/password sign-in
  // -------------------------------------------------------------------------

  /// Authenticate with username and password against the legacy
  /// `/users/sign_in.json` endpoint.
  ///
  /// This is the simplest flow for desktop apps that already collect
  /// credentials, but Plex officially recommends the PIN flow for new
  /// integrations — accounts with 2FA enabled cannot use this path.
  ///
  /// On success the returned [PlexUser] contains `authToken`; the
  /// underlying [PlexConnection] is also updated so subsequent PMS
  /// requests reuse the same token.
  Future<PlexUser> signInWithPassword({
    required String username,
    required String password,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '$_plexTvLegacy/users/sign_in.json',
      method: 'POST',
      absoluteUrl: true,
      data: {
        'user[login]': username,
        'user[password]': password,
      },
      extraHeaders: const {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    );
    final data = res.data;
    if (data == null) {
      throw const PlexException(
        'Empty response from /users/sign_in.json',
        type: PlexErrorType.parse,
      );
    }
    final user = PlexUser.fromJson(data);
    if (user.authToken.isEmpty) {
      throw const PlexException(
        'Sign-in succeeded but no authToken was returned',
        type: PlexErrorType.auth,
      );
    }
    return user;
  }

  // -------------------------------------------------------------------------
  // PIN flow (recommended)
  // -------------------------------------------------------------------------

  /// Start a PIN flow.
  ///
  /// Plex returns a [PlexPin] with a 4-character [PlexPin.code] that the
  /// user must enter at <https://plex.tv/link>. Poll [pollPin] until
  /// [PlexPin.authToken] is non-null, or until [PlexPin.expiresAt] passes.
  ///
  /// When [strong] is true (default), Plex issues a JWT-grade token.
  Future<PlexPin> createPin({bool strong = true}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '$_plexTv/pins',
      method: 'POST',
      absoluteUrl: true,
      queryParameters: {'strong': strong ? 'true' : 'false'},
    );
    final data = res.data;
    if (data == null) {
      throw const PlexException(
        'Empty response from POST /pins',
        type: PlexErrorType.parse,
      );
    }
    return PlexPin.fromJson(data);
  }

  /// Poll the state of a previously created PIN.
  ///
  /// The returned pin is the freshest state — once [PlexPin.isAuthenticated]
  /// is true, save [PlexPin.authToken] and stop polling.
  Future<PlexPin> pollPin(int id) async {
    final res = await _http.request<Map<String, dynamic>>(
      '$_plexTv/pins/$id',
      absoluteUrl: true,
    );
    final data = res.data;
    if (data == null) {
      throw const PlexException(
        'Empty response from GET /pins/{id}',
        type: PlexErrorType.parse,
      );
    }
    return PlexPin.fromJson(data);
  }

  // -------------------------------------------------------------------------
  // Account info & sign-out
  // -------------------------------------------------------------------------

  /// Fetch the currently authenticated user's profile.
  Future<PlexUser> currentUser() async {
    final res = await _http.request<Map<String, dynamic>>(
      '$_plexTv/user',
      absoluteUrl: true,
    );
    final data = res.data;
    if (data == null) {
      throw const PlexException(
        'Empty response from GET /user',
        type: PlexErrorType.parse,
      );
    }
    return PlexUser.fromJson(data);
  }

  /// Sign out the current token at plex.tv.
  Future<void> signOut() async {
    await _http.request<void>(
      '$_plexTvLegacy/api/v2/users/signout',
      method: 'DELETE',
      absoluteUrl: true,
    );
  }

  // -------------------------------------------------------------------------
  // Server discovery
  // -------------------------------------------------------------------------

  /// List the servers the current account has access to.
  ///
  /// Pass `serverOnly = true` (default) to filter out player/client
  /// resources — i.e. keep only resources whose `provides` includes
  /// `'server'`. Use [PlexResource.bestConnection] to pick a connectable
  /// URI from each one.
  Future<List<PlexResource>> fetchResources({
    bool includeHttps = true,
    bool includeRelay = true,
    bool includeIPv6 = true,
    bool serverOnly = true,
  }) async {
    final res = await _http.request<List<dynamic>>(
      '$_plexTv/resources',
      absoluteUrl: true,
      queryParameters: {
        'includeHttps': includeHttps ? 1 : 0,
        'includeRelay': includeRelay ? 1 : 0,
        'includeIPv6': includeIPv6 ? 1 : 0,
      },
    );
    final list = res.data ?? const [];
    final all = <PlexResource>[
      for (final e in list)
        if (e is Map<String, dynamic>) PlexResource.fromJson(e),
    ];
    if (!serverOnly) return all;
    return all.where((r) => r.isServer).toList(growable: false);
  }

  /// `GET /user` — details for the access token currently in use
  /// (issued from the PMS, not from plex.tv).
  Future<Map<String, dynamic>> tokenDetails() async {
    final res = await _http.request<Map<String, dynamic>>('/user');
    return res.data ?? const {};
  }

  /// `GET /users` — list every connected user (admin only).
  Future<List<Map<String, dynamic>>> connectedUsers() async {
    final res = await _http.request<Map<String, dynamic>>('/users');
    final container = res.data?['MediaContainer'];
    if (container is! Map<String, dynamic>) return const [];
    final list = container['User'];
    if (list is! List) return const [];
    return [for (final e in list) if (e is Map<String, dynamic>) e];
  }
}
