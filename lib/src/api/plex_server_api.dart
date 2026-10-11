// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';
import '../plex_server_models.dart';

/// Top-level server endpoints — `/`, `/identity`, `/capabilities`.
class PlexServerApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.server].
  PlexServerApi(this._http);

  /// Cheapest possible reachability check — `/identity` doesn't require
  /// authentication, so this works even with an expired token (you can
  /// use it to verify the server URL is reachable before re-authenticating).
  ///
  Future<PlexServerIdentity> identity() => _http.requestJson(
        '/identity',
        (json) => PlexServerIdentity.fromJson(_container(json)),
      );

  /// Full server root — same shape as [identity] but with more fields
  /// (`platform`, `platformVersion`, `myPlex`, `transcoderAudio`, etc.).
  Future<PlexServerInfo> info() => _http.requestJson(
        '/',
        (json) => PlexServerInfo.fromJson(_container(json)),
      );

  /// `true` when the server replies to `/identity`. Swallows transport
  /// failures and timeouts. Use [identity] directly to inspect errors.
  Future<bool> ping() async {
    try {
      await identity();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// `GET /security/resources?source={s}` — fetch connection info
  /// for a source (used during cross-server playback negotiation).
  ///
  /// [source] is required by the server: omitting it (or passing an empty
  /// string) always yields a 400. [refresh] is sent as the BoolInt `1`/`0`
  /// the API expects.
  Future<Map<String, dynamic>> securityResources({
    required String source,
    bool? refresh,
  }) async {
    assert(source.isNotEmpty, 'source must not be empty');
    final qp = <String, dynamic>{'source': source};
    if (refresh != null) qp['refresh'] = refresh ? 1 : 0;
    final res = await _http.request<Map<String, dynamic>>(
      '/security/resources',
      queryParameters: qp,
    );
    return res.data ?? const {};
  }

  /// `POST /security/token?type=delegation&scope=all` — request a transient
  /// access token (used to delegate playback to a Chromecast or to embed a
  /// viewer link in a webhook).
  ///
  /// The server only accepts `type=delegation` and `scope=all`, so both are
  /// hardcoded; any other value is rejected with a 400. Returns the
  /// transient token string from `MediaContainer.token` (the token is valid
  /// for up to 48 hours), or `null` if the response carries no token.
  Future<String?> transientToken() async {
    final res = await _http.request<Map<String, dynamic>>(
      '/security/token',
      method: 'POST',
      queryParameters: const {'type': 'delegation', 'scope': 'all'},
    );
    final data = res.data ?? const <String, dynamic>{};
    final container = data['MediaContainer'];
    final token =
        container is Map<String, dynamic> ? container['token'] : data['token'];
    return token is String ? token : null;
  }

  /// `GET /status/sessions/background` — list background tasks
  /// currently running on the server (library scans, intro
  /// detection, etc.).
  Future<Map<String, dynamic>> backgroundTasks() async {
    final res = await _http.request<Map<String, dynamic>>(
      '/status/sessions/background',
    );
    return res.data ?? const {};
  }
}

/// The `MediaContainer` of [json], or [json] itself when it has none.
Map<String, dynamic> _container(Object? json) {
  if (json is! Map<String, dynamic>) return const <String, dynamic>{};
  final c = json['MediaContainer'];
  return c is Map<String, dynamic> ? c : json;
}
