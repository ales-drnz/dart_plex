// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';
import '../plex_events.dart';

/// `/:/timeline`, `/:/scrobble`, `/:/unscrobble`, `/:/rate`.
///
/// Scrobble, unscrobble and rate go out as `PUT`, as the current API
/// document asks; PMS 1.43.2 also still answers `GET` (both verified).
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
  @Deprecated('Use PlexPlayState.stopped')
  static const String stateStopped = 'stopped';

  /// `'paused'` — playback is paused but the session is still alive.
  @Deprecated('Use PlexPlayState.paused')
  static const String statePaused = 'paused';

  /// `'playing'` — playback is actively progressing.
  @Deprecated('Use PlexPlayState.playing')
  static const String statePlaying = 'playing';

  /// `'buffering'` — playback is stalled while the player refills its buffer.
  @Deprecated('Use PlexPlayState.buffering')
  static const String stateBuffering = 'buffering';

  /// Report a playback heartbeat (`/:/timeline`). Send one on every state
  /// change plus a periodic progress tick — Plex recommends every 10 s on
  /// LAN, 20 s on cellular.
  ///
  /// [timeMs] is the playhead and [durationMs] the item's length, both in
  /// milliseconds. [playState] is what the player is doing (the `String`
  /// [state] is deprecated). [ratingKey] is the item's rating key; `key`
  /// is sent as
  /// `/library/metadata/{ratingKey}`. [playQueueItemID] is the entry id of
  /// a server-side play queue ([PlexPlayQueuesApi]); leave it null when
  /// you are not playing one — never send a made-up value.
  ///
  /// ## What makes PMS count a play
  ///
  /// Measured on PMS 1.43.2 (music, `viewCount` and the history):
  ///
  /// * The server clocks the session itself. Reports must follow real
  ///   time: a `playing` at 0 and a `stopped` at the end two seconds later
  ///   counts nothing, however far `time` says the playhead moved.
  /// * About half the track must be heard: stopping at 50% of a 60 s track
  ///   counted, at 40% it did not, and 35 s of a 120 s track did not.
  /// * [durationMs] must be the real length. With `duration=0` nothing is
  ///   ever counted, even when the whole track plays in real time — which
  ///   is why this method refuses a non-positive duration.
  /// * Very short tracks are never counted (a 3 s track played in full was
  ///   not); the exact floor was not measured.
  ///
  /// A counted play raises `viewCount`, sets `lastViewedAt` and adds an
  /// entry to `/status/sessions/history/all`. [scrobble] raises `viewCount`
  /// without a history entry — use it for "mark as played", not to report
  /// listening.
  ///
  /// Throws an [ArgumentError] when [durationMs] is not positive or
  /// [timeMs] is negative.
  Future<void> timeline({
    required String ratingKey,
    PlexPlayState? playState,
    @Deprecated('Use playState (a PlexPlayState)') String? state,
    required int timeMs,
    required int durationMs,
    int? playQueueItemID,
    @Deprecated('Use playQueueItemID (an int)') String? playQueueItemId,
    bool continuing = false,
  }) async {
    if ((playState == null) == (state == null)) {
      throw ArgumentError('Pass exactly one of playState and state.');
    }
    if (playState == PlexPlayState.unknown) {
      throw ArgumentError.value(playState, 'playState', 'is not reportable');
    }
    final wireState = playState?.wire ?? state!;
    if (durationMs <= 0) {
      throw ArgumentError.value(
        durationMs,
        'durationMs',
        'must be the track length in ms; PMS never counts a play reported '
            'with duration 0',
      );
    }
    if (timeMs < 0) {
      throw ArgumentError.value(timeMs, 'timeMs', 'must not be negative');
    }
    if (playQueueItemID != null && playQueueItemId != null) {
      throw ArgumentError(
        'Pass playQueueItemID or the deprecated playQueueItemId, not both.',
      );
    }
    final queueItem = playQueueItemID?.toString() ?? playQueueItemId;
    final qp = <String, dynamic>{
      'ratingKey': ratingKey,
      'key': '/library/metadata/$ratingKey',
      'state': wireState,
      'time': timeMs,
      'duration': durationMs,
      'continuing': continuing ? 1 : 0,
    };
    if (queueItem != null) qp['playQueueItemID'] = queueItem;
    await _http.request<void>('/:/timeline', queryParameters: qp);
  }

  /// Mark an item as played (`PUT /:/scrobble`): raises `viewCount` by
  /// one without adding a history entry. To report listening, send
  /// [timeline] reports instead (see there for what PMS counts).
  Future<void> scrobble(String ratingKey) async {
    await _http.request<void>(
      '/:/scrobble',
      method: 'PUT',
      queryParameters: {
        'key': ratingKey,
        'identifier': _libraryIdentifier,
      },
    );
  }

  /// Mark an item as unplayed (`PUT /:/unscrobble`): clears `viewCount`.
  /// The play history is kept.
  Future<void> unscrobble(String ratingKey) async {
    await _http.request<void>(
      '/:/unscrobble',
      method: 'PUT',
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
      method: 'PUT',
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
