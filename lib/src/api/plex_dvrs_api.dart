// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';

/// `/livetv/dvrs/*` — Plex DVR backend configuration.
///
/// Wraps the `DVRs` OpenAPI tag (10 operations not already on
/// [PlexLiveTvApi]). Admin only. Each DVR groups one or more
/// devices and a listings lineup; subscriptions schedule
/// recordings against a DVR.
class PlexDVRsApi {
  final PlexConnection _http;

  PlexDVRsApi(this._http);

  /// `GET /livetv/dvrs/{dvrId}` — one DVR's full configuration.
  Future<Map<String, dynamic>> get(String dvrId) async {
    final res =
        await _http.request<Map<String, dynamic>>('/livetv/dvrs/$dvrId');
    return res.data ?? const {};
  }

  /// `DELETE /livetv/dvrs/{dvrId}` — drop a DVR (its recordings
  /// stay on disk).
  Future<void> delete(String dvrId) async {
    await _http.request<void>('/livetv/dvrs/$dvrId', method: 'DELETE');
  }

  /// `PUT /livetv/dvrs/{dvrId}/prefs` — update DVR preferences.
  Future<void> setPreferences({
    required String dvrId,
    Map<String, dynamic>? prefs,
    String? name,
  }) async {
    final qp = <String, dynamic>{};
    if (name != null) qp['name'] = name;
    if (prefs != null) qp.addAll(prefs);
    await _http.request<void>(
      '/livetv/dvrs/$dvrId/prefs',
      method: 'PUT',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// `PUT /livetv/dvrs/{dvrId}/lineups?lineup={lineupId}` — attach
  /// an EPG lineup to a DVR.
  Future<void> addLineup({
    required String dvrId,
    required String lineup,
  }) async {
    await _http.request<void>(
      '/livetv/dvrs/$dvrId/lineups',
      method: 'PUT',
      queryParameters: {'lineup': lineup},
    );
  }

  /// `DELETE /livetv/dvrs/{dvrId}/lineups?lineup={lineupId}` —
  /// detach a lineup.
  Future<void> deleteLineup({
    required String dvrId,
    required String lineup,
  }) async {
    await _http.request<void>(
      '/livetv/dvrs/$dvrId/lineups',
      method: 'DELETE',
      queryParameters: {'lineup': lineup},
    );
  }

  /// `POST /livetv/dvrs/{dvrId}/reloadGuide` — force-reload the
  /// program guide.
  Future<void> reloadGuide(String dvrId) async {
    await _http.request<void>(
      '/livetv/dvrs/$dvrId/reloadGuide',
      method: 'POST',
    );
  }

  /// `DELETE /livetv/dvrs/{dvrId}/reloadGuide` — abort an in-flight
  /// guide reload.
  Future<void> stopReloadGuide(String dvrId) async {
    await _http.request<void>(
      '/livetv/dvrs/$dvrId/reloadGuide',
      method: 'DELETE',
    );
  }

  /// `POST /livetv/dvrs/{dvrId}/channels/{channel}/tune` — tune a
  /// channel (used by the live-stream session lifecycle).
  Future<void> tuneChannel({
    required String dvrId,
    required String channel,
  }) async {
    await _http.request<void>(
      '/livetv/dvrs/$dvrId/channels/$channel/tune',
      method: 'POST',
    );
  }

  /// `PUT /livetv/dvrs/{dvrId}/devices/{deviceId}` — add an
  /// existing grabber device to a DVR.
  Future<void> addDevice({
    required String dvrId,
    required String deviceId,
  }) async {
    await _http.request<void>(
      '/livetv/dvrs/$dvrId/devices/$deviceId',
      method: 'PUT',
    );
  }

  /// `DELETE /livetv/dvrs/{dvrId}/devices/{deviceId}` — detach a
  /// grabber device from a DVR.
  Future<void> removeDevice({
    required String dvrId,
    required String deviceId,
  }) async {
    await _http.request<void>(
      '/livetv/dvrs/$dvrId/devices/$deviceId',
      method: 'DELETE',
    );
  }
}
