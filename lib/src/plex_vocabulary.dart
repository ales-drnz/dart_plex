// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The words Plex's list and playback endpoints take — sort keys, media
/// types, marker types, streaming protocols — as types instead of
/// strings.
///
/// PMS ignores a value it does not know and answers 200 anyway: a
/// misspelt `sort=titelSort` comes back in library order, unsorted. A
/// typed value makes the misspelling a compile error. The open sets
/// (sort keys, media and marker types) are extension types over the wire
/// string, so a value this package does not list yet is one constructor
/// away: `PlexSort('mediaBitrate')`. The closed ones are enums.
library;

import 'api/plex_account_api.dart';
import 'api/plex_streaming_api.dart';
import 'plex_models.dart';

/// A sort order, as sent in `sort`: a field, optionally with `:asc` or
/// `:desc`, several joined with `,`.
///
/// ```dart
/// plex.library.allByType(
///   sectionId: id,
///   type: PlexMetadataType.album,
///   sort: PlexSort.addedAt.desc,
/// );
/// ```
///
/// Which fields a section sorts by is the section's to say: the
/// constants are the ones PMS 1.43.2 offers on music and movie sections
/// (`/library/sections/{id}/sorts`, or `includeMeta=1`), plus the
/// watchlist's [watchlistedAt]. Any other is `PlexSort('field')`.
///
/// {@category Library}
extension type const PlexSort(String wire) implements String {
  /// `titleSort` — by sort title, A to Z.
  static const titleSort = PlexSort('titleSort');

  /// `addedAt` — when the item was added.
  static const addedAt = PlexSort('addedAt');

  /// `updatedAt` — when its metadata last changed.
  static const updatedAt = PlexSort('updatedAt');

  /// `lastViewedAt` — when it was last played.
  static const lastViewedAt = PlexSort('lastViewedAt');

  /// `lastRatedAt` — when it was last rated.
  static const lastRatedAt = PlexSort('lastRatedAt');

  /// `originallyAvailableAt` — release date.
  static const originallyAvailableAt = PlexSort('originallyAvailableAt');

  /// `year`.
  static const year = PlexSort('year');

  /// `rating` — critic rating.
  static const rating = PlexSort('rating');

  /// `audienceRating`.
  static const audienceRating = PlexSort('audienceRating');

  /// `userRating` — the user's own rating.
  static const userRating = PlexSort('userRating');

  /// `ratingCount` — how many ratings (popularity, on tracks).
  static const ratingCount = PlexSort('ratingCount');

  /// `viewCount` — plays.
  static const viewCount = PlexSort('viewCount');

  /// `skipCount` — skips.
  static const skipCount = PlexSort('skipCount');

  /// `duration`.
  static const duration = PlexSort('duration');

  /// `index` — position in the parent (track number, episode number).
  static const index = PlexSort('index');

  /// `mediaHeight` — video resolution.
  static const mediaHeight = PlexSort('mediaHeight');

  /// `mediaBitrate`.
  static const mediaBitrate = PlexSort('mediaBitrate');

  /// `mediaSize` — file size.
  static const mediaSize = PlexSort('mediaSize');

  /// `random` — a shuffled order.
  static const random = PlexSort('random');

  /// `watchlistedAt` — when the item was added to the watchlist
  /// ([PlexAccountApi.watchlist] only).
  static const watchlistedAt = PlexSort('watchlistedAt');

  /// The same field, ascending (`field:asc`).
  PlexSort get asc => PlexSort('${_field(wire)}:asc');

  /// The same field, descending (`field:desc`).
  PlexSort get desc => PlexSort('${_field(wire)}:desc');

  /// This order, then [next] for ties (`a,b`).
  PlexSort then(PlexSort next) => PlexSort('$wire,${next.wire}');

  static String _field(String wire) {
    final colon = wire.lastIndexOf(':');
    return colon < 0 || wire.contains(',') ? wire : wire.substring(0, colon);
  }
}

/// A media type, as sent in a playlist's or play queue's `type` and
/// `playlistType`: `audio`, `video` or `photo`.
///
/// {@category Playlists}
extension type const PlexMediaType(String wire) implements String {
  /// `audio` — music.
  static const audio = PlexMediaType('audio');

  /// `video` — movies, episodes, clips.
  static const video = PlexMediaType('video');

  /// `photo`.
  static const photo = PlexMediaType('photo');
}

/// The kind of a [PlexMarker], as in `Marker.type` and the marker
/// endpoints' `type`.
///
/// {@category Library}
extension type const PlexMarkerType(String wire) implements String {
  /// `intro` — a show's opening, to skip.
  static const intro = PlexMarkerType('intro');

  /// `credits` — the end credits.
  static const credits = PlexMarkerType('credits');

  /// `commercial` — an ad break (Live TV recordings, with commercial
  /// detection on).
  static const commercial = PlexMarkerType('commercial');

  /// `bookmark` — a user bookmark.
  static const bookmark = PlexMarkerType('bookmark');

  /// `resume` — a resume point.
  static const resume = PlexMarkerType('resume');
}

/// How a transcode reaches the player, as in `protocol` on the universal
/// transcoder ([PlexStreamingApi.startVideoTranscode],
/// [PlexStreamingApi.startAudioTranscode]).
///
/// {@category Streaming}
enum PlexStreamingProtocol {
  /// HLS: an `.m3u8` playlist of MPEG-TS segments. The default, and what
  /// AVPlayer and ExoPlayer play natively.
  hls('hls', 'm3u8', 'mpegts'),

  /// MPEG-DASH: an `.mpd` manifest of fragmented MP4 segments.
  dash('dash', 'mpd', 'mp4'),

  /// One progressive stream over plain HTTP, in a Matroska container for
  /// video (no seeking past what has been transcoded).
  http('http', 'mkv', 'mkv');

  /// The `protocol` value.
  final String wire;

  /// The extension of the `start` URL (`start.m3u8`, …).
  final String extension;

  /// The container the transcoder writes for video.
  final String videoContainer;

  const PlexStreamingProtocol(this.wire, this.extension, this.videoContainer);
}

/// Which part of the watchlist [PlexAccountApi.watchlist] lists.
///
/// {@category Client and sign-in}
enum PlexWatchlistFilter {
  /// Everything on it.
  all,

  /// What can be watched now on one of the user's servers or services.
  available,

  /// What has been released.
  released,
}
