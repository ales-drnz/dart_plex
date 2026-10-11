// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Typed server events, decoded from the notification stream.
///
/// The shapes follow frames captured from PMS 1.43.2 (fixtures in
/// `test/fixtures/notifications/`), not only the API document: the server
/// sends ids as strings where the document says integers, and fields the
/// document leaves out (`parentItemID`, `mediaState`, `Context`).
library;

import 'plex_json.dart';
import 'plex_models.dart';

/// One event from the notification stream. Switch over the subtypes:
///
/// ```dart
/// final socket = await plex.notifications.connectWebSocket();
/// socket.events().listen((event) {
///   switch (event) {
///     case PlexLibraryItemEvent(:final itemId, isDeleted: true):
///       cache.drop(itemId);
///     case PlexLibraryItemEvent(:final itemId, :final updatedAt):
///       cache.refresh(itemId, updatedAt);
///     case PlexPlaySessionEvent(:final ratingKey, :final state):
///       nowPlaying.update(ratingKey, state);
///     case PlexActivityEvent(isLibraryScan: true, :final isEnded):
///       if (isEnded) library.reload();
///     case _:
///   }
/// });
/// ```
sealed class PlexEvent {
  /// The entry as the server sent it.
  final Map<String, Object?> raw;

  const PlexEvent(this.raw);

  /// Decodes every entry of one notification frame — a frame can carry
  /// several. [type] is the frame's `type` discriminator and [container]
  /// the frame body (the `NotificationContainer`).
  static List<PlexEvent> fromFrame(
    String type,
    Map<String, Object?> container,
  ) {
    List<Map<String, Object?>> entries(String key) => [
          if (container[key] is List)
            for (final e in container[key] as List)
              if (e is Map<String, Object?>) e,
        ];

    switch (type) {
      case 'playing':
        return [
          for (final e in entries('PlaySessionStateNotification'))
            PlexPlaySessionEvent.fromJson(e),
        ];
      case 'timeline':
        return [
          for (final e in entries('TimelineEntry'))
            PlexLibraryItemEvent.fromJson(e),
        ];
      case 'activity':
        return [
          for (final e in entries('ActivityNotification'))
            PlexActivityEvent.fromJson(e),
        ];
      case 'status':
        return [
          for (final e in entries('StatusNotification'))
            PlexStatusEvent.fromJson(e),
        ];
      default:
        return [PlexUnknownEvent(type, container)];
    }
  }
}

/// A player's play state changed (frame type `playing`): playing, paused,
/// stopped or buffering — the same reports a client sends with
/// `PlexPlaybackApi.timeline`, as the server saw them.
final class PlexPlaySessionEvent extends PlexEvent {
  /// The server's session id (also on `/status/sessions`).
  final String? sessionKey;

  /// `X-Plex-Client-Identifier` of the player.
  final String? clientIdentifier;

  /// Rating key of the item being played.
  final String ratingKey;

  /// `/library/metadata/{ratingKey}`.
  final String? key;

  /// The play state the player reported.
  final PlexPlayState state;

  /// Playhead in milliseconds.
  final int? viewOffsetMs;

  /// The play queue entry, when the player plays a server-side queue.
  final int? playQueueItemId;

  /// The play queue, when the player plays a server-side queue.
  final int? playQueueId;

  /// Decodes a `PlaySessionStateNotification` entry.
  PlexPlaySessionEvent.fromJson(super.raw)
      : sessionKey = asString(raw['sessionKey']),
        clientIdentifier = asString(raw['clientIdentifier']),
        ratingKey = asString(raw['ratingKey']) ?? '',
        key = asString(raw['key']),
        state = PlexPlayState.fromWire(asString(raw['state'])),
        viewOffsetMs = asInt(raw['viewOffset']),
        playQueueItemId = asInt(raw['playQueueItemID']),
        playQueueId = asInt(raw['playQueueID']);
}

/// Play state of a session.
enum PlexPlayState {
  /// `playing`
  playing('playing'),

  /// `paused`
  paused('paused'),

  /// `buffering`
  buffering('buffering'),

  /// `stopped`
  stopped('stopped'),

  /// Anything else the server may send.
  unknown('');

  /// The wire value.
  final String wire;

  const PlexPlayState(this.wire);

  /// The state for [value]; [unknown] when unrecognised.
  static PlexPlayState fromWire(String? value) => values.firstWhere(
        (s) => s.wire == value && s != unknown,
        orElse: () => unknown,
      );
}

/// A library item was created, changed, analysed or deleted (frame type
/// `timeline`).
///
/// One change arrives as several events as the item moves through
/// [state]: a new track goes `created` (0) → (1) → `loading` (4) → ready
/// (5); a deleted one arrives once with state 9. New artwork arrives as a
/// ready (5) event with a new [updatedAt] — compare it with the item's
/// thumb version to know the cover changed.
final class PlexLibraryItemEvent extends PlexEvent {
  /// Rating key of the item.
  final String itemId;

