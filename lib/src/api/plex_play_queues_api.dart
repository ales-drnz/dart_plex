// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';
import '../plex_models.dart';

/// `/playQueues/*` — Plex's canonical playback queue model.
///
/// A play queue is what survives across clients in a Plex session: it
/// holds the currently-playing item, what's next, and any shuffled
/// order. Casting from your phone to a TV reuses the same queue; the
/// queue ID also drives Plex's "Resume" behaviour across devices.
///
/// You don't strictly need queues for local-only playback (just use
/// `library` + `streaming`), but if you want cast-friendly state,
/// "Up Next" persistence, or party-mode add-to-queue from another
/// device, this is the API.
class PlexPlayQueuesApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.playQueues].
  PlexPlayQueuesApi(this._http);

  /// `POST /playQueues` — create a new queue from a single item, an
  /// album, an artist (with `allLeaves` semantics), or an arbitrary
  /// list of rating keys.
  ///
  /// [type] is `'audio' | 'video' | 'photo'`.
  ///
  /// [uri] is the Plex queue URI to seed from. Build it from a list of
  /// rating keys with [seedFromItems], or pass `'server://{machineId}'
  /// '/com.plexapp.plugins.library/library/metadata/{id}'` to start
  /// from one item.
  ///
  /// Returns a [PlexPlayQueue] carrying the server-assigned queue id
  /// (needed by every subsequent call: [items], [addItems],
  /// [removeItem], …) plus the queue's initial contents.
  Future<PlexPlayQueue> create({
    required String type,
    required String uri,
    bool shuffle = false,
    bool repeat = false,
    bool continuous = true,
    bool includeChapters = false,
    int? playQueueItemId,
  }) async {
    final qp = <String, dynamic>{
      'type': type,
      'uri': uri,
      'shuffle': shuffle ? 1 : 0,
      'repeat': repeat ? 1 : 0,
      'continuous': continuous ? 1 : 0,
      'includeChapters': includeChapters ? 1 : 0,
    };
    if (playQueueItemId != null) qp['playQueueItemID'] = playQueueItemId;
    final res = await _http.request<Map<String, dynamic>>(
      '/playQueues',
      method: 'POST',
      queryParameters: qp,
    );
    return PlexPlayQueue.fromJson(res.data ?? const {});
  }

  /// `GET /playQueues/{id}` — retrieve the current queue contents.
  Future<List<PlexMetadata>> items({
    required int playQueueId,
    bool includeChapters = false,
    int? center,
    int? window,
  }) async {
    final qp = <String, dynamic>{
      'includeChapters': includeChapters ? 1 : 0,
    };
    if (center != null) qp['center'] = center;
    if (window != null) qp['window'] = window;
    final res = await _http.request<Map<String, dynamic>>(
      '/playQueues/$playQueueId',
      queryParameters: qp,
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `PUT /playQueues/{id}?uri=...` (or `?playlistID=...`) — append
  /// items to the queue. Pass [playNext] = true to splice the items
  /// right after the currently-playing entry instead of at the end.
  ///
  /// Provide exactly one of [uri] or [playlistId]. They are mutually
  /// exclusive per the upstream spec.
  Future<void> addItems({
    required int playQueueId,
    String? uri,
    String? playlistId,
    bool playNext = false,
  }) async {
    assert(
      (uri == null) != (playlistId == null),
      'Pass exactly one of uri or playlistId.',
    );
    final qp = <String, dynamic>{
      if (uri != null) 'uri': uri,
      if (playlistId != null) 'playlistID': playlistId,
      if (playNext) 'next': 1,
    };
    await _http.request<void>(
      '/playQueues/$playQueueId',
      method: 'PUT',
      queryParameters: qp,
    );
  }

  /// `PUT /playQueues/{id}/items/{playQueueItemId}/move?after={otherId}`
  /// — reorder the queue. Pass [afterPlaylistItemId] = 0 to move the
  /// item to the very start.
  Future<void> moveItem({
    required int playQueueId,
    required int playQueueItemId,
    required int afterPlaylistItemId,
  }) async {
    await _http.request<void>(
      '/playQueues/$playQueueId/items/$playQueueItemId/move',
      method: 'PUT',
      queryParameters: {'after': afterPlaylistItemId},
    );
  }

  /// `DELETE /playQueues/{id}/items/{playQueueItemId}` — remove one
  /// entry from the queue.
  Future<void> removeItem({
    required int playQueueId,
    required int playQueueItemId,
  }) async {
    await _http.request<void>(
      '/playQueues/$playQueueId/items/$playQueueItemId',
      method: 'DELETE',
    );
  }

  /// `PUT /playQueues/{id}/shuffle` — randomize the queue order.
  Future<void> shuffle(int playQueueId) async {
    await _http.request<void>(
      '/playQueues/$playQueueId/shuffle',
      method: 'PUT',
    );
  }

  /// `PUT /playQueues/{id}/unshuffle` — restore the original order.
  Future<void> unshuffle(int playQueueId) async {
    await _http.request<void>(
      '/playQueues/$playQueueId/unshuffle',
      method: 'PUT',
    );
  }

  /// `DELETE /playQueues/{id}/items` — clear every item from the
  /// queue. The queue itself stays alive (its id remains valid),
  /// only the contents are removed.
  Future<void> clear(int playQueueId) async {
    await _http.request<void>(
      '/playQueues/$playQueueId/items',
      method: 'DELETE',
    );
  }

  /// `PUT /playQueues/{id}/reset` — rewind the queue so the first
  /// item is the current item again. Does not change the queue
  /// contents.
  Future<void> reset(int playQueueId) async {
    await _http.request<void>(
      '/playQueues/$playQueueId/reset',
      method: 'PUT',
    );
  }

  /// Build a "seed from a list of items" URI suitable for [create] and
  /// [addItems]. The server identifier comes from
  /// [PlexServerApi.identity] (`machineIdentifier`).
  static String seedFromItems({
    required String machineIdentifier,
    required List<String> ratingKeys,
  }) =>
      'server://$machineIdentifier/com.plexapp.plugins.library'
      '/library/metadata/${ratingKeys.join(',')}';
}
