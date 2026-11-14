// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../parsing/plex_parsing.dart';
import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_models.dart';
import '../plex_urls.dart';

/// `/media/providers` — third-party media providers (TIDAL, internal
/// channels, external streaming sources).
///
/// Wraps the `Provider` OpenAPI tag (4 operations).
///
/// {@category Server}
class PlexProvidersApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.providers].
  PlexProvidersApi(this._http);

  /// `GET /media/providers` — every registered provider, with what it
  /// offers (verified on PMS 1.43.2: the library, with its features).
  Future<List<PlexMediaProvider>> list() => _http.requestJson(
    '/media/providers',
    entriesOf('MediaProvider', PlexMediaProvider.fromJson, altKey: 'Provider'),
  );

  /// `POST /media/providers?url={url}` — add a new provider; returns the
  /// providers the answer lists.
  Future<List<PlexMediaProvider>> add({required String url}) =>
      _http.requestJson(
        '/media/providers',
        entriesOf(
          'MediaProvider',
          PlexMediaProvider.fromJson,
          altKey: 'Provider',
        ),
        method: 'POST',
        queryParameters: {'url': url},
      );

  /// `POST /media/providers/refresh` — re-poll every provider to
  /// pick up new content.
  Future<void> refresh() async {
    await _http.request<void>('/media/providers/refresh', method: 'POST');
  }

  /// `DELETE /media/providers/{provider}` — drop a provider.
  Future<void> delete({required String provider}) async {
    await _http.request<void>(
      '/media/providers/${seg(provider)}',
      method: 'DELETE',
    );
  }
}
