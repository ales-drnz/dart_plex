// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';

/// `/butler` — Plex's nightly maintenance task runner.
///
/// Wraps the `Butler` OpenAPI tag (5 operations). Admin only.
/// Tasks include thumbnail generation, library cleanup, intro
/// detection, music analysis. They normally run on their schedule
/// but can be triggered manually here.
class PlexButlerApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.butler].
  PlexButlerApi(this._http);

  /// `GET /butler` — list configured tasks and their state.
  Future<Map<String, dynamic>> tasks() async {
    final res = await _http.request<Map<String, dynamic>>('/butler');
    return res.data ?? const {};
  }

  /// `POST /butler` — start every task now.
  Future<void> startAll() async {
    await _http.request<void>('/butler', method: 'POST');
  }

  /// `DELETE /butler` — stop every running task.
  Future<void> stopAll() async {
    await _http.request<void>('/butler', method: 'DELETE');
  }

  /// `POST /butler/{butlerTask}` — start a single task now.
  Future<void> start(String butlerTask) async {
    await _http.request<void>('/butler/$butlerTask', method: 'POST');
  }

  /// `DELETE /butler/{butlerTask}` — stop a single running task.
  Future<void> stop(String butlerTask) async {
    await _http.request<void>('/butler/$butlerTask', method: 'DELETE');
  }
}
