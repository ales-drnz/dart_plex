// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_models.dart';
import '../plex_parsing.dart';
import '../plex_server_models.dart';

/// `/status/sessions` and `/status/sessions/history/*` — "what's
/// playing on the server right now" and "what was played in the past".
///
/// Sessions include both the user's own playback and any other
/// concurrent client. Useful for showing a "now playing on server"
/// dashboard, or to detect when the user is already streaming
/// elsewhere before starting a new transcode.
class PlexSessionsApi {
  static const String _libraryIdentifier = 'com.plexapp.plugins.library';

  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.sessions].
  PlexSessionsApi(this._http);

  /// All active playback sessions on the server.
  Future<List<PlexSession>> active() async {
    return _http.requestJson(
      '/status/sessions',
      itemsOf('Metadata', PlexSession.fromJson),
    );
  }

  /// Past sessions (scrobble history).
  ///
  /// [accountId] filters to one user (`1` is the owner). [mindate]
  /// uses `viewedAt >= unixtime` and [maxdate] uses `viewedAt <= unixtime`
  /// (both bounds inclusive).
  Future<PlexMediaContainer<PlexHistoryEntry>> history({
    int? accountId,
    int? mindate,
    int? maxdate,
    int? librarySectionId,
    int start = 0,
    int size = 50,
    String? sort,
  }) {
    final qp = <String, Object?>{
      'X-Plex-Container-Start': start,
      'X-Plex-Container-Size': size,
    };
    if (accountId != null) qp['accountID'] = accountId;
    if (mindate != null) qp['viewedAt>='] = mindate;
    if (maxdate != null) qp['viewedAt<='] = maxdate;
    if (librarySectionId != null) {
      qp['librarySectionID'] = librarySectionId;
    }
    if (sort != null) qp['sort'] = sort;
    return _http.requestJson(
      '/status/sessions/history/all',
      queryParameters: qp,
      containerOf('Metadata', PlexHistoryEntry.fromJson),
    );
  }

  /// Forcibly stop a session. [sessionId] is the `Session.id` field
  /// (NOT the playback `session=` UUID).
  Future<void> terminate({
    required String sessionId,
    String reason = 'Stopped',
  }) async {
    await _http.request<void>(
      '/status/sessions/terminate',
      queryParameters: {
        'sessionId': sessionId,
        'reason': reason,
      },
    );
  }

  /// A single history entry by its numeric history id.
  ///
  /// Wraps `GET /status/sessions/history/{historyId}`. [historyId] is the
  /// numeric history identifier (the `historyKey` field is its full key
  /// path); pass it as a [String] or [int] — Plex accepts the numeric id
  /// either way, mirroring how [deleteHistoryEntry] deals in keys. Returns
  /// the first `Metadata` entry, or `null` when no matching entry exists.
  Future<Map<String, Object?>?> historyItem({required Object historyId}) async {
    final res = await _http.request<Map<String, Object?>>(
      '/status/sessions/history/$historyId',
    );
    final container = res.data?['MediaContainer'];
    if (container is! Map<String, Object?>) return null;
    final list = container['Metadata'];
    if (list is! List || list.isEmpty) return null;
    final first = list.first;
    return first is Map<String, Object?> ? first : null;
  }

  /// Delete a single history entry by its history `key`.
  Future<void> deleteHistoryEntry({required String historyKey}) async {
    await _http.request<void>(
      historyKey,
      method: 'DELETE',
      queryParameters: const {'identifier': _libraryIdentifier},
    );
  }
}
