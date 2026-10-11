// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';

/// `/media/grabbers/*` — DVR/IPTV grabber device management.
///
/// Wraps the `Devices` OpenAPI tag (13 operations). Admin only.
/// "Grabbers" are the things that capture live TV: HDHomeRun tuners,
/// IPTV M3U sources, etc. Each grabber owns one or more devices,
/// each device has channels and a channel map.
class PlexDevicesApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.devices].
  PlexDevicesApi(this._http);

  /// `GET /media/grabbers?protocol={...}` — available grabber
  /// protocols (HDHomeRun, M3U, etc.).
  Future<Map<String, Object?>> grabbers({String? protocol}) async {
    final qp = <String, Object?>{};
    if (protocol != null) qp['protocol'] = protocol;
    final res = await _http.request<Map<String, Object?>>(
      '/media/grabbers',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `GET /media/grabbers/devices` — every registered device.
  Future<Map<String, Object?>> list() async {
    final res =
        await _http.request<Map<String, Object?>>('/media/grabbers/devices');
    return res.data ?? const {};
  }

  /// `POST /media/grabbers/devices?uri={uri}` — add a device by URI
  /// (e.g. `hdhomerun://1A2B3C4D` or an M3U URL).
  Future<Map<String, Object?>> add({required String uri}) async {
    final res = await _http.request<Map<String, Object?>>(
      '/media/grabbers/devices',
      method: 'POST',
      queryParameters: {'uri': uri},
    );
    return res.data ?? const {};
  }

  /// `POST /media/grabbers/devices/discover` — tell every grabber
  /// to probe the LAN for new devices.
  Future<Map<String, Object?>> discover() async {
    final res = await _http.request<Map<String, Object?>>(
      '/media/grabbers/devices/discover',
      method: 'POST',
    );
    return res.data ?? const {};
  }

  /// `GET /media/grabbers/devices/{deviceId}` — one device's
  /// details.
  Future<Map<String, Object?>> details(String deviceId) async {
    final res = await _http.request<Map<String, Object?>>(
      '/media/grabbers/devices/$deviceId',
    );
    return res.data ?? const {};
  }

  /// `DELETE /media/grabbers/devices/{deviceId}` — drop a device.
  Future<void> remove(String deviceId) async {
    await _http.request<void>(
      '/media/grabbers/devices/$deviceId',
      method: 'DELETE',
    );
  }

  /// `PUT /media/grabbers/devices/{deviceId}?enabled={bool}` —
  /// enable or disable a device.
  Future<void> setEnabled({
    required String deviceId,
    required bool enabled,
  }) async {
    await _http.request<void>(
      '/media/grabbers/devices/$deviceId',
      method: 'PUT',
      queryParameters: {'enabled': enabled ? 1 : 0},
    );
  }

  /// `GET /media/grabbers/devices/{deviceId}/channels` — channels
  /// the device can see.
  Future<Map<String, Object?>> channels(String deviceId) async {
    final res = await _http.request<Map<String, Object?>>(
      '/media/grabbers/devices/$deviceId/channels',
    );
    return res.data ?? const {};
  }

  /// `PUT /media/grabbers/devices/{deviceId}/channelmap` — set the
  /// device's channel map (which channels are visible, optional
  /// remapping by VCN or by lineup key).
  ///
  /// [channelMapping] maps each device channel to a lineup VCN
  /// (e.g. `{'46.3': 2, '48.9': 4}`); [channelMappingByKey] maps each
  /// device channel to a lineup key. Both are `deepObject` query
  /// params, so each entry is flattened into a bracket-notation key
  /// (`channelMapping[46.3]=2`) to match the wire format the server
  /// expects. [channelsEnabled] lists the channels to enable and is
  /// sent as a comma-separated array.
  Future<void> setChannelMap({
    required String deviceId,
    Map<String, Object>? channelMapping,
    Map<String, Object>? channelMappingByKey,
    List<String>? channelsEnabled,
  }) async {
    final qp = <String, Object?>{};
    channelMapping?.forEach((k, v) => qp['channelMapping[$k]'] = v);
    channelMappingByKey?.forEach((k, v) => qp['channelMappingByKey[$k]'] = v);
    if (channelsEnabled != null) {
      qp['channelsEnabled'] = channelsEnabled.join(',');
    }
    await _http.request<void>(
      '/media/grabbers/devices/$deviceId/channelmap',
      method: 'PUT',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// `PUT /media/grabbers/devices/{deviceId}/prefs` — set device
  /// preferences. [prefs] keys vary by grabber type and travel as query
  /// parameters; [name] renames the device.
  Future<void> setPreferences({
    required String deviceId,
    Map<String, Object?>? prefs,
    String? name,
  }) async {
    final qp = <String, Object?>{};
    if (name != null) qp['name'] = name;
    if (prefs != null) qp.addAll(prefs);
    await _http.request<void>(
      '/media/grabbers/devices/$deviceId/prefs',
      method: 'PUT',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// `POST /media/grabbers/devices/{deviceId}/scan` — kick off a
  /// channel scan on the device. [source] is grabber-specific
  /// (e.g. `'antenna'`, `'cable'`).
  Future<void> startScan({required String deviceId, String? source}) async {
    final qp = <String, Object?>{};
    if (source != null) qp['source'] = source;
    await _http.request<void>(
      '/media/grabbers/devices/$deviceId/scan',
      method: 'POST',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// `DELETE /media/grabbers/devices/{deviceId}/scan` — stop a
  /// running channel scan.
  Future<void> stopScan(String deviceId) async {
    await _http.request<void>(
      '/media/grabbers/devices/$deviceId/scan',
      method: 'DELETE',
    );
  }

  /// `GET /media/grabbers/devices/{deviceId}/thumb/{version}` —
  /// URL for the device's thumbnail icon (each grabber type may
  /// ship its own icon).
  String thumbUrl({required String deviceId, required String version}) {
    final base = _http.baseUrl;
    final token = _http.token ?? '';
    return '$base/media/grabbers/devices/$deviceId/thumb/$version?X-Plex-Token=$token';
  }
}
