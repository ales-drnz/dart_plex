// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';
import '../plex_models.dart';

/// Playlist endpoints — `/playlists` and `/playlists/{id}/items`.
class PlexPlaylistsApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.playlists].
  PlexPlaylistsApi(this._http);

  /// List playlists (optionally filtered by [type] — `'audio' | 'video' |
  /// 'photo'`).
  Future<List<PlexMetadata>> list({
    String? type,
    bool? smart,
    String? sort,
    int start = 0,
    int size = 50,
  }) async {
    final qp = <String, dynamic>{
      'X-Plex-Container-Start': start,
      'X-Plex-Container-Size': size,
    };
    if (type != null) qp['playlistType'] = type;
    if (smart != null) qp['smart'] = smart ? 1 : 0;
    if (sort != null) qp['sort'] = sort;
    final res = await _http.request<Map<String, dynamic>>(
      '/playlists',
      queryParameters: qp,
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// Count playlists matching the same filters as [list], without
  /// transferring the items.
  Future<int> count({String? type}) async {
    final qp = <String, dynamic>{
      'X-Plex-Container-Start': 0,
      'X-Plex-Container-Size': 0,
    };
    if (type != null) qp['playlistType'] = type;
    final res = await _http.request<Map<String, dynamic>>(
      '/playlists',
      queryParameters: qp,
    );
    final raw = res.data ?? const <String, dynamic>{};
    final container = raw['MediaContainer'];
    if (container is Map<String, dynamic>) {
      final v = container['totalSize'] ?? container['size'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
    }
    return 0;
  }

  /// Items inside a playlist (`/playlists/{id}/items`).
  Future<List<PlexMetadata>> items(String playlistId) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/playlists/$playlistId/items',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
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
      throw Exception('Plex returned no playlist after create');
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

  /// Remove a single item by its `playlistItemID` (NOT by ratingKey).
  ///
  /// To find the playlistItemID, list [items] first and read
  /// `raw['playlistItemID']` on each entry.
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
  /// reorder an item. Omit [afterPlaylistItemId] (leave it null) to
  /// move the item to the very start.
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
    final res = await _http.request<Map<String, dynamic>>(
      '/playlists/$playlistId/items/$generatorId/items',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
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
    final res = await _http.request<Map<String, dynamic>>(
      '/playlists/upload',
      method: 'POST',
      queryParameters: {
        'path': path,
        'force': force ? 1 : 0,
      },
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }
}
