// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of '../plex_models.dart';

// ---------------------------------------------------------------------------
// Play queues (returned by /playQueues create + fetch)
// ---------------------------------------------------------------------------

/// Wraps the response of `POST /playQueues` (and friends).
///
/// Plex puts the queue identity on the MediaContainer envelope itself —
/// `playQueueID`, `playQueueSelectedItemID`, `playQueueShuffled`,
/// `playQueueVersion` — and the items in the `Metadata` array. This
/// DTO surfaces both so callers can pass [id] straight back to
/// [PlexPlayQueuesApi.items], [PlexPlayQueuesApi.addItems], …
final class PlexPlayQueue {
  /// Server-assigned queue identifier. Use this with the rest of
  /// [PlexPlayQueuesApi].
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
      shuffled: container['playQueueShuffled'] == true ||
          container['playQueueShuffled'] == 1,
      version: asInt(container['playQueueVersion']),
      items: [
        if (metadata is List)
          for (final m in metadata)
            if (m is Map<String, Object?>) PlexMetadata.fromJson(m),
      ],
      raw: container,
    );
  }
}

// ---------------------------------------------------------------------------
// Sessions (now playing on the server)
// ---------------------------------------------------------------------------

/// One entry from `/status/sessions` — a Plex metadata item enriched
/// with `User`, `Player` and (when transcoding) `TranscodeSession`
/// sub-nodes describing **who is playing** and **how**.
final class PlexSession {
  /// The underlying metadata for the item being played.
  final PlexMetadata metadata;

  /// Current playback position, in milliseconds.
  final int? viewOffsetMs;

  /// `Player.title`, `Player.product`, `Player.device`, …
  final PlexSessionPlayer? player;

  /// `User.id`, `User.title`, `User.thumb` — who's streaming.
  final PlexSessionUser? user;

  /// `Session.id` — the **session identifier** (NOT the transcode
  /// session UUID). Use this with `PlexSessionsApi.terminate`.
  final String? sessionId;

  /// Bandwidth in kbps when known.
  final int? bandwidth;

  /// `TranscodeSession.key`, `videoDecision`, `audioDecision`,
  /// `protocol`, `progress`. Null on direct-play sessions.
  final Map<String, Object?>? transcodeSession;

  /// Full raw JSON for fields not lifted above.
  final Map<String, Object?> raw;

  /// Creates a session record.
  const PlexSession({
    required this.metadata,
    required this.raw,
    this.viewOffsetMs,
    this.player,
    this.user,
    this.sessionId,
    this.bandwidth,
    this.transcodeSession,
  });

  /// Parses one item from `/status/sessions` along with its nested
  /// `Player`, `User`, `Session` and `TranscodeSession` sub-nodes.
  factory PlexSession.fromJson(Map<String, Object?> json) {
    final session = json['Session'];
    return PlexSession(
      metadata: PlexMetadata.fromJson(json),
      viewOffsetMs: asInt(json['viewOffset']),
      player: json['Player'] is Map<String, Object?>
          ? PlexSessionPlayer.fromJson(json['Player'] as Map<String, Object?>)
          : null,
      user: json['User'] is Map<String, Object?>
          ? PlexSessionUser.fromJson(json['User'] as Map<String, Object?>)
          : null,
      sessionId: session is Map ? asString(session['id']) : null,
      bandwidth: session is Map ? asInt(session['bandwidth']) : null,
      transcodeSession: json['TranscodeSession'] is Map<String, Object?>
          ? json['TranscodeSession'] as Map<String, Object?>
          : null,
      raw: json,
    );
  }
}

/// `Player` sub-node of a [PlexSession] — identifies the device that's
/// driving playback.
final class PlexSessionPlayer {
  /// Friendly device name (`Living Room Apple TV`, …).
  final String? title;

  /// Product name (`Plex for tvOS`, …).
  final String? product;

  /// Host platform (`tvOS`, `iOS`, …).
  final String? platform;

  /// Device descriptor / form factor.
  final String? device;

  /// Playback state: `playing`, `paused`, `buffering`, `stopped`.
  final String? state; // playing | paused | buffering | stopped

  /// True when the player is on the same LAN as the server.
  final bool local;

  /// Player IP address as the server sees it.
  final String? address;

  /// Full raw JSON for fields not lifted above.
  final Map<String, Object?> raw;

  /// Creates a player descriptor; only [raw] is required.
  const PlexSessionPlayer({
    required this.raw,
    this.title,
    this.product,
    this.platform,
    this.device,
    this.state,
    this.local = false,
    this.address,
  });

  /// Parses a `<Player>` sub-node.
  factory PlexSessionPlayer.fromJson(Map<String, Object?> json) =>
      PlexSessionPlayer(
        title: asString(json['title']),
        product: asString(json['product']),
        platform: asString(json['platform']),
        device: asString(json['device']),
        state: asString(json['state']),
        local: json['local'] == true || json['local'] == '1',
        address: asString(json['address']),
        raw: json,
      );
}

/// `User` sub-node of a [PlexSession] — identifies the account streaming
/// the item.
final class PlexSessionUser {
  /// Plex account id of the streaming user.
  final String id;

  /// Display name of the user.
  final String title;

  /// Avatar URL, when set.
  final String? thumb;

  /// Full raw JSON for fields not lifted above.
  final Map<String, Object?> raw;

  /// Creates a session-user record.
  const PlexSessionUser({
    required this.id,
    required this.title,
    required this.raw,
    this.thumb,
  });

  /// Parses a `<User>` sub-node.
  factory PlexSessionUser.fromJson(Map<String, Object?> json) =>
      PlexSessionUser(
        id: asString(json['id']) ?? '',
        title: asString(json['title']) ?? '',
        thumb: asString(json['thumb']),
        raw: json,
      );
}
