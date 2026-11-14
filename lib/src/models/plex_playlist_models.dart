// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

library;

import '../plex_json.dart';

// ---------------------------------------------------------------------------
// Playlists
// ---------------------------------------------------------------------------

/// What feeds a smart playlist (`PlayQueueGenerator`).
///
/// {@category Playlists}
final class PlexPlayQueueGenerator {
  /// Generator id — what `PlexPlaylistsApi.generatorItems` takes.
  final int id;

  /// The playlist.
  final int? playlistId;

  /// Kind of generator.
  final int? type;

  /// The query it runs (`library://…`).
  final String? uri;

  /// When it was created.
  final DateTime? createdAt;

  /// When it was last updated.
  final DateTime? updatedAt;

  /// When its results last changed.
  final DateTime? changedAt;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a generator.
  const PlexPlayQueueGenerator({
    required this.id,
    this.playlistId,
    this.type,
    this.uri,
    this.createdAt,
    this.updatedAt,
    this.changedAt,
    this.raw = const {},
  });

  /// Parses one `PlayQueueGenerator`.
  factory PlexPlayQueueGenerator.fromJson(Map<String, Object?> json) =>
      PlexPlayQueueGenerator(
        id: asInt(json['id']) ?? 0,
        playlistId: asInt(json['playlistID']),
        type: asInt(json['type']),
        uri: asString(json['uri']),
        createdAt: asEpochSeconds(json['createdAt']),
        updatedAt: asEpochSeconds(json['updatedAt']),
        changedAt: asEpochSeconds(json['changedAt']),
        raw: json,
      );
}
