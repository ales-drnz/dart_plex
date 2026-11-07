// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';
import '../plex_models.dart';
import 'plex_play_queues_api.dart';
import 'plex_streaming_api.dart';

/// `/downloadQueue/*` — legacy mobile-sync download queue.
///
/// Wraps the `Download Queue` OpenAPI tag (9 operations). Plex's
/// mobile apps historically used this surface to maintain an
/// offline copy of media on the device. New clients should prefer
/// the [PlexStreamingApi] / [PlexPlayQueuesApi] flow; this sub-API
/// exists so older mobile workflows can still be driven from Dart.
///
/// {@category Events and downloads}
class PlexDownloadQueueApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.downloadQueue].
  PlexDownloadQueueApi(this._http);

  /// `POST /downloadQueue` — this client's download queue, created when
  /// it has none (one per client and user; verified on PMS 1.43.2).
  ///
  /// Throws a [PlexException] of type [PlexErrorType.parse] when the
  /// answer holds no queue.
  Future<PlexDownloadQueue> create() =>
      _http.requestJson('/downloadQueue', _created, method: 'POST');

  static PlexDownloadQueue _created(Object? json) {
    final queue = PlexDownloadQueue.listOf(json).firstOrNull;
    if (queue != null) return queue;
    throw const PlexException(
      'The answer holds no DownloadQueue',
      type: PlexErrorType.parse,
    );
  }

  /// `GET /downloadQueue/{queueId}` — a queue's status, or `null` when the
  /// answer holds none.
  Future<PlexDownloadQueue?> get({required int queueId}) => _http.requestJson(
    '/downloadQueue/$queueId',
    (json) => PlexDownloadQueue.listOf(json).firstOrNull,
  );

  /// `POST /downloadQueue/{queueId}/add?keys={ratingKeysJoinedByComma}` —
  /// queue items for offline sync.
  Future<void> add({required int queueId, required List<String> keys}) async {
    await _http.request<void>(
      '/downloadQueue/$queueId/add',
      method: 'POST',
      queryParameters: {'keys': keys.join(',')},
    );
  }

  /// `GET /downloadQueue/{queueId}/items` — every item in the queue, with
  /// its status and decision.
  Future<List<PlexDownloadQueueItem>> items({required int queueId}) =>
      _http.requestJson(
        '/downloadQueue/$queueId/items',
        PlexDownloadQueueItem.listOf,
      );

  /// `GET /downloadQueue/{queueId}/items/{itemId}` — one queued item, or
  /// `null` when the answer holds none.
  Future<PlexDownloadQueueItem?> item({
    required int queueId,
    required int itemId,
  }) => _http.requestJson(
    '/downloadQueue/$queueId/items/$itemId',
    (json) => PlexDownloadQueueItem.listOf(json).firstOrNull,
  );

  /// `DELETE /downloadQueue/{queueId}/items/{itemId}` — remove an
  /// item from the queue.
  Future<void> remove({required int queueId, required int itemId}) async {
    await _http.request<void>(
      '/downloadQueue/$queueId/items/$itemId',
      method: 'DELETE',
    );
  }

  /// `POST /downloadQueue/{queueId}/items/{itemId}/restart` —
  /// re-run the decision step (re-evaluate which version of the
  /// item to grab).
  Future<void> restart({required int queueId, required int itemId}) async {
    await _http.request<void>(
      '/downloadQueue/$queueId/items/$itemId/restart',
      method: 'POST',
    );
  }

  /// `GET /downloadQueue/{queueId}/item/{itemId}/decision` — the
  /// decision for a queued item (which media source, what transcode
  /// profile); [PlexTranscodeDecision.raw] holds the item's metadata.
  Future<PlexTranscodeDecision> itemDecision({
    required int queueId,
    required int itemId,
  }) => _http.requestJson(
    '/downloadQueue/$queueId/item/$itemId/decision',
    _decision,
  );

  static PlexTranscodeDecision _decision(Object? json) {
    final c = json is Map<String, Object?> ? json['MediaContainer'] : null;
    final container = c is Map<String, Object?> ? c : const <String, Object?>{};
    final code = container['generalDecisionCode'];
    return PlexTranscodeDecision(
      code: code is int ? code : int.tryParse('$code'),
      raw: container,
    );
  }

  /// `GET /downloadQueue/{queueId}/item/{itemId}/media` — the URL of the
  /// item's file, once it is `available`: the media itself, not JSON, so
  /// it is a URL (with the token, when there is one) to hand to
  /// `downloadToFile` or [PlexClient.requestStream].
  ///
  /// Throws a [PlexException] of type [PlexErrorType.state] before
  /// [PlexClient.connect].
  String itemMediaUrl({required int queueId, required int itemId}) {
    _http.requireConnected();
    final url = '${_http.baseUrl}/downloadQueue/$queueId/item/$itemId/media';
    final token = _http.token;
    if (token == null) return url;
    return '$url?X-Plex-Token=${Uri.encodeQueryComponent(token)}';
  }
}
