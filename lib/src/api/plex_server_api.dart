// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_models.dart';
import '../plex_parsing.dart';
import '../plex_server_models.dart';

/// Top-level server endpoints — `/`, `/identity`, `/capabilities`.
///
/// {@category Server}
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
  Future<PlexSecurityResource> securityResources({
    required String source,
    bool? refresh,
  }) {
    assert(source.isNotEmpty, 'source must not be empty');
    final qp = <String, Object?>{'source': source};
    if (refresh != null) qp['refresh'] = refresh ? 1 : 0;
    return _http.requestJson(
      '/security/resources',
      queryParameters: qp,
      (json) => PlexSecurityResource.fromJson(_container(json)),
    );
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
    final res = await _http.request<Map<String, Object?>>(
      '/security/token',
      method: 'POST',
      queryParameters: const {'type': 'delegation', 'scope': 'all'},
    );
    final data = res.data ?? const <String, Object?>{};
    final container = data['MediaContainer'];
    final token = container is Map<String, Object?>
        ? container['token']
        : data['token'];
    return token is String ? token : null;
  }

  /// `GET /status/sessions/background` — background transcode jobs
  /// running on the server (optimizing, converting for download).
  Future<List<PlexTranscodeJob>> backgroundTasks() => _http.requestJson(
    '/status/sessions/background',
    itemsOf('TranscodeJob', PlexTranscodeJob.fromJson),
  );
}

/// The `MediaContainer` of [json], or [json] itself when it has none.
Map<String, Object?> _container(Object? json) {
  if (json is! Map<String, Object?>) return const <String, Object?>{};
  final c = json['MediaContainer'];
  return c is Map<String, Object?> ? c : json;
}
