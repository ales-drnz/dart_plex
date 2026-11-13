// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_events.dart';
import 'plex_play_queues_api.dart';

/// `/:/timeline`, `/:/scrobble`, `/:/unscrobble`, `/:/rate`.
///
/// Scrobble, unscrobble and rate go out as `PUT`, as the current API
/// document asks; PMS 1.43.2 also still answers `GET` (both verified).
///
/// Plex doesn't have an "is favorite" flag — favorites are encoded as
/// `userRating == 10` (i.e. five stars). Use [setFavorite] for the
/// convention and [rate] for arbitrary ratings.
///
/// {@category Playback and play queues}
class PlexPlaybackApi {
  static const String _libraryIdentifier = 'com.plexapp.plugins.library';

  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.playback].
  PlexPlaybackApi(this._http);

  /// Report a playback heartbeat (`/:/timeline`). Send one on every state
  /// change plus a periodic progress tick — Plex recommends every 10 s on
  /// LAN, 20 s on cellular.
  ///
  /// [timeMs] is the playhead and [durationMs] the item's length, both in
  /// milliseconds. [playState] is what the player is doing. [ratingKey]
  /// is the item's rating key; `key` is sent as
  /// `/library/metadata/{ratingKey}`. [playQueueItemID] is the entry id of
  /// a server-side play queue ([PlexPlayQueuesApi]); leave it null when
  /// you are not playing one — never send a made-up value.
  ///
  /// ## What makes PMS count a play
  ///
  /// Measured on PMS 1.43.2 (music, `viewCount` and the history). The
  /// 50% figures came from a library with full-length tracks; the
  /// integration seed's 3 s tracks only reproduce the duration rules.
  ///
  /// * The server clocks the session itself. Reports must follow real
  ///   time: a `playing` at 0 and a `stopped` at the end two seconds later
  ///   counts nothing, however far `time` says the playhead moved.
  /// * About half the track must be heard: stopping at 50% of a 60 s track
  ///   counted, at 40% it did not, and 35 s of a 120 s track did not.
  /// * [durationMs] must be the real length. With `duration=0` nothing is
  ///   ever counted, even when the whole track plays in real time — which
  ///   is why this method refuses a non-positive duration.
  /// * PMS judges the *reported* [durationMs] against real time, not the
  ///   file: a 3 s track reported with its true length and played in full
  ///   was not counted, the same file reported as 20 s and played for
  ///   16 s was. The exact floor was not measured.
  ///
  /// A counted play raises `viewCount`, sets `lastViewedAt` and adds an
  /// entry to `/status/sessions/history/all`. [scrobble] raises `viewCount`
  /// without a history entry — use it for "mark as played", not to report
  /// listening.
  ///
  /// A [timeMs] past [durationMs] (a playhead that rounds past the end) is
  /// sent as [durationMs]: PMS answers 400 to `time > duration`.
  ///
  /// Throws an [ArgumentError] when [durationMs] is not positive, [timeMs]
  /// is negative or [playState] is [PlexPlayState.unknown].
  Future<void> timeline({
    required String ratingKey,
    required PlexPlayState playState,
    required int timeMs,
    required int durationMs,
    int? playQueueItemID,
    bool continuing = false,
  }) async {
    if (playState == PlexPlayState.unknown) {
      throw ArgumentError.value(playState, 'playState', 'is not reportable');
    }
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
    await _http.request<void>(
      '/:/timeline',
      queryParameters: {
        'ratingKey': ratingKey,
        'key': '/library/metadata/$ratingKey',
        'state': playState.wire,
        'time': timeMs > durationMs ? durationMs : timeMs,
        'duration': durationMs,
        'continuing': continuing ? 1 : 0,
        'playQueueItemID': ?playQueueItemID,
      },
    );
  }

  /// Mark an item as played (`PUT /:/scrobble`): raises `viewCount` by
  /// one without adding a history entry. To report listening, send
  /// [timeline] reports instead (see there for what PMS counts).
  Future<void> scrobble({required String ratingKey}) async {
    await _http.request<void>(
      '/:/scrobble',
      method: 'PUT',
      queryParameters: {'key': ratingKey, 'identifier': _libraryIdentifier},
    );
  }

  /// Mark an item as unplayed (`PUT /:/unscrobble`): clears `viewCount`.
  /// The play history is kept.
  Future<void> unscrobble({required String ratingKey}) async {
    await _http.request<void>(
      '/:/unscrobble',
      method: 'PUT',
      queryParameters: {'key': ratingKey, 'identifier': _libraryIdentifier},
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
  }) => rate(ratingKey: ratingKey, rating: isFavorite ? 10 : 0);
}
