// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_models.dart';
import '../plex_parsing.dart';

/// `/livetv/*` — Plex Live TV and DVR.
///
/// Wraps the consumer-facing slice (sessions, DVRs, subscriptions).
/// Tuner / EPG / device-grabber configuration lives behind the
/// escape hatch — those endpoints are admin-only and unlikely to
/// belong in a music+video app.
class PlexLiveTvApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.liveTv].
  PlexLiveTvApi(this._http);

  /// `GET /livetv/sessions` — currently-streaming Live TV sessions.
  Future<List<Map<String, Object?>>> sessions() async {
    final res = await _http.request<Map<String, Object?>>('/livetv/sessions');
    final container = res.data?['MediaContainer'];
    if (container is! Map<String, Object?>) return const [];
    final list = container['Metadata'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map<String, Object?>) e,
    ];
  }

  /// `GET /livetv/dvrs` — configured DVR backends.
  Future<List<Map<String, Object?>>> dvrs() async {
    final res = await _http.request<Map<String, Object?>>('/livetv/dvrs');
    final container = res.data?['MediaContainer'];
    if (container is! Map<String, Object?>) return const [];
    final list = container['Dvr'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map<String, Object?>) e,
    ];
  }

  /// Helper to drill into the EPG inside a Live TV DVR. The id comes
  /// from [dvrs] → entry's `key` field. Returns the channel listing.
  Future<List<PlexMetadata>> dvrChannels({required String dvrKey}) async {
    return _http.requestJson(
      '$dvrKey/channels',
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  // ---------------------------------------------------------------------------
  // Live session reads / segments
  // ---------------------------------------------------------------------------

  /// `GET /livetv/sessions/{sessionId}` — fetch a single live
  /// session (status, currently-tuned channel, decision).
  Future<Map<String, Object?>> liveSession({required String sessionId}) async {
    final res = await _http.request<Map<String, Object?>>(
      '/livetv/sessions/$sessionId',
    );
    return res.data ?? const {};
  }

  /// `GET /livetv/sessions/{sessionId}/{consumerId}/index.m3u8` —
  /// URL for the HLS playlist of one consumer attached to a live
  /// session.
  String sessionPlaylistUrl({
    required String sessionId,
    required String consumerId,
  }) {
    final base = _http.baseUrl;
    final token = _http.token ?? '';
    return '$base/livetv/sessions/$sessionId/$consumerId/index.m3u8?X-Plex-Token=$token';
  }

  /// `GET /livetv/sessions/{sessionId}/{consumerId}/{segmentId}` —
  /// URL for one HLS segment of the live session.
  String sessionSegmentUrl({
    required String sessionId,
    required String consumerId,
    required String segmentId,
  }) {
    final base = _http.baseUrl;
    final token = _http.token ?? '';
    return '$base/livetv/sessions/$sessionId/$consumerId/$segmentId?X-Plex-Token=$token';
  }
}
