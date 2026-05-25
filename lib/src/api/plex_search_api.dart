// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';
import '../plex_models.dart';

/// Search endpoints.
class PlexSearchApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.search].
  PlexSearchApi(this._http);

  /// Modern hub-based search (`/hubs/search`). Returns one [PlexHub] per
  /// result category — albums, artists, tracks, movies, …
  ///
  /// Scope the query to a single library by passing [sectionId].
  Future<List<PlexHub>> hubs({
    required String query,
    String? sectionId,
    int limit = 10,
    bool includeCollections = true,
  }) async {
    final qp = <String, dynamic>{
      'query': query,
      'limit': limit,
      'includeCollections': includeCollections ? 1 : 0,
    };
    if (sectionId != null) qp['sectionId'] = sectionId;
    final res = await _http.request<Map<String, dynamic>>(
      '/hubs/search',
      queryParameters: qp,
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Hub',
      PlexHub.fromJson,
    ).items;
  }

  /// Legacy flat search (`/search?query=…`).
  Future<List<PlexMetadata>> flat({
    required String query,
    int limit = 30,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/search',
      queryParameters: {'query': query, 'limit': limit},
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `GET /hubs/search/voice` — voice-search variant of [hubs].
  /// Same response shape as `hubs()`; the server treats the query
  /// as a free-form natural-language phrase rather than a token
  /// match.
  Future<List<PlexHub>> voice({
    required String query,
    int limit = 10,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/hubs/search/voice',
      queryParameters: {'query': query, 'limit': limit},
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Hub',
      PlexHub.fromJson,
    ).items;
  }
}
