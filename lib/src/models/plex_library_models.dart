// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of '../plex_models.dart';

// ---------------------------------------------------------------------------
// Library sections
// ---------------------------------------------------------------------------

/// One library section from `/library/sections`.
final class PlexLibrarySection {
  /// `key` field — the numeric/string id used in `/library/sections/{id}/all`.
  final String id;

  /// User-facing library name (e.g. `Movies`, `Music`).
  final String title;

  /// Coarse library kind (movies, music, …).
  final PlexLibraryType type;

  /// Metadata agent identifier (e.g. `tv.plex.agents.movie`).
  final String agent;

  /// Scanner identifier (e.g. `Plex Movie Scanner`).
  final String scanner;

  /// Preferred metadata language as a BCP-47 code.
  final String language;

  /// Stable section UUID, when present.
  final String? uuid;

  /// Last scan time (UTC), null if never scanned.
  final DateTime? scannedAt;

  /// Library creation time (UTC).
  final DateTime? createdAt;

  /// Filesystem paths backing this section.
  final List<String> locations;

  /// Full raw JSON of the section for fields not lifted above.
  final Map<String, Object?> raw;

  /// Creates a section record.
  const PlexLibrarySection({
    required this.id,
    required this.title,
    required this.type,
    required this.agent,
    required this.scanner,
    required this.language,
    required this.locations,
    required this.raw,
    this.uuid,
    this.scannedAt,
    this.createdAt,
  });

  /// Parses one `<Directory>` entry from `/library/sections`.
  factory PlexLibrarySection.fromJson(Map<String, Object?> json) {
    final locs = json['Location'];
    final out = <String>[];
    if (locs is List) {
      for (final l in locs) {
        if (l is Map && l['path'] is String) out.add(l['path'] as String);
      }
    }
    return PlexLibrarySection(
      id: asString(json['key']) ?? '',
      title: asString(json['title']) ?? '',
      type: PlexLibraryType.fromWire(asString(json['type'])),
      agent: asString(json['agent']) ?? '',
      scanner: asString(json['scanner']) ?? '',
      language: asString(json['language']) ?? '',
      uuid: asString(json['uuid']),
      scannedAt: asEpochSeconds(json['scannedAt']),
      createdAt: asEpochSeconds(json['createdAt']),
      locations: out,
      raw: json,
    );
  }
}

// ---------------------------------------------------------------------------
// Section facets and their values
// ---------------------------------------------------------------------------

/// Kind of value a [PlexLibraryFilter] compares against, from the
/// `filterType` attribute.
///
/// The pinned spec describes this as "either `string`, `integer`, or
/// `boolean`". Anything else a server sends resolves to [unknown]; the
/// wire string stays available in [PlexLibraryFilter.raw].
enum PlexFilterValueType {
  /// Free text (`string`). Note that tag facets such as genre report
  /// this type but are still filtered by numeric [PlexTag.id].
  string('string'),

  /// Whole number (`integer`) — year, play count, rating.
  integer('integer'),

  /// A `1` / `0` flag (`boolean`) — e.g. `unwatched`.
  boolean('boolean'),

  /// Unrecognised or missing `filterType`.
  unknown('');

  /// Raw Plex wire string for this variant.
  final String wire;

  const PlexFilterValueType(this.wire);

  /// Resolves a wire string, returning [unknown] when null or unmatched.
  static PlexFilterValueType fromWire(String? value) {
    if (value == null) return PlexFilterValueType.unknown;
    for (final t in PlexFilterValueType.values) {
      if (t.wire == value) return t;
    }
    return PlexFilterValueType.unknown;
  }
}

/// One facet a section can be filtered on, from
/// `/library/sections/{id}/filters`.
///
/// [field] is the query-parameter name to filter with — feed it to
/// [PlexFilter.new] or one of its named constructors. [valuesKey] is
/// the endpoint listing the values the facet can take, which
/// [PlexLibraryApi.filterValues] fetches for you.
final class PlexLibraryFilter {
  /// Parameter name this facet filters on (`genre`, `year`,
  /// `unwatched`) — the `filter` attribute on the wire.
  final String field;

  /// User-facing facet name (e.g. `Genre`).
  final String title;

  /// Kind of value [field] compares against — the `filterType`
  /// attribute.
  final PlexFilterValueType valueType;

