// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// @docImport '../plex_client.dart';
/// @docImport 'plex_library_api.dart';
library;

import '../parsing/plex_parsing.dart';
import '../plex_connection.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';
import '../plex_models.dart';
import '../plex_urls.dart';

/// `/library/collections/*` — hand-curated groupings of metadata
/// items.
///
/// Wraps the `Collection` and `Library Collections` OpenAPI tags
/// (4 operations). Collections are typed metadata items with their
/// own ratingKey, so the existing [PlexLibraryApi.item] and
/// [PlexLibraryApi.children] also work on them — this sub-API is
/// for create / add / remove / reorder.
///
/// {@category Library}
class PlexCollectionsApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.collections].
  PlexCollectionsApi(this._http);

  /// `POST /library/collections?sectionId={id}` — create a new
  /// collection in the library section [sectionId].
  ///
  /// Only [sectionId] is required by the server. Provide [title] to
  /// name the collection, [type] (sent as its numeric value) to
  /// constrain its contents, and [smart] to create a smart
  /// collection driven by a filter.
  ///
  /// [seedUri] is the play-queue-style URI of the items to seed the
  /// collection with, built like:
  /// `server://{machineIdentifier}/com.plexapp.plugins.library/library/metadata/{id1},{id2}`.
  /// It is optional for a regular collection (omit it to create an
  /// empty collection, then add items with [addItems]) but is
  /// **required when [smart] is `true`** — the server returns 400
  /// ("The uri is missing for a smart collection") otherwise. The
  /// `smart` flag is sent as Plex's conventional `1`/`0` BoolInt, and
  /// a smart collection without a [seedUri] throws an [ArgumentError].
  Future<PlexMetadata> create({
    required String sectionId,
    String? title,
    PlexMetadataType? type,
    bool? smart,
    String? seedUri,
  }) async {
    if (smart == true && seedUri == null) {
      throw ArgumentError('seedUri is required when smart is true');
    }
    final items = await _http.requestJson(
      '/library/collections',
      itemsOf('Metadata', PlexMetadata.fromJson),
      method: 'POST',
      queryParameters: {
        'sectionId': sectionId,
        'title': ?title,
        'type': ?type?.value,
        if (smart != null) 'smart': smart ? '1' : '0',
        'uri': ?seedUri,
      },
    );
    if (items.isEmpty) {
      throw const PlexException(
        'Plex returned no collection metadata after create',
        type: PlexErrorType.parse,
      );
    }
    return items.first;
  }

  /// `GET /library/collections/{collectionId}/items` — items in a
  /// collection.
  Future<List<PlexMetadata>> items({required String collectionId}) async {
    return _http.requestJson(
      '/library/collections/${seg(collectionId)}/items',
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `PUT /library/collections/{collectionId}/items?uri={uri}` —
  /// add items to a collection.
  Future<void> addItems({
    required String collectionId,
    required String uri,
  }) async {
    await _http.request<void>(
      '/library/collections/${seg(collectionId)}/items',
      method: 'PUT',
      queryParameters: {'uri': uri},
    );
  }

  /// `DELETE /library/collections/{collectionId}/items/{itemId}` —
  /// remove a single item from a collection.
  ///
  /// The community document lists `PUT` for this route; verified on PMS
  /// 1.43.2, `PUT` answers 404 and leaves the item, `DELETE` answers 200
  /// and removes it.
  Future<void> removeItem({
    required String collectionId,
    required String itemId,
  }) async {
    await _http.request<void>(
      '/library/collections/${seg(collectionId)}/items/${seg(itemId)}',
      method: 'DELETE',
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
      '/library/collections/${seg(collectionId)}/items/${seg(itemId)}/move',
      method: 'PUT',
      queryParameters: {'after': afterItemId},
    );
  }

  /// `GET /library/collections/{collectionId}/composite/{updatedAt}`
  /// — URL for the collection's auto-composed cover image.
  ///
  /// The URL carries the token: do not log it. Throws a `state`
  /// [PlexException] before [PlexClient.connect].
  String compositeImageUrl({
    required String collectionId,
    required int updatedAt,
  }) => _http.signedUrl(
    '/library/collections/${seg(collectionId)}/composite/$updatedAt',
  );
}
