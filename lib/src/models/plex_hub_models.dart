// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of '../plex_models.dart';

// ---------------------------------------------------------------------------
// Hubs (used by /hubs and /hubs/search)
// ---------------------------------------------------------------------------

/// One `<Hub>` entry from `/hubs` or `/hubs/search` — a titled, optionally
/// paginated bucket of [PlexMetadata] items grouped by Plex.
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

  /// Parses one `<Hub>` entry from `/hubs` or `/hubs/search`.
  factory PlexHub.fromJson(Map<String, Object?> json) => PlexHub(
        key: asString(json['key']) ?? '',
        hubKey: asString(json['hubKey']) ?? '',
        hubIdentifier: asString(json['hubIdentifier']) ?? '',
        title: asString(json['title']) ?? '',
        type: asString(json['type']),
        size: asInt(json['size']) ?? 0,
        more: json['more'] == true,
        items: [
          if (json['Metadata'] is List)
            for (final m in json['Metadata'] as List)
              if (m is Map<String, Object?>) PlexMetadata.fromJson(m),
        ],
        raw: json,
      );
}

// ---------------------------------------------------------------------------
// UltraBlur (`/services/ultrablur/colors`)
// ---------------------------------------------------------------------------

/// Four hex colours extracted from an image by the Plex server. Use
/// the same four values to ask `/services/ultrablur/image` for a
/// server-rendered gradient backdrop.
final class PlexUltraBlurColors {
  /// Top-left swatch as a hex string (e.g. `#1a2b3c`).
  final String? topLeft;

  /// Top-right swatch as a hex string.
  final String? topRight;

  /// Bottom-left swatch as a hex string.
  final String? bottomLeft;

  /// Bottom-right swatch as a hex string.
  final String? bottomRight;

  /// Full raw JSON for fields not lifted above.
  final Map<String, Object?> raw;

  /// Creates an UltraBlur colour quad; all swatches are optional.
  const PlexUltraBlurColors({
    this.topLeft,
    this.topRight,
    this.bottomLeft,
    this.bottomRight,
    this.raw = const {},
  });

  /// Parses the response of `/services/ultrablur/colors`.
  factory PlexUltraBlurColors.fromJson(Map<String, Object?> json) =>
      PlexUltraBlurColors(
        topLeft: asString(json['topLeft']),
        topRight: asString(json['topRight']),
        bottomLeft: asString(json['bottomLeft']),
        bottomRight: asString(json['bottomRight']),
        raw: json,
      );
}
