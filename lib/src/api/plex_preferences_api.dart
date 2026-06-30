// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';

/// `/:/prefs` — server preferences (setting names and values).
///
/// Wraps the `Preferences` OpenAPI tag (3 operations). Admin only.
/// Each preference is a `Setting` map with `id`, `value`,
/// `default`, `summary`, `type` (`bool | int | text | enum`).
class PlexPreferencesApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.preferences].
  PlexPreferencesApi(this._http);

  /// `GET /:/prefs` — every preference.
  Future<List<Map<String, dynamic>>> all() async {
    final res = await _http.request<Map<String, dynamic>>('/:/prefs');
    final container = res.data?['MediaContainer'];
    if (container is! Map<String, dynamic>) return const [];
    final list = container['Setting'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) e,
    ];
  }

  /// `GET /:/prefs/get?id={id}` — fetch a single preference.
  ///
  /// Returns the matching `Setting` map (the same shape as an entry
  /// of [all]), unwrapped from the `MediaContainer`/`Setting`
  /// envelope. Returns an empty map when the id is unknown.
  Future<Map<String, dynamic>> byId(String id) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/:/prefs/get',
      queryParameters: {'id': id},
    );
    final container = res.data?['MediaContainer'];
    if (container is! Map<String, dynamic>) return const {};
    final list = container['Setting'];
    if (list is! List) return const {};
    final first = list.firstWhere(
      (e) => e is Map<String, dynamic>,
      orElse: () => null,
    );
    return first is Map<String, dynamic> ? first : const {};
  }

  /// `PUT /:/prefs?{name}={value}&...` — set one or more
  /// preferences. The keys in [values] are preference ids; the
  /// values are the new values (string-coerced).
  Future<void> set(Map<String, dynamic> values) async {
    await _http.request<void>(
      '/:/prefs',
      method: 'PUT',
      queryParameters: values,
    );
  }
}
