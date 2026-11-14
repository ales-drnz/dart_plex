// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Play queues and what generates them.
library;

import '../parsing/plex_json.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';
import 'plex_metadata_models.dart';

// ---------------------------------------------------------------------------
// Play queues (returned by /playQueues create + fetch)
// ---------------------------------------------------------------------------

/// Wraps the response of `POST /playQueues` (and friends).
///
/// Plex puts the queue identity on the MediaContainer envelope itself —
/// `playQueueID`, `playQueueSelectedItemID`, `playQueueShuffled`,
/// `playQueueVersion` — and the items in the `Metadata` array. This
/// DTO surfaces both so callers can pass [id] straight back to
/// `PlexPlayQueuesApi.items`, `PlexPlayQueuesApi.addItems`, …
///
/// {@category Playback and play queues}
final class PlexPlayQueue {
  /// Server-assigned queue identifier. Use this with the rest of
  /// `PlexPlayQueuesApi`.
  final int id;

  /// `playQueueSelectedItemID` — the per-item id (NOT a ratingKey) of
  /// the entry the server picked as "current". Useful when seeding from
  /// a multi-item URI: Plex picks one as the starting point.
  final int? selectedItemId;

  /// `playQueueShuffled` — whether the queue was created with shuffle
  /// already on.
  final bool shuffled;

  /// `playQueueVersion` — monotonically increasing version number,
  /// bumped on every queue mutation. Useful for optimistic concurrency.
  final int? version;

  /// Initial queue contents (the `Metadata` array of the response).
  final List<PlexMetadata> items;

  /// Raw MediaContainer envelope, for fields not promoted above.
  final Map<String, Object?> raw;

  /// Creates a play queue snapshot.
  const PlexPlayQueue({
    required this.id,
    required this.shuffled,
    required this.items,
    required this.raw,
    this.selectedItemId,
    this.version,
  });

  /// Parses a `POST /playQueues` (or fetch) response, lifting the queue
  /// identity off the `MediaContainer` envelope and the items out of the
  /// nested `Metadata` array.
  factory PlexPlayQueue.fromJson(Map<String, Object?> json) {
    final container = json['MediaContainer'];
    if (container is! Map<String, Object?>) {
      throw const PlexException(
        'Missing MediaContainer in play queue response',
        type: PlexErrorType.parse,
      );
    }
    final metadata = container['Metadata'];
    return PlexPlayQueue(
      id: asInt(container['playQueueID']) ?? 0,
      selectedItemId: asInt(container['playQueueSelectedItemID']),
      shuffled: asBool(container['playQueueShuffled']),
      version: asInt(container['playQueueVersion']),
      items: asObjectList(metadata, PlexMetadata.fromJson),
      raw: container,
    );
  }
}

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
