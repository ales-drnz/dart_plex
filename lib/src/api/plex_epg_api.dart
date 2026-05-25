// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';

/// `/livetv/epg/*` — Electronic Program Guide.
///
/// Wraps the `EPG` OpenAPI tag (9 operations). The EPG is what
/// powers the "what's on" grid: which channels exist, what shows
/// are airing on them, when. Used during DVR setup to pick a
/// listings lineup.
class PlexEpgApi {
  final PlexConnection _http;

  PlexEpgApi(this._http);

  /// `GET /livetv/epg/countries` — every country with EPG support.
  Future<Map<String, dynamic>> countries() async {
    final res =
        await _http.request<Map<String, dynamic>>('/livetv/epg/countries');
    return res.data ?? const {};
  }

  /// `GET /livetv/epg/languages` — every language with EPG support.
  Future<Map<String, dynamic>> languages() async {
    final res =
        await _http.request<Map<String, dynamic>>('/livetv/epg/languages');
    return res.data ?? const {};
  }

  /// `GET /livetv/epg/countries/{country}/{epgId}/lineups?postalCode={zip}` —
  /// lineups (channel packages) for one country.
  Future<Map<String, dynamic>> countryLineups({
    required String country,
    required String epgId,
    String? postalCode,
  }) async {
    final qp = <String, dynamic>{};
    if (postalCode != null) qp['postalCode'] = postalCode;
    final res = await _http.request<Map<String, dynamic>>(
      '/livetv/epg/countries/$country/$epgId/lineups',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `GET /livetv/epg/countries/{country}/{epgId}/regions` — admin
  /// regions inside a country (used to refine lineup lookup).
  Future<Map<String, dynamic>> countryRegions({
    required String country,
    required String epgId,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/livetv/epg/countries/$country/$epgId/regions',
    );
    return res.data ?? const {};
  }

  /// `GET /livetv/epg/countries/{country}/{epgId}/regions/{region}/lineups`
  /// — lineups available inside one admin region.
  Future<Map<String, dynamic>> regionLineups({
    required String country,
    required String epgId,
    required String region,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/livetv/epg/countries/$country/$epgId/regions/$region/lineups',
    );
    return res.data ?? const {};
  }

  /// `GET /livetv/epg/lineup?device={d}&lineupGroup={g}` — server's
  /// recommended lineup for a device (uses postal code + tuning).
  Future<Map<String, dynamic>> bestLineup({
    String? device,
    String? lineupGroup,
  }) async {
    final qp = <String, dynamic>{};
    if (device != null) qp['device'] = device;
    if (lineupGroup != null) qp['lineupGroup'] = lineupGroup;
    final res = await _http.request<Map<String, dynamic>>(
      '/livetv/epg/lineup',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `GET /livetv/epg/channelmap?device={d}&lineup={l}` — best
  /// mapping between device channels and EPG lineup entries.
  Future<Map<String, dynamic>> channelMap({
    required String device,
    required String lineup,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/livetv/epg/channelmap',
      queryParameters: {'device': device, 'lineup': lineup},
    );
    return res.data ?? const {};
  }

  /// `GET /livetv/epg/channels?lineup={l}` — channels in a lineup.
  Future<Map<String, dynamic>> channels({required String lineup}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/livetv/epg/channels',
      queryParameters: {'lineup': lineup},
    );
    return res.data ?? const {};
  }

  /// `GET /livetv/epg/lineupchannels?lineup={l1,l2,...}` — channels
  /// across multiple lineups in one call.
  Future<Map<String, dynamic>> lineupChannels({
    required String lineup,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/livetv/epg/lineupchannels',
      queryParameters: {'lineup': lineup},
    );
    return res.data ?? const {};
  }
}
