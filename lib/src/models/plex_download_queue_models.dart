// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

library;

import '../api/plex_streaming_api.dart' show PlexTranscodeDecision;
import '../plex_json.dart';

// ---------------------------------------------------------------------------
// Download queue
//
// Shapes checked against PMS 1.43.2 (test/fixtures/real/download_queue*.json).
// ---------------------------------------------------------------------------

/// A download queue (`/downloadQueue`): one per client and user.
///
/// {@category Events and downloads}
final class PlexDownloadQueue {
  /// Queue id — what the other queue calls take.
  final int id;

  /// Items queued.
  final int itemCount;

  /// Status (`deciding`, `processing`, `done`, …).
  final String? status;

  /// The client it belongs to.
  final String? clientIdentifier;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a queue.
  const PlexDownloadQueue({
    required this.id,
    required this.itemCount,
    this.status,
    this.clientIdentifier,
    this.raw = const {},
  });

  /// Parses one `DownloadQueue`.
  factory PlexDownloadQueue.fromJson(Map<String, Object?> json) =>
      PlexDownloadQueue(
        id: asInt(json['id']) ?? 0,
        itemCount: asInt(json['itemCount']) ?? 0,
        status: asString(json['status']),
        clientIdentifier: asString(json['clientIdentifier']),
        raw: json,
      );
}

/// An item of a download queue (`DownloadQueueItem`).
///
/// {@category Events and downloads}
final class PlexDownloadQueueItem {
  /// Item id.
  final int id;

  /// The queue it is in.
  final int? queueId;

  /// The rating key of what is downloaded.
  final String? key;

  /// Status (`deciding`, `waiting`, `processing`, `available`, `error`,
  /// …).
  final String? status;

  /// The error, when [status] is `error` (`decisionError`, …).
  final String? error;

  /// The decision for the item (`DecisionResult`), when made.
  final PlexTranscodeDecision? decision;

  /// The transcode producing it (`TranscodeSession`), as received.
  final Map<String, Object?>? transcodeSession;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds an item.
  const PlexDownloadQueueItem({
    required this.id,
    this.queueId,
    this.key,
    this.status,
    this.error,
    this.decision,
    this.transcodeSession,
    this.raw = const {},
  });

  /// Parses one `DownloadQueueItem`.
  factory PlexDownloadQueueItem.fromJson(Map<String, Object?> json) {
    final d = json['DecisionResult'];
    final t = json['TranscodeSession'];
    return PlexDownloadQueueItem(
      id: asInt(json['id']) ?? 0,
      queueId: asInt(json['queueId']),
      key: asString(json['key']),
      status: asString(json['status']),
      error: asString(json['error']),
      decision: d is Map<String, Object?>
          ? PlexTranscodeDecision.fromJson(d)
          : null,
      transcodeSession: t is Map<String, Object?> ? t : null,
      raw: json,
    );
  }
}
