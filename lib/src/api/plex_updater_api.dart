// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';

/// `/updater/*` — server software update lifecycle.
///
/// Wraps the `Updater` OpenAPI tag (3 operations). Admin only.
class PlexUpdaterApi {
  final PlexConnection _http;

  PlexUpdaterApi(this._http);

  /// `GET /updater/status` — current update state (last check,
  /// downloaded version, install ready).
  Future<Map<String, dynamic>> status() async {
    final res = await _http.request<Map<String, dynamic>>('/updater/status');
    return res.data ?? const {};
  }

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
      queryParameters: {
        'tonight': tonight ? 1 : 0,
        'skip': skip ? 1 : 0,
      },
    );
  }
}
