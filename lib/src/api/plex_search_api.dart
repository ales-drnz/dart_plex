// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_models.dart';
import '../plex_parsing.dart';

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
    return _http.requestJson(
      '/hubs/search',
      queryParameters: qp,
      itemsOf('Hub', PlexHub.fromJson),
    );
  }

  /// Legacy flat search (`/search?query=…`).
  Future<List<PlexMetadata>> flat({
    required String query,
    int limit = 30,
  }) async {
    return _http.requestJson(
      '/search',
      queryParameters: {'query': query, 'limit': limit},
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// Search one section for one kind of item
  /// (`/library/sections/{sectionId}/search?query=…&type=…`).
  ///
  /// [type] is required: PMS 1.43.2 answers 400 without it (verified).
  /// Unlike [hubs] the answer is a flat list of [type] only, so it suits
  /// a "tracks matching…" list.
  Future<List<PlexMetadata>> section({
    required String sectionId,
    required String query,
    required PlexMetadataType type,
    int? limit,
  }) {
    return _http.requestJson(
      '/library/sections/$sectionId/search',
      queryParameters: {
        'query': query,
        'type': type.value,
        if (limit != null) 'limit': limit,
      },
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `GET /hubs/search/voice` — voice-search variant of [hubs].
  /// Same response shape as `hubs()`; the server treats the query
  /// as a free-form natural-language phrase rather than a token
  /// match.
  ///
  /// Because this endpoint uses a slow Levenshtein-distance heuristic,
  /// the server recommends scoping the search to a single media [type]
  /// (e.g. [PlexMetadataType.track]) whenever possible.
  Future<List<PlexHub>> voice({
    required String query,
    PlexMetadataType? type,
    int limit = 10,
  }) async {
    final qp = <String, dynamic>{'query': query, 'limit': limit};
    if (type != null) qp['type'] = type.value;
    return _http.requestJson(
      '/hubs/search/voice',
      queryParameters: qp,
      itemsOf('Hub', PlexHub.fromJson),
    );
  }
}