  /// Endpoint listing the possible values for this facet (the `key`
  /// attribute), or null when the server did not supply one.
  final String? valuesKey;

  /// Full raw JSON of the facet, including the `Pivot` array of
  /// pre-built sub-views (A-Z index, folder view).
  final Map<String, Object?> raw;

  /// Creates a facet descriptor.
  const PlexLibraryFilter({
    required this.field,
    required this.title,
    required this.valueType,
    required this.raw,
    this.valuesKey,
  });

  /// Parses one `<Directory>` entry from
  /// `/library/sections/{id}/filters`.
  factory PlexLibraryFilter.fromJson(Map<String, Object?> json) =>
      PlexLibraryFilter(
        field: asString(json['filter']) ?? '',
        title: asString(json['title']) ?? '',
        valueType: PlexFilterValueType.fromWire(asString(json['filterType'])),
        valuesKey: asString(json['key']),
        raw: json,
      );
}

/// One value of a filterable field — a genre, mood, style, decade,
/// collection or label row.
///
/// Returned by [PlexLibraryApi.genres] and
/// [PlexLibraryApi.filterValues]. [id] is the number Plex expects when
/// filtering by this tag and [field] is the parameter it belongs to;
/// hand the whole tag to [PlexFilter.of] rather than reassembling
/// either by hand.
final class PlexTag {
  /// Numeric tag id — the value in `?genre=<id>`.
  ///
  /// Null when the server sent no id this package could resolve, in
  /// which case the tag cannot be filtered on; [PlexFilter.of] throws
  /// rather than issue a request that would come back unfiltered.
  final int? id;

  /// Display name (e.g. `Rock`).
  final String title;

  /// Query parameter this tag filters on (`genre`, `mood`, `style`).
  ///
  /// Read out of [fastKey] when the server supplies one, otherwise
  /// taken from the endpoint that produced the tag.
  final String field;

  /// The `key` attribute as sent. A bare tag id on current servers, a
  /// `/library/sections/...` path on older ones.
  final String? key;

  /// The `fastKey` attribute — a ready-made
  /// `/library/sections/{id}/all?<field>=<id>&type=<n>` query.
  final String? fastKey;

  /// Full raw JSON of the tag.
  final Map<String, Object?> raw;

  /// Creates a tag value.
  const PlexTag({
    required this.title,
    required this.field,
    required this.raw,
    this.id,
    this.key,
    this.fastKey,
  });

  /// Parses one `<Directory>` entry from a tag index such as
  /// `/library/sections/{id}/genre`.
  ///
  /// [field] is the facet the entry came from, used when the response
  /// carries no [fastKey] to derive it from.
  factory PlexTag.fromJson(Map<String, Object?> json, {String? field}) {
    final key = asString(json['key']);
    final fastKey = asString(json['fastKey']);
    final resolved = _resolveTagFilter(json, key, fastKey);
    return PlexTag(
      id: resolved.id ?? asInt(json['id']),
      title: asString(json['title']) ?? '',
      field: resolved.field ?? field ?? asString(json['type']) ?? '',
      key: key,
      fastKey: fastKey,
      raw: json,
    );
  }
}

/// Pull the filter field and tag id out of a tag entry's `fastKey` /
/// `key`, covering all three shapes servers send: a ready-made query
/// (`/library/sections/3/all?genre=42&type=9`), a bare id (`42`), and a
/// path ending in the id (`/library/sections/3/genre/42`).
({int? id, String? field}) _resolveTagFilter(
  Map<String, Object?> json,
  String? key,
  String? fastKey,
) {
  for (final candidate in [fastKey, key]) {
    if (candidate == null || !candidate.contains('?')) continue;
    final params = Uri.parse(candidate).queryParameters;
    for (final entry in params.entries) {
      if (entry.key == 'type') continue;
      final value = int.tryParse(entry.value);
      if (value != null) return (id: value, field: entry.key);
    }
  }
  if (key != null) {
    final bare = int.tryParse(key);
    if (bare != null) return (id: bare, field: null);
    final segments = Uri.parse(key).pathSegments;
    if (segments.isNotEmpty) {
      final last = int.tryParse(segments.last);
      if (last != null) {
        return (
          id: last,
          field: segments.length >= 2 ? segments[segments.length - 2] : null,
        );
      }
    }
  }
  return (id: null, field: null);
}
