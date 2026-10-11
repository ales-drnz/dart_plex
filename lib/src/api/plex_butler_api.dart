// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_server_models.dart';

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
  Future<List<PlexButlerTask>> tasks() => _http.requestJson(
        '/butler',
        _butlerTasks,
      );

  /// `POST /butler` — start every task now.
  Future<void> startAll() async {
    await _http.request<void>('/butler', method: 'POST');
  }

  /// `DELETE /butler` — stop every running task.
  Future<void> stopAll() async {
    await _http.request<void>('/butler', method: 'DELETE');
  }

  /// `POST /butler/{butlerTask}` — start a single task now.
  Future<void> start({required String butlerTask}) async {
    await _http.request<void>('/butler/$butlerTask', method: 'POST');
  }

  /// `DELETE /butler/{butlerTask}` — stop a single running task.
  Future<void> stop({required String butlerTask}) async {
    await _http.request<void>('/butler/$butlerTask', method: 'DELETE');
  }
}

/// `/butler` answers `{ButlerTasks: {ButlerTask: [...]}}`, not a
/// `MediaContainer`.
List<PlexButlerTask> _butlerTasks(Object? json) {
  final outer = json is Map<String, Object?> ? json['ButlerTasks'] : null;
  final list = outer is Map<String, Object?> ? outer['ButlerTask'] : null;
  return [
    if (list is List)
      for (final e in list)
        if (e is Map<String, Object?>) PlexButlerTask.fromJson(e),
  ];
}
