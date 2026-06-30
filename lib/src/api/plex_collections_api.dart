// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';
import '../plex_models.dart';

/// `/library/collections/*` — hand-curated groupings of metadata
/// items.
///
/// Wraps the `Collection` and `Library Collections` OpenAPI tags
/// (4 operations). Collections are typed metadata items with their
/// own ratingKey, so the existing [PlexLibraryApi.item] and
/// [PlexLibraryApi.children] also work on them — this sub-API is
/// for create / add / remove / reorder.
class PlexCollectionsApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.collections].
  PlexCollectionsApi(this._http);

  /// `POST /library/collections?sectionId={id}` — create a new
  /// collection in the library section [sectionId].
  ///
  /// Only [sectionId] is required by the server. Provide [title] to
  /// name the collection, [type] (a [PlexMediaType]-style numeric
  /// code) to constrain its contents, and [smart] to create a smart
  /// collection driven by a filter.
  ///
  /// [seedUri] is the play-queue-style URI of the items to seed the
  /// collection with, built like:
  /// `server://{machineIdentifier}/com.plexapp.plugins.library/library/metadata/{id1},{id2}`.
  /// It is optional for a regular collection (omit it to create an
  /// empty collection, then add items with [addItems]) but is
  /// **required when [smart] is `true`** — the server returns 400
  /// ("The uri is missing for a smart collection") otherwise. The
  /// `smart` flag is sent as Plex's conventional `1`/`0` BoolInt.
  Future<PlexMetadata> create({
    required String sectionId,
    String? title,
    String? type,
    bool? smart,
    String? seedUri,
  }) async {
    assert(
      smart != true || seedUri != null,
      'seedUri is required when smart is true',
    );
    final qp = <String, dynamic>{'sectionId': sectionId};
    if (title != null) qp['title'] = title;
    if (type != null) qp['type'] = type;
    if (smart != null) qp['smart'] = smart ? '1' : '0';
    if (seedUri != null) qp['uri'] = seedUri;
    final res = await _http.request<Map<String, dynamic>>(
      '/library/collections',
      method: 'POST',
      queryParameters: qp,
    );
    final c = PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    );
    if (c.items.isEmpty) {
      throw Exception('Plex returned no collection metadata after create');
    }
    return c.items.first;
  }

  /// `GET /library/collections/{collectionId}/items` — items in a
  /// collection.
  Future<List<PlexMetadata>> items(String collectionId) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/collections/$collectionId/items',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `PUT /library/collections/{collectionId}/items?uri={uri}` —
  /// add items to a collection.
  Future<void> addItems({
    required String collectionId,
    required String uri,
  }) async {
    await _http.request<void>(
      '/library/collections/$collectionId/items',
      method: 'PUT',
      queryParameters: {'uri': uri},
    );
  }

  /// `PUT /library/collections/{collectionId}/items/{itemId}` —
  /// delete a single item from a collection. (The spec uses PUT not
  /// DELETE; the upstream lifecycle is "tombstone via PUT".)
  Future<void> removeItem({
    required String collectionId,
    required String itemId,
  }) async {
    await _http.request<void>(
      '/library/collections/$collectionId/items/$itemId',
      method: 'PUT',
    );
  }

  /// `PUT /library/collections/{collectionId}/items/{itemId}/move?after={otherId}`
  /// — reorder a collection. Pass [afterItemId] = `'0'` to move to
  /// the very start.
  Future<void> moveItem({
    required String collectionId,
    required String itemId,
    required String afterItemId,
  }) async {
    await _http.request<void>(
      '/library/collections/$collectionId/items/$itemId/move',
      method: 'PUT',
      queryParameters: {'after': afterItemId},
    );
  }

  /// `GET /library/collections/{collectionId}/composite/{updatedAt}`
  /// — URL for the collection's auto-composed cover image.
  String compositeImageUrl({
    required String collectionId,
    required int updatedAt,
  }) {
    final base = _http.baseUrl;
    final token = _http.token ?? '';
    return '$base/library/collections/$collectionId/composite/$updatedAt?X-Plex-Token=$token';
  }
}
