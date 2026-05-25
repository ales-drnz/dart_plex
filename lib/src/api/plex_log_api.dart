// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:typed_data';

import '../plex_connection.dart';

/// `/log` — send log entries to the server.
///
/// Wraps the `Log` OpenAPI tag (3 operations). Useful from native
/// clients to fold their own crash reports / diagnostics into the
/// server log stream.
class PlexLogApi {
  final PlexConnection _http;

  PlexLogApi(this._http);

  /// `PUT /log?level={l}&message={m}&source={s}` — log one line.
  /// [level] is `0..9` (0=trace, 4=info, 6=error).
  Future<void> writeMessage({
    required int level,
    required String message,
    required String source,
  }) async {
    await _http.request<void>(
      '/log',
      method: 'PUT',
      queryParameters: {
        'level': level,
        'message': message,
        'source': source,
      },
    );
  }

  /// `POST /log` — append a multi-line body to the log.
  Future<void> writeBlock({
    required Uint8List body,
    String contentType = 'text/plain',
  }) async {
    await _http.request<void>(
      '/log',
      method: 'POST',
      data: body,
      extraHeaders: {'Content-Type': contentType},
    );
  }

  /// `POST /log/networked?minutes={m}` — enable Papertrail / remote
  /// log forwarding for [minutes].
  Future<void> enablePapertrail({required int minutes}) async {
    await _http.request<void>(
      '/log/networked',
      method: 'POST',
      queryParameters: {'minutes': minutes},
    );
  }
}
