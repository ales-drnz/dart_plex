// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';

/// `/media/grabbers/*` — DVR/IPTV grabber device management.
///
/// Wraps the `Devices` OpenAPI tag (13 operations). Admin only.
/// "Grabbers" are the things that capture live TV: HDHomeRun tuners,
/// IPTV M3U sources, etc. Each grabber owns one or more devices,
/// each device has channels and a channel map.
class PlexDevicesApi {
  final PlexConnection _http;

  PlexDevicesApi(this._http);

  /// `GET /media/grabbers?protocol={...}` — available grabber
  /// protocols (HDHomeRun, M3U, etc.).
  Future<Map<String, dynamic>> grabbers({String? protocol}) async {
    final qp = <String, dynamic>{};
    if (protocol != null) qp['protocol'] = protocol;
    final res = await _http.request<Map<String, dynamic>>(
      '/media/grabbers',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `GET /media/grabbers/devices` — every registered device.
  Future<Map<String, dynamic>> list() async {
    final res =
        await _http.request<Map<String, dynamic>>('/media/grabbers/devices');
    return res.data ?? const {};
  }

  /// `POST /media/grabbers/devices?uri={uri}` — add a device by URI
  /// (e.g. `hdhomerun://1A2B3C4D` or an M3U URL).
  Future<Map<String, dynamic>> add({required String uri}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/media/grabbers/devices',
      method: 'POST',
      queryParameters: {'uri': uri},
    );
    return res.data ?? const {};
  }

  /// `POST /media/grabbers/devices/discover` — tell every grabber
  /// to probe the LAN for new devices.
  Future<Map<String, dynamic>> discover() async {
    final res = await _http.request<Map<String, dynamic>>(
      '/media/grabbers/devices/discover',
      method: 'POST',
    );
    return res.data ?? const {};
  }

  /// `GET /media/grabbers/devices/{deviceId}` — one device's
  /// details.
  Future<Map<String, dynamic>> details(String deviceId) async {
    final res = await _http.request<Map<String, dynamic>>(
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
  Future<Map<String, dynamic>> channels(String deviceId) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/media/grabbers/devices/$deviceId/channels',
    );
    return res.data ?? const {};
  }

  /// `PUT /media/grabbers/devices/{deviceId}/channelmap` — set the
  /// device's channel map (which channels are visible, optional
  /// remapping by key).
  Future<void> setChannelMap({
    required String deviceId,
    String? channelMapping,
    String? channelMappingByKey,
    String? channelsEnabled,
  }) async {
    final qp = <String, dynamic>{};
    if (channelMapping != null) qp['channelMapping'] = channelMapping;
    if (channelMappingByKey != null) {
      qp['channelMappingByKey'] = channelMappingByKey;
    }
    if (channelsEnabled != null) qp['channelsEnabled'] = channelsEnabled;
    await _http.request<void>(
      '/media/grabbers/devices/$deviceId/channelmap',
      method: 'PUT',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// `PUT /media/grabbers/devices/{deviceId}/prefs` — set device
  /// preferences. [body] keys vary by grabber type.
  Future<void> setPreferences({
    required String deviceId,
    Map<String, dynamic>? prefs,
    String? name,
  }) async {
    final qp = <String, dynamic>{};
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
    final qp = <String, dynamic>{};
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
