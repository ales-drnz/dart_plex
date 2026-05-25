// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';
import '../plex_models.dart';

/// `/livetv/*` — Plex Live TV and DVR.
///
/// Wraps the consumer-facing slice (sessions, DVRs, subscriptions).
/// Tuner / EPG / device-grabber configuration lives behind the
/// escape hatch — those endpoints are admin-only and unlikely to
/// belong in a music+video app.
class PlexLiveTvApi {
  final PlexConnection _http;

  PlexLiveTvApi(this._http);

  /// `GET /livetv/sessions` — currently-streaming Live TV sessions.
  Future<List<Map<String, dynamic>>> sessions() async {
    final res = await _http.request<Map<String, dynamic>>('/livetv/sessions');
    final container = res.data?['MediaContainer'];
    if (container is! Map<String, dynamic>) return const [];
    final list = container['Metadata'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) e,
    ];
  }

  /// `GET /livetv/dvrs` — configured DVR backends.
  Future<List<Map<String, dynamic>>> dvrs() async {
    final res = await _http.request<Map<String, dynamic>>('/livetv/dvrs');
    final container = res.data?['MediaContainer'];
    if (container is! Map<String, dynamic>) return const [];
    final list = container['Dvr'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) e,
    ];
  }

  /// `GET /livetv/subscriptions` — recording subscriptions (single +
  /// series). Each entry carries a `key`, `type`, `subscriptionType`,
  /// linked metadata, schedule info.
  Future<List<Map<String, dynamic>>> subscriptions() async {
    final res = await _http.request<Map<String, dynamic>>(
      '/livetv/subscriptions',
    );
    final container = res.data?['MediaContainer'];
    if (container is! Map<String, dynamic>) return const [];
    final list = container['MediaSubscription'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) e,
    ];
  }

  /// `DELETE /livetv/subscriptions/{key}` — cancel a recording
  /// subscription.
  Future<void> cancelSubscription(String key) async {
    await _http.request<void>(
      '/livetv/subscriptions/$key',
      method: 'DELETE',
    );
  }

  /// `GET /livetv/sessions/history/all` — past Live TV viewing
  /// history. Same shape as `sessions.history()` for VOD.
  Future<List<Map<String, dynamic>>> history({
    int start = 0,
    int size = 50,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/livetv/sessions/history/all',
      queryParameters: {
        'X-Plex-Container-Start': start,
        'X-Plex-Container-Size': size,
      },
    );
    final container = res.data?['MediaContainer'];
    if (container is! Map<String, dynamic>) return const [];
    final list = container['Metadata'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) e,
    ];
  }

  /// Helper to drill into the EPG inside a Live TV DVR. The id comes
  /// from [dvrs] → entry's `key` field. Returns the channel listing.
  Future<List<PlexMetadata>> dvrChannels(String dvrKey) async {
    final res = await _http.request<Map<String, dynamic>>(
      '$dvrKey/channels',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  // ---------------------------------------------------------------------------
  // Live session reads / segments
  // ---------------------------------------------------------------------------

  /// `GET /livetv/sessions/{sessionId}` — fetch a single live
  /// session (status, currently-tuned channel, decision).
  Future<Map<String, dynamic>> liveSession(String sessionId) async {
    final res = await _http.request<Map<String, dynamic>>(
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
