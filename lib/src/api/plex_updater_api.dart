// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// @docImport '../plex_client.dart';
library;

import '../plex_connection.dart';
import '../plex_models.dart';

/// `/updater/*` — server software update lifecycle.
///
/// Wraps the `Updater` OpenAPI tag (3 operations). Admin only.
///
/// {@category Server}
class PlexUpdaterApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.updater].
  PlexUpdaterApi(this._http);

  /// `GET /updater/status` — current update state (last check, releases
  /// on offer, install ready).
  Future<PlexUpdaterStatus> status() => _http.requestJson(
    '/updater/status',
    (json) => PlexUpdaterStatus.fromJson(
      json is Map<String, Object?> ? json : const {},
    ),
  );

  /// `PUT /updater/check?download={bool}` — run an update check.
  /// Pass [download] = true to also download the new version.
  Future<void> check({bool download = false}) async {
    await _http.request<void>(
      '/updater/check',
      method: 'PUT',
      queryParameters: {'download': download ? 1 : 0},
    );
  }

  /// `PUT /updater/apply?tonight={bool}&skip={bool}` — apply a
  /// downloaded update. [tonight] schedules the install for the
  /// quiet hours window. [skip] is mutually exclusive with
  /// [tonight] and is ignored if both are passed.
  Future<void> apply({bool tonight = false, bool skip = false}) async {
    await _http.request<void>(
      '/updater/apply',
      method: 'PUT',
      queryParameters: {'tonight': tonight ? 1 : 0, 'skip': skip ? 1 : 0},
    );
  }
}
