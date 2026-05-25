// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';
import '../plex_models.dart';

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
    final res = await _http.request<Map<String, dynamic>>(
      '/hubs',
      queryParameters: {
        'count': count,
        'onlyTransient': onlyTransient ? 1 : 0,
        'includeMeta': includeMeta ? 1 : 0,
      },
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Hub',
      PlexHub.fromJson,
    ).items;
  }

  /// Hubs scoped to a single library section (`/hubs/sections/{id}`).
  ///
  /// [count] caps each hub's item list. [excludeFields] / [includeMeta]
  /// follow the upstream contract.
  Future<List<PlexHub>> forSection({
    required String sectionId,
    int count = 16,
    bool onlyTransient = false,
    bool includeMeta = true,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/hubs/sections/$sectionId',
      queryParameters: {
        'count': count,
        'onlyTransient': onlyTransient ? 1 : 0,
        'includeMeta': includeMeta ? 1 : 0,
      },
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Hub',
      PlexHub.fromJson,
    ).items;
  }

  /// `/hubs/promoted` — the small set the server flags as "feature me
  /// prominently".
  Future<List<PlexHub>> promoted({int count = 16}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/hubs/promoted',
      queryParameters: {'count': count},
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Hub',
      PlexHub.fromJson,
    ).items;
  }

  /// `/hubs/continueWatching` — Plex's "On Deck" / "Continue Listening"
  /// rail merged across libraries.
  Future<List<PlexMetadata>> continueWatching({int count = 16}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/hubs/continueWatching',
      queryParameters: {'count': count},
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `/hubs/sections/{id}/onDeck` — per-library "Up Next".
  Future<List<PlexMetadata>> sectionOnDeck({
    required String sectionId,
    int count = 16,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/onDeck',
      queryParameters: {
        'X-Plex-Container-Start': 0,
        'X-Plex-Container-Size': count,
      },
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `/hubs/items?identifier={id}` — drill into a hub by its
  /// `identifier` (a token like `library.recentlyAdded.3`).
  Future<List<PlexMetadata>> itemsByIdentifier({
    required String identifier,
    int start = 0,
    int size = 50,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/hubs/items',
      queryParameters: {
        'identifier': identifier,
        'X-Plex-Container-Start': start,
        'X-Plex-Container-Size': size,
      },
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `/hubs/metadata/{metadataId}/postplay` — hubs to display after
  /// the user finishes playing this item (next-up suggestions).
  Future<List<PlexHub>> postplay({
    required String metadataId,
    bool? onlyTransient,
  }) async {
    final qp = <String, dynamic>{};
    if (onlyTransient != null) qp['onlyTransient'] = onlyTransient ? 1 : 0;
    final res = await _http.request<Map<String, dynamic>>(
      '/hubs/metadata/$metadataId/postplay',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Hub',
      PlexHub.fromJson,
    ).items;
  }

  /// `/hubs/metadata/{metadataId}/related` — hubs related to a
  /// specific metadata item.
  Future<List<PlexHub>> related({
    required String metadataId,
    bool? onlyTransient,
  }) async {
    final qp = <String, dynamic>{};
    if (onlyTransient != null) qp['onlyTransient'] = onlyTransient ? 1 : 0;
    final res = await _http.request<Map<String, dynamic>>(
      '/hubs/metadata/$metadataId/related',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Hub',
      PlexHub.fromJson,
    ).items;
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
    final res = await _http.request<Map<String, dynamic>>(
      '/hubs/sections/$sectionId/manage',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Hub',
      PlexHub.fromJson,
    ).items;
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
    final res = await _http.request<Map<String, dynamic>>(
      path,
      queryParameters: {
        'X-Plex-Container-Start': start,
        'X-Plex-Container-Size': size,
      },
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }
}
