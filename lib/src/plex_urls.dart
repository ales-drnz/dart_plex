// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The URLs and paths the sub-APIs build by hand. Plex only, so it lives
/// apart from the transport shared with dart_jellyfin. Not exported.
/// @docImport 'plex_exception.dart';
library;

import 'plex_connection.dart';

/// URLs a player, an image widget or a download opens on its own: they
/// cannot send headers, so the token rides in the query.
extension PlexSignedUrls on PlexConnection {
  /// The full URL of [path] on the connected server, with [query] and the
  /// token (`X-Plex-Token`, last, left out when there is none). A [query]
  /// that names `X-Plex-Token` itself keeps its own.
  ///
  /// [path] starts with `/` and is taken as it is: build its variable
  /// segments with [seg]. Keys and values of [query] are form-encoded; an
  /// entry whose value is `null` is left out.
  ///
  /// Throws a `state` [PlexException] before a server is
  /// set, rather than answering a URL that starts with `null`.
  String signedUrl(String path, [Map<String, Object?> query = const {}]) {
    requireConnected();
    final token = this.token;
    final named = query.keys.any((k) => k.toLowerCase() == 'x-plex-token');
    final pairs = [
      for (final MapEntry(:key, :value) in query.entries)
        if (value != null) _pair(key, value),
      if (!named && token != null && token.isNotEmpty)
        _pair('X-Plex-Token', token),
    ];
    return '$baseUrl$path${pairs.isEmpty ? '' : '?${pairs.join('&')}'}';
  }
}

String _pair(String key, Object value) =>
    '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent('$value')}';

/// [value] as one segment of a request path: `/`, `?`, `#`, `%`, `\` and
/// whitespace are percent-encoded, so an id cannot name another route.
/// Everything else stays as it is — a rating key list (`1,2,3`) keeps its
/// commas.
///
/// Throws an [ArgumentError] for an empty value, `.` or `..`: those are
/// not ids, and a path would be resolved around them.
///
/// Not for a parameter that is itself a path (a `key` the server gave,
/// such as `/library/metadata/1/children`): that one goes as it is.
String seg(Object value) {
  final text = '$value';
  if (text.isEmpty || text == '.' || text == '..') {
    throw ArgumentError.value(value, 'id', 'not usable in a request path');
  }
  return text.replaceAllMapped(
    _unsafe,
    (m) => Uri.encodeComponent(m[0]!).replaceAll('+', '%20'),
  );
}

final RegExp _unsafe = RegExp(r'[/?#%\\\s]');
