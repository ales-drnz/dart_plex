// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';
import '../plex_filter.dart';
import '../plex_models.dart';
import '../plex_parsing.dart';
import '../plex_query.dart';
import 'plex_library_api.dart';
import 'plex_server_api.dart';

/// Playlist endpoints — `/playlists` and `/playlists/{id}/items`.
class PlexPlaylistsApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.playlists].
  PlexPlaylistsApi(this._http);

  /// List playlists (`/playlists`).
  ///
  /// [type] narrows to `'audio' | 'video' | 'photo'` playlists, [smart] to
  /// smart (`true`) or regular (`false`) ones. [filters] narrows on the
  /// server, like [PlexLibraryApi.allByType]: verified on PMS 1.43.2,
  /// `/playlists` takes the general filter syntax, so
  /// `[PlexFilter.titleContains('mix'), PlexFilter.rated()]` sends
  /// `?title=mix&userRating>>=0` and comes back already narrowed (title
  /// matching is a case-insensitive "contains"). There is no need to scan
  /// pages and filter on the client.
  ///
  /// [sort] takes the section sort syntax (`'titleSort'`,
  /// `'addedAt:desc'`, `'lastViewedAt:desc'`).
  Future<List<PlexMetadata>> list({
    String? type,
    bool? smart,
    String? sort,
    List<PlexFilter> filters = const [],
    int start = 0,
    int size = 50,
  }) =>
      _http.requestJson(
        '/playlists',
        queryParameters: _query(
          type: type,
          smart: smart,
          sort: sort,
          filters: filters,
          start: start,
          size: size,
        ),
        itemsOf('Metadata', PlexMetadata.fromJson),
      );

  /// Count playlists matching the same narrowing as [list], without
  /// transferring them.
  Future<int> count({
    String? type,
    bool? smart,
    List<PlexFilter> filters = const [],
  }) async {
    final page = await _http.requestJson(
      '/playlists',
      queryParameters: _query(
        type: type,
        smart: smart,
        filters: filters,
        start: 0,
        size: 0,
      ),
      containerOf('Metadata', PlexMetadata.fromJson),
    );
    return page.totalSize;
  }

  Map<String, dynamic> _query({
    required String? type,
    required bool? smart,
    String? sort,
    required List<PlexFilter> filters,
    required int start,
    required int size,
  }) {
    final qp = containerPage(start: start, size: size);
    if (type != null) qp['playlistType'] = type;
    if (smart != null) qp['smart'] = smart ? 1 : 0;
    if (sort != null) qp['sort'] = sort;
    applyFilters(qp, filters);
    return qp;
  }

  /// Items inside a playlist (`/playlists/{id}/items`).
  ///
  /// Without [size] the whole playlist comes back, which for a long one is
  /// hundreds of KB. Pass it (and [start], default 0) to read a page — for
  /// example the first few rows, when all you need is some cover art. Each
  /// entry carries its [PlexMetadata.playlistItemId].
  Future<List<PlexMetadata>> items(
    String playlistId, {
    int? start,
    int? size,
  }) async {
    return _http.requestJson(
      '/playlists/$playlistId/items',
      queryParameters: containerPage(start: start, size: size),
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// Create a new playlist.
  ///
  /// [type] is `'audio' | 'video' | 'photo'`. [machineIdentifier] is the
  /// server's identifier — you can get it from [PlexServerApi.identity].
  ///
  /// When [itemRatingKeys] is non-empty the playlist is seeded with
  /// those items at creation time.
  Future<PlexMetadata> create({
    required String title,
    required String type,
    required String machineIdentifier,
    List<String> itemRatingKeys = const [],
  }) async {
    final uri = itemRatingKeys.isEmpty
        ? null
        : 'server://$machineIdentifier/com.plexapp.plugins.library'
            '/library/metadata/${itemRatingKeys.join(',')}';
    final qp = <String, dynamic>{
      'type': type,
      'title': title,
      'smart': 0,
      if (uri != null) 'uri': uri,
    };
    final res = await _http.request<Map<String, dynamic>>(
      '/playlists',
      method: 'POST',
      queryParameters: qp,
    );
    final c = PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    );
    if (c.items.isEmpty) {
      throw const PlexException(
        'Plex returned no playlist after create',
        type: PlexErrorType.parse,
      );
    }
    return c.items.first;
  }

  /// Append items to an existing playlist.
  Future<void> addItems({
    required String playlistId,
    required String machineIdentifier,
    required List<String> itemRatingKeys,
  }) async {
    if (itemRatingKeys.isEmpty) return;
    final uri = 'server://$machineIdentifier/com.plexapp.plugins.library'
        '/library/metadata/${itemRatingKeys.join(',')}';
    await _http.request<void>(
      '/playlists/$playlistId/items',
      method: 'PUT',
      queryParameters: {'uri': uri},
    );
  }

  /// Remove one entry by its [PlexMetadata.playlistItemId] — not by the
  /// track's ratingKey, so a track that appears twice loses only the entry
  /// you name.
  Future<void> removeItem({
    required String playlistId,
    required String playlistItemId,
  }) async {
    await _http.request<void>(
      '/playlists/$playlistId/items/$playlistItemId',
      method: 'DELETE',
    );
  }

  /// Delete a playlist.
  Future<void> delete(String playlistId) async {
    await _http.request<void>('/playlists/$playlistId', method: 'DELETE');
  }

  /// Rename a playlist.
  Future<void> rename({
    required String playlistId,
    required String title,
  }) async {
    await _http.request<void>(
      '/playlists/$playlistId',
      method: 'PUT',
      queryParameters: {'title': title},
    );
  }

  /// `PUT /playlists/{playlistId}/items/{playlistItemId}/move` —
  /// reorder one entry. Both ids are [PlexMetadata.playlistItemId]s. Omit
  /// [afterPlaylistItemId] (leave it null) to move the entry to the very
  /// start.
  Future<void> moveItem({
    required String playlistId,
    required String playlistItemId,
    String? afterPlaylistItemId,
  }) async {
    await _http.request<void>(
      '/playlists/$playlistId/items/$playlistItemId/move',
      method: 'PUT',
      queryParameters:
          afterPlaylistItemId == null ? null : {'after': afterPlaylistItemId},
    );
  }

  /// `GET /playlists/{playlistId}/generators` — list the smart
  /// generators feeding a smart playlist. Returns raw maps; the
  /// generator id is in each entry's `id` field.
  Future<List<Map<String, dynamic>>> generators(String playlistId) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/playlists/$playlistId/generators',
    );
    final container = res.data?['MediaContainer'];
    if (container is! Map<String, dynamic>) return const [];
    final list = container['PlayQueueGenerator'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) e,
    ];
  }

  /// `GET /playlists/{playlistId}/items/{generatorId}/items` — items
  /// produced by one generator inside a smart playlist.
  Future<List<PlexMetadata>> generatorItems({
    required String playlistId,
    required String generatorId,
  }) async {
    return _http.requestJson(
      '/playlists/$playlistId/items/$generatorId/items',
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `PUT /playlists/{playlistId}/items/{generatorId}/{metadataId}/{action}`
  /// — re-run a generator with an action (`reprocess`, `disable`, or
  /// `enable`).
  Future<void> reprocessGenerator({
    required String playlistId,
    required String generatorId,
    required String metadataId,
    required String action,
  }) async {
    await _http.request<void>(
      '/playlists/$playlistId/items/$generatorId/$metadataId/$action',
      method: 'PUT',
    );
  }

  /// `POST /playlists/upload` — import m3u playlists from a server-side path.
  ///
  /// [path] is the absolute path on the server to either a directory of
  /// m3u files (each file becomes a separate playlist) or a single
  /// playlist file.
  ///
  /// [force] controls duplicate handling and defaults to `true` to match
  /// the server's default behaviour: a playlist uploaded with the same
  /// path overwrites the existing one. Pass `false` to instead create a
  /// new playlist suffixed with the upload date and time.
  ///
  /// Returns the playlists created or overwritten by the import.
  Future<List<PlexMetadata>> upload({
    required String path,
    bool force = true,
  }) async {
    return _http.requestJson(
      '/playlists/upload',
      method: 'POST',
      queryParameters: {
        'path': path,
        'force': force ? 1 : 0,
      },
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }
}
