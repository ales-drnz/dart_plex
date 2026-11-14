// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// @docImport '../plex_client.dart';
library;

import '../parsing/plex_parsing.dart';
import '../plex_connection.dart';
import '../plex_models.dart';
import '../plex_urls.dart';

/// `/livetv/epg/*` — Electronic Program Guide.
///
/// Wraps the `EPG` OpenAPI tag (9 operations). The EPG is what
/// powers the "what's on" grid: which channels exist, what shows
/// are airing on them, when. Used during DVR setup to pick a
/// listings lineup.
///
/// {@category Live TV}
class PlexEpgApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.epg].
  PlexEpgApi(this._http);

  /// `GET /livetv/epg/countries` — every country with EPG support.
  Future<List<PlexEpgCountry>> countries() => _http.requestJson(
    '/livetv/epg/countries',
    itemsOf('Country', PlexEpgCountry.fromJson),
  );

  /// `GET /livetv/epg/languages` — every language with EPG support
  /// (verified on PMS 1.43.2: 594 of them).
  Future<List<PlexEpgLanguage>> languages() => _http.requestJson(
    '/livetv/epg/languages',
    itemsOf('Language', PlexEpgLanguage.fromJson),
  );

  /// `GET /livetv/epg/countries/{country}/{epgId}/lineups?postalCode={zip}` —
  /// lineups (channel packages) for one country.
  Future<List<PlexLineup>> countryLineups({
    required String country,
    required String epgId,
    String? postalCode,
  }) async => _http.requestJson(
    '/livetv/epg/countries/${seg(country)}/${seg(epgId)}/lineups',
    entriesOf('Lineup', PlexLineup.fromJson),
    queryParameters: {'postalCode': ?postalCode},
  );

  /// `GET /livetv/epg/countries/{country}/{epgId}/regions` — admin
  /// regions inside a country (used to refine lineup lookup). The API
  /// document gives them the shape of a country.
  Future<List<PlexEpgCountry>> countryRegions({
    required String country,
    required String epgId,
  }) async => _http.requestJson(
    '/livetv/epg/countries/${seg(country)}/${seg(epgId)}/regions',
    itemsOf('Country', PlexEpgCountry.fromJson),
  );

  /// `GET /livetv/epg/countries/{country}/{epgId}/regions/{region}/lineups`
  /// — lineups available inside one admin region.
  Future<List<PlexLineup>> regionLineups({
    required String country,
    required String epgId,
    required String region,
  }) async => _http.requestJson(
    '/livetv/epg/countries/${seg(country)}/${seg(epgId)}/regions/${seg(region)}/lineups',
    entriesOf('Lineup', PlexLineup.fromJson),
  );

  /// `GET /livetv/epg/lineup?device={d}&lineupGroup={g}` — server's
  /// recommended lineup for a device (uses postal code + tuning).
  ///
  /// Both [device] and [lineupGroup] are required by the server; omitting
  /// either yields a 404.
  Future<List<PlexLineup>> bestLineup({
    required String device,
    required String lineupGroup,
  }) => _http.requestJson(
    '/livetv/epg/lineup',
    entriesOf('Lineup', PlexLineup.fromJson),
    queryParameters: {'device': device, 'lineupGroup': lineupGroup},
  );

  /// `GET /livetv/epg/channelmap?device={d}&lineup={l}` — best
  /// mapping between device channels and EPG lineup entries.
  Future<List<PlexChannelMapping>> channelMap({
    required String device,
    required String lineup,
  }) => _http.requestJson(
    '/livetv/epg/channelmap',
    entriesOf('ChannelMapping', PlexChannelMapping.fromJson),
    queryParameters: {'device': device, 'lineup': lineup},
  );

  /// `GET /livetv/epg/channels?lineup={l}` — channels in a lineup.
  Future<List<PlexEpgChannel>> channels({required String lineup}) =>
      _http.requestJson(
        '/livetv/epg/channels',
        itemsOf('Channel', PlexEpgChannel.fromJson),
        queryParameters: {'lineup': lineup},
      );

  /// `GET /livetv/epg/lineupchannels?lineup={l1}&lineup={l2}&…` — channels
  /// across multiple lineups in one call.
  ///
  /// [lineup] is the list of lineup URIs to fetch; it is serialized as
  /// repeated `lineup=` query parameters. Each lineup comes with its
  /// [PlexLineup.channels].
  ///
  /// Throws an [ArgumentError] when [lineup] is empty.
  Future<List<PlexLineup>> lineupChannels({
    required List<String> lineup,
  }) async {
    if (lineup.isEmpty) {
      throw ArgumentError.value(
        lineup,
        'lineup',
        'lineup must contain at least one URI',
      );
    }
    return _http.requestJson(
      '/livetv/epg/lineupchannels',
      entriesOf('Lineup', PlexLineup.fromJson),
      queryParameters: {'lineup': lineup},
    );
  }
}
