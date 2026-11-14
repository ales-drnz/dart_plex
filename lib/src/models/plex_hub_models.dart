// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

library;

import '../plex_json.dart';
import 'plex_metadata_models.dart';

// ---------------------------------------------------------------------------
// Hubs (used by /hubs and /hubs/search)
// ---------------------------------------------------------------------------

/// One `<Hub>` entry from `/hubs` or `/hubs/search` — a titled, optionally
/// paginated bucket of [PlexMetadata] items grouped by Plex.
///
/// {@category Images and hubs}
final class PlexHub {
  /// Relative URL to fetch the full contents of this hub (e.g.
  /// `/hubs/sections/home/onDeck`). This is the field to use for
  /// fetching or paginating a hub's contents.
  final String key;

  /// Optional re-fetch key for the *exact* content currently displayed.
  /// Important when the hub is random — re-requesting [key] may yield
  /// different results, whereas [hubKey] reproduces the same slice. Often
  /// absent, in which case it is the empty string.
  final String hubKey;

  /// Stable hub identifier (e.g. `home.continue`, `music.recent.played`).
  final String hubIdentifier;

  /// Display title of the hub.
  final String title;

  /// Optional sub-type, e.g. `clip`, `mixed`, `movie`.
  final String? type;

  /// Number of items returned in this slice.
  final int size;

  /// True when more items exist beyond what's in [items].
  final bool more;

  /// Items in this hub slice.
  final List<PlexMetadata> items;

  /// Full raw JSON for fields not lifted above.
  final Map<String, Object?> raw;

  /// Creates a hub record; [type] is optional.
  const PlexHub({
    required this.key,
    required this.hubKey,
    required this.hubIdentifier,
    required this.title,
    required this.size,
    required this.more,
    required this.items,
    required this.raw,
    this.type,
  });

  /// Parses one `<Hub>` entry from `/hubs` or `/hubs/search`, or from
  /// `/hubs/sections/{id}/manage`, which names the id `identifier`.
  factory PlexHub.fromJson(Map<String, Object?> json) => PlexHub(
    key: asString(json['key']) ?? '',
    hubKey: asString(json['hubKey']) ?? '',
    hubIdentifier:
        asString(json['hubIdentifier']) ?? asString(json['identifier']) ?? '',
    title: asString(json['title']) ?? '',
    type: asString(json['type']),
    size: asInt(json['size']) ?? 0,
    more: asBool(json['more']),
    items: asObjectList(json['Metadata'], PlexMetadata.fromJson),
    raw: json,
  );
}
