// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_models.dart';
import '../plex_parsing.dart';
import 'plex_search_api.dart';

/// `/hubs/*` — global and per-section discovery rails.
///
/// Hubs power Plex's "Home" screen: "Recently Added Music", "Continue
/// Listening", "More from `<artist>`", "On Deck", … Each hub is a typed
/// row of [PlexMetadata]; render them as horizontal carousels.
///
/// Search hubs live on [PlexSearchApi.hubs] (separate endpoint).
class PlexHubsApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.hubs].
  PlexHubsApi(this._http);

  /// Global hubs (`/hubs`). Returns rails the server thinks belong on
  /// the home page across every library.
  Future<List<PlexHub>> global({
    int count = 16,
    bool onlyTransient = false,
    bool includeMeta = true,
  }) async {
    return _http.requestJson(
      '/hubs',
      queryParameters: {
        'count': count,
        'onlyTransient': onlyTransient ? 1 : 0,
        'includeMeta': includeMeta ? 1 : 0,
      },
      itemsOf('Hub', PlexHub.fromJson),
    );
  }

  /// Hubs scoped to a single library section (`/hubs/sections/{id}`).
  ///
  /// [count] caps each hub's item list, [onlyTransient] keeps only the
  /// transient hubs (recently added, continue listening), and
  /// [includeMeta] asks for each hub's metadata.
  Future<List<PlexHub>> forSection({
    required String sectionId,
    int count = 16,
    bool onlyTransient = false,
    bool includeMeta = true,
  }) async {
    return _http.requestJson(
      '/hubs/sections/$sectionId',
      queryParameters: {
        'count': count,
        'onlyTransient': onlyTransient ? 1 : 0,
        'includeMeta': includeMeta ? 1 : 0,
      },
      itemsOf('Hub', PlexHub.fromJson),
    );
  }

  /// `/hubs/promoted` — the small set the server flags as "feature me
  /// prominently".
  Future<List<PlexHub>> promoted({int count = 16}) async {
    return _http.requestJson(
      '/hubs/promoted',
      queryParameters: {'count': count},
      itemsOf('Hub', PlexHub.fromJson),
    );
  }

  /// `/hubs/continueWatching` — Plex's "On Deck" / "Continue Listening"
  /// rail merged across libraries.
  Future<List<PlexMetadata>> continueWatching({int count = 16}) async {
    return _http.requestJson(
      '/hubs/continueWatching',
      queryParameters: {'count': count},
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `/hubs/sections/{id}/onDeck` — per-library "Up Next".
  Future<List<PlexMetadata>> sectionOnDeck({
    required String sectionId,
    int count = 16,
  }) async {
    return _http.requestJson(
      '/library/sections/$sectionId/onDeck',
      queryParameters: {
        'X-Plex-Container-Start': 0,
        'X-Plex-Container-Size': count,
      },
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `/hubs/items?identifier={id}` — drill into a hub by its
  /// `identifier` (a token like `library.recentlyAdded.3`).
  Future<List<PlexMetadata>> itemsByIdentifier({
    required String identifier,
    int start = 0,
    int size = 50,
  }) async {
    return _http.requestJson(
      '/hubs/items',
      queryParameters: {
        'identifier': identifier,
        'X-Plex-Container-Start': start,
        'X-Plex-Container-Size': size,
      },
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `/hubs/metadata/{metadataId}/postplay` — hubs to display after
  /// the user finishes playing this item (next-up suggestions).
  Future<List<PlexHub>> postplay({
    required String metadataId,
    bool? onlyTransient,
  }) async {
    final qp = <String, dynamic>{};
    if (onlyTransient != null) qp['onlyTransient'] = onlyTransient ? 1 : 0;
    return _http.requestJson(
      '/hubs/metadata/$metadataId/postplay',
      queryParameters: qp.isEmpty ? null : qp,
      itemsOf('Hub', PlexHub.fromJson),
    );
  }

  /// `/hubs/metadata/{metadataId}/related` — hubs related to a
  /// specific metadata item.
  Future<List<PlexHub>> related({
    required String metadataId,
    bool? onlyTransient,
  }) async {
    final qp = <String, dynamic>{};
    if (onlyTransient != null) qp['onlyTransient'] = onlyTransient ? 1 : 0;
    return _http.requestJson(
      '/hubs/metadata/$metadataId/related',
      queryParameters: qp.isEmpty ? null : qp,
      itemsOf('Hub', PlexHub.fromJson),
    );
  }

  /// `/hubs/metadata/{metadataId}` — discovery hubs rooted at a single
  /// metadata item (e.g. "More by this artist", "Appears on").
  /// Currently only meaningful for music sections.
  ///
  /// This is the base sibling of [postplay] and [related]. [onlyTransient]
  /// limits the result to hubs prone to changing after playback/additions;
  /// [count] caps each hub's item list. Both are sent only when non-null.
  Future<List<PlexHub>> forMetadata({
    required String metadataId,
    bool? onlyTransient,
    int? count,
  }) async {
    final qp = <String, dynamic>{};
    if (onlyTransient != null) qp['onlyTransient'] = onlyTransient ? 1 : 0;
    if (count != null) qp['count'] = count;
    return _http.requestJson(
      '/hubs/metadata/$metadataId',
      queryParameters: qp.isEmpty ? null : qp,
      itemsOf('Hub', PlexHub.fromJson),
    );
  }

  // ---------------------------------------------------------------------------
  // Custom hub management (admin)
  // ---------------------------------------------------------------------------

  /// `GET /hubs/sections/{sectionId}/manage` — list every hub
  /// (built-in + custom) configured on a section, including
  /// promotion flags.
  Future<List<PlexHub>> manage({
    required String sectionId,
    String? metadataItemId,
  }) async {
    final qp = <String, dynamic>{};
    if (metadataItemId != null) qp['metadataItemId'] = metadataItemId;
    return _http.requestJson(
      '/hubs/sections/$sectionId/manage',
      queryParameters: qp.isEmpty ? null : qp,
      itemsOf('Hub', PlexHub.fromJson),
    );
  }

  /// `POST /hubs/sections/{sectionId}/manage` — create a custom hub
  /// rooted at [metadataItemId]. Use the `promotedTo*` flags to
  /// decide where the hub appears.
  Future<void> createCustom({
    required String sectionId,
    required String metadataItemId,
    bool promotedToRecommended = false,
    bool promotedToOwnHome = false,
    bool promotedToSharedHome = false,
  }) async {
    await _http.request<void>(
      '/hubs/sections/$sectionId/manage',
      method: 'POST',
      queryParameters: {
        'metadataItemId': metadataItemId,
        'promotedToRecommended': promotedToRecommended ? 1 : 0,
        'promotedToOwnHome': promotedToOwnHome ? 1 : 0,
        'promotedToSharedHome': promotedToSharedHome ? 1 : 0,
      },
    );
  }

  /// `PUT /hubs/sections/{sectionId}/manage/{identifier}` — update
  /// the promotion flags on a hub.
  Future<void> updateVisibility({
    required String sectionId,
    required String identifier,
    bool? promotedToRecommended,
    bool? promotedToOwnHome,
    bool? promotedToSharedHome,
  }) async {
    final qp = <String, dynamic>{};
    if (promotedToRecommended != null) {
      qp['promotedToRecommended'] = promotedToRecommended ? 1 : 0;
    }
    if (promotedToOwnHome != null) {
      qp['promotedToOwnHome'] = promotedToOwnHome ? 1 : 0;
    }
    if (promotedToSharedHome != null) {
      qp['promotedToSharedHome'] = promotedToSharedHome ? 1 : 0;
    }
    await _http.request<void>(
      '/hubs/sections/$sectionId/manage/$identifier',
      method: 'PUT',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// `DELETE /hubs/sections/{sectionId}/manage/{identifier}` —
  /// delete a custom hub. Built-in hubs cannot be deleted.
  Future<void> deleteCustom({
    required String sectionId,
    required String identifier,
  }) async {
    await _http.request<void>(
      '/hubs/sections/$sectionId/manage/$identifier',
      method: 'DELETE',
    );
  }

  /// `PUT /hubs/sections/{sectionId}/manage/move` — reorder a hub
  /// within the section. Pass [afterIdentifier] empty to move to
  /// the start.
  Future<void> move({
    required String sectionId,
    required String identifier,
    String afterIdentifier = '',
  }) async {
    await _http.request<void>(
      '/hubs/sections/$sectionId/manage/move',
      method: 'PUT',
      queryParameters: {
        'identifier': identifier,
        'after': afterIdentifier,
      },
    );
  }

  /// `DELETE /hubs/sections/{sectionId}/manage` — reset the
  /// section's hub configuration to defaults (deletes every custom
  /// hub and restores built-in ordering).
  Future<void> resetSection({required String sectionId}) async {
    await _http.request<void>(
      '/hubs/sections/$sectionId/manage',
      method: 'DELETE',
    );
  }

  /// Drill into a single hub — `/hubs/{hubIdentifier}/items` or the
  /// `more` link from a [PlexHub] with `hub.more == true`.
  ///
  /// [hubKeyOrIdentifier] is one of:
  ///   - `hub.hubKey`  (a path like `/library/sections/3/recentlyAdded`)
  ///   - `hub.hubIdentifier` (a token like `library.recentlyAdded.3`)
  Future<List<PlexMetadata>> drill({
    required String hubKeyOrIdentifier,
    int start = 0,
    int size = 50,
  }) async {
    // hubKey is already a path; identifier needs the /hubs/{}/items wrap.
    final path = hubKeyOrIdentifier.startsWith('/')
        ? hubKeyOrIdentifier
        : '/hubs/$hubKeyOrIdentifier/items';
    return _http.requestJson(
      path,
      queryParameters: {
        'X-Plex-Container-Start': start,
        'X-Plex-Container-Size': size,
      },
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }
}
