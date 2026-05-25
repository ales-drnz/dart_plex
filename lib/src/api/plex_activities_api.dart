// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';

/// `/activities` — long-running server activities (scan progress,
/// transcoding sessions, etc.).
///
/// Wraps the `Activities` OpenAPI tag (2 operations). Activities
/// are reported via the websocket notifications too; this REST
/// endpoint is for one-shot reads.
class PlexActivitiesApi {
  final PlexConnection _http;

  PlexActivitiesApi(this._http);

  /// `GET /activities` — list running activities.
  Future<Map<String, dynamic>> list() async {
    final res = await _http.request<Map<String, dynamic>>('/activities');
    return res.data ?? const {};
  }

  /// `DELETE /activities/{activityId}` — cancel a running activity
  /// (best-effort; some activity types cannot be cancelled).
  Future<void> cancel(String activityId) async {
    await _http.request<void>(
      '/activities/$activityId',
      method: 'DELETE',
    );
  }
}
