// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';

/// `/:/timeline`, `/:/scrobble`, `/:/unscrobble`, `/:/rate`.
///
/// Plex doesn't have an "is favorite" flag — favorites are encoded as
/// `userRating == 10` (i.e. five stars). Use [setFavorite] for the
/// convention and [rate] for arbitrary ratings.
class PlexPlaybackApi {
  static const String _libraryIdentifier = 'com.plexapp.plugins.library';

  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.playback].
  PlexPlaybackApi(this._http);

  /// `'stopped'` — playback ended or was cancelled.
  static const String stateStopped = 'stopped';

  /// `'paused'` — playback is paused but the session is still alive.
  static const String statePaused = 'paused';

  /// `'playing'` — playback is actively progressing.
  static const String statePlaying = 'playing';

  /// `'buffering'` — playback is stalled while the player refills its buffer.
  static const String stateBuffering = 'buffering';

  /// Report a playback heartbeat. Send on every state change plus a
  /// periodic progress tick — Plex recommends every 10 s on LAN,
  /// 20 s on cellular.
  ///
  /// [time] / [duration] are milliseconds. [ratingKey] is the item's
  /// rating key; [key] is `/library/metadata/{ratingKey}`.
  Future<void> timeline({
    required String ratingKey,
    required String state,
    required int timeMs,
    required int durationMs,
    String? playQueueItemId,
    bool continuing = false,
  }) async {
    final qp = <String, dynamic>{
      'ratingKey': ratingKey,
      'key': '/library/metadata/$ratingKey',
      'state': state,
      'time': timeMs,
      'duration': durationMs,
      'continuing': continuing ? 1 : 0,
    };
    if (playQueueItemId != null) qp['playQueueItemID'] = playQueueItemId;
    await _http.request<void>('/:/timeline', queryParameters: qp);
  }

  /// Mark an item as watched (`/:/scrobble`).
  Future<void> scrobble(String ratingKey) async {
    await _http.request<void>(
      '/:/scrobble',
      queryParameters: {
        'key': ratingKey,
        'identifier': _libraryIdentifier,
      },
    );
  }

  /// Mark an item as unwatched (`/:/unscrobble`).
  Future<void> unscrobble(String ratingKey) async {
    await _http.request<void>(
      '/:/unscrobble',
      queryParameters: {
        'key': ratingKey,
        'identifier': _libraryIdentifier,
      },
    );
  }

  /// Set the user rating for an item, 0..10 (audio uses 0–10 in half-star
  /// increments). Pass 0 to clear.
  Future<void> rate({required String ratingKey, required double rating}) async {
    await _http.request<void>(
      '/:/rate',
      queryParameters: {
        'key': ratingKey,
        'identifier': _libraryIdentifier,
        'rating': rating,
      },
    );
  }

  /// Convention helper: favourite = rating 10, un-favourite = rating 0.
  Future<void> setFavorite({
    required String ratingKey,
    required bool isFavorite,
  }) =>
      rate(ratingKey: ratingKey, rating: isFavorite ? 10 : 0);
}
