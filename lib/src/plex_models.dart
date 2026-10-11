// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Plain immutable DTOs for the Plex API.
///
/// All models are plain Dart classes (no freezed / json_serializable) so
/// the package stays codegen-free. `fromJson` factories accept either the
/// shape returned by `plex.tv/api/v2/*` (top-level object) or the shape
/// nested inside a `MediaContainer` envelope (PMS endpoints).
library;

import 'api/plex_account_api.dart';
import 'api/plex_library_api.dart';
import 'api/plex_play_queues_api.dart';
import 'api/plex_playlists_api.dart';
import 'plex_error_type.dart';
import 'plex_exception.dart';
import 'plex_filter.dart';
import 'plex_json.dart';

part 'models/plex_account_models.dart';
part 'models/plex_hub_models.dart';
part 'models/plex_library_models.dart';
part 'models/plex_metadata_models.dart';
part 'models/plex_session_models.dart';

// ---------------------------------------------------------------------------
// Type tags
// ---------------------------------------------------------------------------

/// Top-level library category (the `type` field on a `<Directory>` returned
/// from `/library/sections`).
enum PlexLibraryType {
  /// Music library (Plex wire value `artist`).
  music('artist'),

  /// Movie library.
  movie('movie'),

  /// TV show library.
  show('show'),

  /// Photo library.
  photo('photo'),

  /// Unrecognised or missing type — fallback when the wire value doesn't
  /// match any known variant.
  unknown('');

  /// Raw Plex wire string for this variant (e.g. `artist` for music).
  final String wire;
  const PlexLibraryType(this.wire);

  /// Resolves a wire string to a [PlexLibraryType], returning [unknown]
  /// when `value` is null or unrecognised.
  static PlexLibraryType fromWire(String? value) {
    switch (value) {
      case 'artist':
        return PlexLibraryType.music;
      case 'movie':
        return PlexLibraryType.movie;
      case 'show':
        return PlexLibraryType.show;
      case 'photo':
        return PlexLibraryType.photo;
      default:
        return PlexLibraryType.unknown;
    }
  }
}

/// The integer type tag used on every `/library/metadata/{id}` response.
///
/// `type=1 movie, 2 show, 3 season, 4 episode, 5 trailer, 8 artist,
///  9 album, 10 track, 13 photoAlbum, 14 photo, 15 playlist, 18 collection`.
enum PlexMetadataType {
  /// Movie (`type=1`).
  movie(1, 'movie'),

  /// TV show / series root (`type=2`).
  show(2, 'show'),

  /// Season under a show (`type=3`).
  season(3, 'season'),

  /// Episode under a season (`type=4`).
  episode(4, 'episode'),

  /// Trailer (`type=5`).
  trailer(5, 'trailer'),

  /// Music artist (`type=8`).
  artist(8, 'artist'),

  /// Music album (`type=9`).
  album(9, 'album'),

  /// Music track (`type=10`).
  track(10, 'track'),

  /// Photo album (`type=13`).
  ///
  /// The wire string `photoalbum` matches Plex's lowercase library/libtype
  /// token. Note that individual photo-album *metadata* items report their
  /// `type` as `photo`, so they resolve to [photo] via [fromWire]; use
  /// [fromValue] with `13` to obtain this variant explicitly.
  photoAlbum(13, 'photoalbum'),

  /// Photo (`type=14`).
  photo(14, 'photo'),

  /// Playlist (`type=15`).
  playlist(15, 'playlist'),

  /// Collection (`type=18`).
  collection(18, 'collection'),

  /// Unrecognised or missing type — fallback used when the int / wire
  /// string doesn't match any known variant.
  unknown(0, 'unknown');

  /// Numeric `type` tag as used in Plex JSON.
  final int value;

  /// Lowercase wire string Plex sometimes uses in place of the numeric
  /// [value] (e.g. `track`, `episode`).
  final String wire;
  const PlexMetadataType(this.value, this.wire);

  /// Resolves a numeric `type` tag, returning [unknown] when null or
  /// unmatched.
  static PlexMetadataType fromValue(int? value) {
    for (final t in PlexMetadataType.values) {
      if (t.value == value) return t;
    }
    return PlexMetadataType.unknown;
  }

  /// Resolves a wire string variant, returning [unknown] when null or
  /// unmatched.
  static PlexMetadataType fromWire(String? value) {
    if (value == null) return PlexMetadataType.unknown;
    for (final t in PlexMetadataType.values) {
      if (t.wire == value) return t;
    }
    return PlexMetadataType.unknown;
  }
}

// ---------------------------------------------------------------------------
// MediaContainer envelope
// ---------------------------------------------------------------------------

/// Every PMS endpoint returns a `MediaContainer` envelope wrapping the
/// payload. This helper unwraps it and validates the basic shape.
final class PlexMediaContainer<T> {
  /// Total number of records, when paginated (`totalSize`).
  final int totalSize;

  /// Items returned by this page (`size`).
  final int size;

  /// Caller-typed payload — what's inside the container.
  final List<T> items;

  /// The envelope's own fields (`librarySectionID`, `title1`, …), for
  /// those not lifted into this class. The entry array is left out: it is
  /// [items], parsed, and keeping the JSON of a large page alongside its
  /// models would double what it holds.
  final Map<String, Object?> raw;

  /// Creates a container with already-parsed [items] and the envelope's
  /// other fields in [raw].
  const PlexMediaContainer({
    required this.totalSize,
    required this.size,
    required this.items,
    required this.raw,
  });

  /// Decode the envelope at the top of [json], extract the array named
  /// [arrayKey], and map each entry with [parser].
  ///
  /// Plex responses use different array keys depending on the endpoint:
  /// `Metadata`, `Directory`, `Hub`, `Playlist`, `Pivot`, …
  factory PlexMediaContainer.fromJson(
    Map<String, Object?> json,
    String arrayKey,
    T Function(Map<String, Object?>) parser,
  ) {
    final container = json['MediaContainer'];
    if (container is! Map<String, Object?>) {
      throw const PlexException(
        'Missing MediaContainer in response',
        type: PlexErrorType.parse,
      );
    }
    final raw = container[arrayKey];
    final list = raw is List ? raw : const <Object?>[];
    return PlexMediaContainer<T>(
      totalSize: asInt(container['totalSize']) ?? asInt(container['size']) ?? 0,
      size: asInt(container['size']) ?? list.length,
      items: [
        for (final e in list)
          if (e is Map<String, Object?>) parser(e),
      ],
      raw: {
        for (final e in container.entries)
          if (e.key != arrayKey) e.key: e.value,
      },
    );
  }
}
