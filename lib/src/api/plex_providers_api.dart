// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';

/// `/media/providers` — third-party media providers (TIDAL, internal
/// channels, external streaming sources).
///
/// Wraps the `Provider` OpenAPI tag (4 operations).
class PlexProvidersApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.providers].
  PlexProvidersApi(this._http);

  /// `GET /media/providers` — list every registered provider.
  Future<Map<String, dynamic>> list() async {
    final res = await _http.request<Map<String, dynamic>>('/media/providers');
    return res.data ?? const {};
  }

  /// `POST /media/providers?url={url}` — add a new provider.
  Future<Map<String, dynamic>> add({required String url}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/media/providers',
      method: 'POST',
      queryParameters: {'url': url},
    );
    return res.data ?? const {};
  }

  /// `POST /media/providers/refresh` — re-poll every provider to
  /// pick up new content.
  Future<void> refresh() async {
    await _http.request<void>(
      '/media/providers/refresh',
      method: 'POST',
    );
  }

  /// `DELETE /media/providers/{provider}` — drop a provider.
  Future<void> delete(String provider) async {
    await _http.request<void>(
      '/media/providers/$provider',
      method: 'DELETE',
    );
  }
}
