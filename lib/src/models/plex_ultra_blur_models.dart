// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The UltraBlur colours of an artwork.
library;

import '../parsing/plex_json.dart';

// ---------------------------------------------------------------------------
// UltraBlur (`/services/ultrablur/colors`)
// ---------------------------------------------------------------------------

/// Four hex colours extracted from an image by the Plex server. Use
/// the same four values to ask `/services/ultrablur/image` for a
/// server-rendered gradient backdrop.
///
/// {@category Images and hubs}
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
