// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';

/// Top-level server endpoints — `/`, `/identity`, `/capabilities`.
class PlexServerApi {
  final PlexConnection _http;

  PlexServerApi(this._http);

  /// Cheapest possible reachability check — `/identity` doesn't require
  /// authentication, so this works even with an expired token (you can
  /// use it to verify the server URL is reachable before re-authenticating).
  ///
  /// Returns the raw `MediaContainer` map — useful keys are
  /// `machineIdentifier`, `version`, `apiVersion`.
  Future<Map<String, dynamic>> identity() async {
    final res = await _http.request<Map<String, dynamic>>('/identity');
    final data = res.data ?? const <String, dynamic>{};
    final container = data['MediaContainer'];
    return container is Map<String, dynamic> ? container : data;
  }

  /// Full server root — same shape as [identity] but with more fields
  /// (`platform`, `platformVersion`, `myPlex`, `transcoderAudio`, etc.).
  Future<Map<String, dynamic>> info() async {
    final res = await _http.request<Map<String, dynamic>>('/');
    final data = res.data ?? const <String, dynamic>{};
    final container = data['MediaContainer'];
    return container is Map<String, dynamic> ? container : data;
  }

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
  Future<Map<String, dynamic>> securityResources({
    String? source,
    bool? refresh,
  }) async {
    final qp = <String, dynamic>{};
    if (source != null) qp['source'] = source;
    if (refresh != null) qp['refresh'] = refresh ? 1 : 0;
    final res = await _http.request<Map<String, dynamic>>(
      '/security/resources',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `POST /security/token?type={t}&scope={s}` — request a transient
  /// access token (used to delegate playback to a Chromecast or
  /// to embed a viewer link in a webhook).
  Future<Map<String, dynamic>> transientToken({
    required String type,
    required String scope,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/security/token',
      method: 'POST',
      queryParameters: {'type': type, 'scope': scope},
    );
    return res.data ?? const {};
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
