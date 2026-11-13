// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_exception.dart';
import '../plex_models.dart';
import '../plex_parsing.dart';
import '../plex_urls.dart';

/// `/livetv/*` — Plex Live TV and DVR.
///
/// Wraps the consumer-facing slice (sessions, DVRs, subscriptions).
/// Tuner / EPG / device-grabber configuration lives behind the
/// escape hatch — those endpoints are admin-only and unlikely to
/// belong in a music+video app.
///
/// {@category Live TV}
class PlexLiveTvApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.liveTv].
  PlexLiveTvApi(this._http);

  /// `GET /livetv/sessions` — currently-streaming Live TV sessions, as the
  /// items being watched.
  Future<List<PlexMetadata>> sessions() => _http.requestJson(
    '/livetv/sessions',
    itemsOf('Metadata', PlexMetadata.fromJson),
  );

  /// `GET /livetv/dvrs` — configured DVR backends.
  Future<List<PlexDvr>> dvrs() => _http.requestJson(
    '/livetv/dvrs',
    entriesOf('Dvr', PlexDvr.fromJson, altKey: 'DVR'),
  );

  /// Helper to drill into the EPG inside a Live TV DVR: [dvrKey] is
  /// [PlexDvr.key]. Returns the channel listing.
  Future<List<PlexMetadata>> dvrChannels({required String dvrKey}) =>
      _http.requestJson(
        '$dvrKey/channels',
        itemsOf('Metadata', PlexMetadata.fromJson),
      );

  // ---------------------------------------------------------------------------
  // Live session reads / segments
  // ---------------------------------------------------------------------------

  /// `GET /livetv/sessions/{sessionId}` — a single live session, as the
  /// item being watched (with the tuned channel in its media), or `null`
  /// when the answer holds none.
  Future<PlexMetadata?> liveSession({required String sessionId}) async =>
      _http.requestJson(
        '/livetv/sessions/${seg(sessionId)}',
        (json) => PlexMediaContainer.fromJson(
          json is Map<String, Object?> ? json : const {},
          'Metadata',
          PlexMetadata.fromJson,
        ).items.firstOrNull,
      );

  /// `GET /livetv/sessions/{sessionId}/{consumerId}/index.m3u8` —
  /// URL for the HLS playlist of one consumer attached to a live
  /// session.
  ///
  /// The URL carries the token, when there is one: do not log it. Throws
  /// a `state` [PlexException] before [PlexClient.connect].
  String sessionPlaylistUrl({
    required String sessionId,
    required String consumerId,
  }) => _http.signedUrl(
    '/livetv/sessions/${seg(sessionId)}/${seg(consumerId)}/index.m3u8',
  );

  /// `GET /livetv/sessions/{sessionId}/{consumerId}/{segmentId}` —
  /// URL for one HLS segment of the live session.
  ///
  /// The URL carries the token, when there is one: do not log it. Throws
  /// a `state` [PlexException] before [PlexClient.connect].
  String sessionSegmentUrl({
    required String sessionId,
    required String consumerId,
    required String segmentId,
  }) => _http.signedUrl(
    '/livetv/sessions/${seg(sessionId)}/${seg(consumerId)}/${seg(segmentId)}',
  );
}
