// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Parsers for `PlexConnection.requestJson`. Not exported.
///
/// Each one returns a closure that captures only its arguments — `fromJson`
/// tear-offs and strings — so it can be sent to the isolate that decodes a
/// large response. A closure written inline in a sub-API method would be
/// just as sendable as long as it touches nothing but its own arguments;
/// these exist so that the rule has one obvious way to be followed.
library;

import 'plex_error_type.dart';
import 'plex_exception.dart';
import 'plex_models.dart';

/// Parses a `MediaContainer` envelope whose entries sit under [arrayKey].
PlexMediaContainer<T> Function(Object? json) containerOf<T>(
  String arrayKey,
  T Function(Map<String, dynamic>) parser,
) =>
    (json) => PlexMediaContainer.fromJson(_map(json), arrayKey, parser);

/// Like [containerOf], keeping only the entries.
List<T> Function(Object? json) itemsOf<T>(
  String arrayKey,
  T Function(Map<String, dynamic>) parser,
) =>
    (json) => PlexMediaContainer.fromJson(_map(json), arrayKey, parser).items;

Map<String, dynamic> _map(Object? json) {
  if (json == null) return const <String, dynamic>{};
  if (json is Map<String, dynamic>) return json;
  throw PlexException(
    'Expected a JSON object, got ${json.runtimeType}',
    type: PlexErrorType.parse,
  );
}
