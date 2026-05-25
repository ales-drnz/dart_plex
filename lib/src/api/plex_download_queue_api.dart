// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';

/// `/downloadQueue/*` — legacy mobile-sync download queue.
///
/// Wraps the `Download Queue` OpenAPI tag (9 operations). Plex's
/// mobile apps historically used this surface to maintain an
/// offline copy of media on the device. New clients should prefer
/// the [PlexStreamingApi] / [PlexPlayQueuesApi] flow; this sub-API
/// exists so older mobile workflows can still be driven from Dart.
class PlexDownloadQueueApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.downloadQueue].
  PlexDownloadQueueApi(this._http);

  /// `POST /downloadQueue` — create a new download queue.
  Future<Map<String, dynamic>> create() async {
    final res = await _http.request<Map<String, dynamic>>(
      '/downloadQueue',
      method: 'POST',
    );
    return res.data ?? const {};
  }

  /// `GET /downloadQueue/{queueId}` — fetch a queue's status.
  Future<Map<String, dynamic>> get(String queueId) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/downloadQueue/$queueId',
    );
    return res.data ?? const {};
  }

  /// `POST /downloadQueue/{queueId}/add?keys={ratingKeysJoinedByComma}` —
  /// queue items for offline sync.
  Future<void> add({
    required String queueId,
    required List<String> keys,
  }) async {
    await _http.request<void>(
      '/downloadQueue/$queueId/add',
      method: 'POST',
      queryParameters: {'keys': keys.join(',')},
    );
  }

  /// `GET /downloadQueue/{queueId}/items` — every item in the queue.
  Future<Map<String, dynamic>> items(String queueId) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/downloadQueue/$queueId/items',
    );
    return res.data ?? const {};
  }

  /// `GET /downloadQueue/{queueId}/items/{itemId}` — one queued
  /// item.
  Future<Map<String, dynamic>> item({
    required String queueId,
    required String itemId,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/downloadQueue/$queueId/items/$itemId',
    );
    return res.data ?? const {};
  }

  /// `DELETE /downloadQueue/{queueId}/items/{itemId}` — remove an
  /// item from the queue.
  Future<void> remove({
    required String queueId,
    required String itemId,
  }) async {
    await _http.request<void>(
      '/downloadQueue/$queueId/items/$itemId',
      method: 'DELETE',
    );
  }

  /// `POST /downloadQueue/{queueId}/items/{itemId}/restart` —
  /// re-run the decision step (re-evaluate which version of the
  /// item to grab).
  Future<void> restart({
    required String queueId,
    required String itemId,
  }) async {
    await _http.request<void>(
      '/downloadQueue/$queueId/items/$itemId/restart',
      method: 'POST',
    );
  }

  /// `GET /downloadQueue/{queueId}/item/{itemId}/decision` — the
  /// decision document for a queued item (which media source, what
  /// transcode profile).
  Future<Map<String, dynamic>> itemDecision({
    required String queueId,
    required String itemId,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/downloadQueue/$queueId/item/$itemId/decision',
    );
    return res.data ?? const {};
  }

  /// `GET /downloadQueue/{queueId}/item/{itemId}/media` — the media
  /// payload (used by the mobile downloader to fetch bytes).
  Future<Map<String, dynamic>> itemMedia({
    required String queueId,
    required String itemId,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/downloadQueue/$queueId/item/$itemId/media',
    );
    return res.data ?? const {};
  }
}