  /// Rating key of its parent (a track's album), when sent.
  final String? parentItemId;

  /// Rating key of its root (a track's artist), when sent.
  final String? rootItemId;

  /// The library section, as its id string.
  final String? sectionId;

  /// The item kind; [PlexMetadataType.unknown] when not sent.
  final PlexMetadataType type;

  /// `"Artist / Album (track n)"`-style display title; may be empty on the
  /// first `created` event.
  final String title;

  /// The server's processing state (see [isReady], [isDeleted]).
  final int? state;

  /// `created`, `processing`, `loading`, `deleted`, … when sent.
  final String? metadataState;

  /// `analyzing`, … when the media is being analysed.
  final String? mediaState;

  /// When the item last changed.
  final DateTime? updatedAt;

  /// Decodes a `TimelineEntry`.
  PlexLibraryItemEvent.fromJson(super.raw)
      : itemId = asString(raw['itemID']) ?? '',
        parentItemId = asString(raw['parentItemID']),
        rootItemId = asString(raw['rootItemID']),
        sectionId = asString(raw['sectionID']),
        type = PlexMetadataType.fromValue(asInt(raw['type'])),
        title = asString(raw['title']) ?? '',
        state = asInt(raw['state']),
        metadataState = asString(raw['metadataState']),
        mediaState = asString(raw['mediaState']),
        updatedAt = asEpochSeconds(raw['updatedAt']);

  /// The item was just created (state 0 / `metadataState: created`).
  bool get isCreated => state == 0 || metadataState == 'created';

  /// Processing finished and nothing is pending: re-read the item.
  bool get isReady => state == 5 && metadataState == null && mediaState == null;

  /// The item is gone (state 9 / `metadataState: deleted`).
  bool get isDeleted => state == 9 || metadataState == 'deleted';
}

/// A background activity started, progressed or ended (frame type
/// `activity`) — library scans above all.
final class PlexActivityEvent extends PlexEvent {
  /// `started`, `updated` or `ended`.
  final String event;

  /// The activity's id, stable across its events.
  final String uuid;

  /// e.g. `library.update.section`, `library.refresh.items`,
  /// `media.generate.chapters`.
  final String activityType;

  /// e.g. `Scanning Music`.
  final String title;

  /// e.g. the album being scanned.
  final String? subtitle;

  /// 0–100.
  final int? progress;

  /// Whether the activity can be cancelled (`PlexActivitiesApi`).
  final bool cancellable;

  /// The section the activity works on, when it names one.
  final String? librarySectionId;

  /// Decodes an `ActivityNotification` entry.
  factory PlexActivityEvent.fromJson(Map<String, Object?> raw) {
    final activity = raw['Activity'] is Map<String, Object?>
        ? raw['Activity'] as Map<String, Object?>
        : const <String, Object?>{};
    final context = activity['Context'] is Map<String, Object?>
        ? activity['Context'] as Map<String, Object?>
        : const <String, Object?>{};
    return PlexActivityEvent._(
      raw,
      event: asString(raw['event']) ?? '',
      uuid: asString(raw['uuid']) ?? asString(activity['uuid']) ?? '',
      activityType: asString(activity['type']) ?? '',
      title: asString(activity['title']) ?? '',
      subtitle: asString(activity['subtitle']),
      progress: asInt(activity['progress']),
      cancellable: activity['cancellable'] == true,
      librarySectionId: asString(context['librarySectionID']),
    );
  }

  PlexActivityEvent._(
    super.raw, {
    required this.event,
    required this.uuid,
    required this.activityType,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.cancellable,
    required this.librarySectionId,
  });

  /// A library scan or refresh (`library.update.*`, `library.refresh.*`).
  bool get isLibraryScan =>
      activityType.startsWith('library.update') ||
      activityType.startsWith('library.refresh');

  /// The activity has finished.
  bool get isEnded => event == 'ended';
}

/// A server status message (frame type `status`), e.g. a scan starting.
final class PlexStatusEvent extends PlexEvent {
  /// e.g. `Scanning the "Music" section`.
  final String title;

  /// Extra text; often empty.
  final String? description;

  /// e.g. `LIBRARY_UPDATE`.
  final String? notificationName;

  /// Decodes a `StatusNotification` entry.
  PlexStatusEvent.fromJson(super.raw)
      : title = asString(raw['title']) ?? '',
        description = asString(raw['description']),
        notificationName = asString(raw['notificationName']);
}

/// A frame type without a typed event (`progress`, `reachability`,
/// `transcodeSession.update`, `preference`, …). [raw] is the whole frame.
final class PlexUnknownEvent extends PlexEvent {
  /// The frame's `type`.
  final String type;

  /// Wraps a frame of [type].
  const PlexUnknownEvent(this.type, super.raw);
}
