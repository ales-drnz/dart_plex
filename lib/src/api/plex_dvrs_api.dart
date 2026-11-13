// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_models.dart';
import '../plex_parsing.dart';
import '../plex_urls.dart';
import 'plex_live_tv_api.dart';

/// `/livetv/dvrs/*` — Plex DVR backend configuration.
///
/// Wraps the `DVRs` OpenAPI tag (10 operations not already on
/// [PlexLiveTvApi]). Admin only. Each DVR groups one or more
/// devices and a listings lineup; subscriptions schedule
/// recordings against a DVR.
///
/// {@category Live TV}
class PlexDvrsApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.dvrs].
  PlexDvrsApi(this._http);

  /// `GET /livetv/dvrs/{dvrId}` — one DVR's full configuration, or
  /// `null` when the answer holds none.
  Future<PlexDvr?> get({required String dvrId}) => _http.requestJson(
    '/livetv/dvrs/${seg(dvrId)}',
    firstOf('Dvr', PlexDvr.fromJson, altKey: 'DVR'),
  );

  /// `DELETE /livetv/dvrs/{dvrId}` — drop a DVR (its recordings
  /// stay on disk).
  Future<void> delete({required String dvrId}) async {
    await _http.request<void>('/livetv/dvrs/${seg(dvrId)}', method: 'DELETE');
  }

  /// `PUT /livetv/dvrs/{dvrId}/prefs` — update DVR preferences.
  ///
  /// Only `name` is formally declared by the Plex OpenAPI spec
  /// (operation `setDVRPreferences`). The optional [prefs] map is an
  /// unvalidated passthrough: each entry is flattened into the query
  /// string as a `key=value` parameter. PMS accepts additional DVR
  /// preference keys this way, but they are not enumerated or
  /// validated by the spec or this client. Because [name] is applied
  /// first and then [prefs] is merged in, a `name` key inside [prefs]
  /// would override the explicit [name] argument.
  Future<void> setPreferences({
    required String dvrId,
    Map<String, Object?>? prefs,
    String? name,
  }) async {
    await _http.request<void>(
      '/livetv/dvrs/${seg(dvrId)}/prefs',
      method: 'PUT',
      queryParameters: {'name': ?name, ...?prefs},
    );
  }

  /// `PUT /livetv/dvrs/{dvrId}/lineups?lineup={lineupId}` — attach
  /// an EPG lineup to a DVR.
  Future<void> addLineup({
    required String dvrId,
    required String lineup,
  }) async {
    await _http.request<void>(
      '/livetv/dvrs/${seg(dvrId)}/lineups',
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
      '/livetv/dvrs/${seg(dvrId)}/lineups',
      method: 'DELETE',
      queryParameters: {'lineup': lineup},
    );
  }

  /// `POST /livetv/dvrs/{dvrId}/reloadGuide` — force-reload the
  /// program guide.
  Future<void> reloadGuide({required String dvrId}) async {
    await _http.request<void>(
      '/livetv/dvrs/${seg(dvrId)}/reloadGuide',
      method: 'POST',
    );
  }

  /// `DELETE /livetv/dvrs/{dvrId}/reloadGuide` — abort an in-flight
  /// guide reload.
  Future<void> stopReloadGuide({required String dvrId}) async {
    await _http.request<void>(
      '/livetv/dvrs/${seg(dvrId)}/reloadGuide',
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
      '/livetv/dvrs/${seg(dvrId)}/channels/${seg(channel)}/tune',
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
      '/livetv/dvrs/${seg(dvrId)}/devices/${seg(deviceId)}',
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
      '/livetv/dvrs/${seg(dvrId)}/devices/${seg(deviceId)}',
      method: 'DELETE',
    );
  }
}
