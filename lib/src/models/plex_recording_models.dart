// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Recording rules and what is being recorded.
library;

import '../plex_json.dart';
import 'plex_metadata_models.dart';

/// A recording rule (`/media/subscriptions`): "record this show", "record
/// this airing".
///
/// {@category Live TV}
final class PlexMediaSubscription {
  /// Path of the subscription; its last segment is the id the other
  /// subscription calls take.
  final String? key;

  /// Title.
  final String? title;

  /// Metadata type it records (`2` show, `4` episode, …).
  final int? type;

  /// Which airings (`New Airings Only`, …).
  final String? airingsType;

  /// When it was created.
  final DateTime? createdAt;

  /// The section recordings go to.
  final int? targetLibrarySectionId;

  /// The folder of that section.
  final int? targetSectionLocationId;

  /// That section's title.
  final String? librarySectionTitle;

  /// That folder's path.
  final String? locationPath;

  /// Total duration recorded, in ms.
  final int? durationTotal;

  /// Total storage used, in bytes.
  final int? storageTotal;

  /// What it records, when it is one item (`Video` or `Directory`).
  final PlexMetadata? item;

  /// Recordings in progress or planned for it (`MediaGrabOperation`).
  final List<PlexMediaGrabOperation> grabs;

  /// Its preferences (`Setting`), as received.
  final List<Map<String, Object?>> settings;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a subscription.
  const PlexMediaSubscription({
    required this.grabs,
    required this.settings,
    this.key,
    this.title,
    this.type,
    this.airingsType,
    this.createdAt,
    this.targetLibrarySectionId,
    this.targetSectionLocationId,
    this.librarySectionTitle,
    this.locationPath,
    this.durationTotal,
    this.storageTotal,
    this.item,
    this.raw = const {},
  });

  /// Parses one `MediaSubscription`.
  factory PlexMediaSubscription.fromJson(Map<String, Object?> json) {
    final item = json['Video'] ?? json['Directory'];
    return PlexMediaSubscription(
      key: asString(json['key']),
      title: asString(json['title']),
      type: asInt(json['type']),
      airingsType: asString(json['airingsType']),
      createdAt: asEpochSeconds(json['createdAt']),
      targetLibrarySectionId: asInt(json['targetLibrarySectionID']),
      targetSectionLocationId: asInt(json['targetSectionLocationID']),
      librarySectionTitle: asString(json['librarySectionTitle']),
      locationPath: asString(json['locationPath']),
      durationTotal: asInt(json['durationTotal']),
      storageTotal: asInt(json['storageTotal']),
      item: item is Map<String, Object?> && item.isNotEmpty
          ? PlexMetadata.fromJson(item)
          : null,
      grabs: asObjectList(
        json['MediaGrabOperation'],
        PlexMediaGrabOperation.fromJson,
      ),
      settings: asObjectList(json['Setting'], (m) => m),
      raw: json,
    );
  }
}

/// A recording, in progress or planned (`MediaGrabOperation`).
///
/// {@category Live TV}
final class PlexMediaGrabOperation {
  /// Its id — what `PlexSubscriptionsApi.cancelGrab` takes.
  final String? id;

  /// Path.
  final String? key;

  /// Status (`scheduled`, `inprogress`, …).
  final String? status;

  /// Progress, 0–100.
  final double? percent;

  /// Bytes recorded so far.
  final int? currentSize;

  /// Grabber identifier.
  final String? grabberIdentifier;

  /// Grabber protocol.
  final String? grabberProtocol;

  /// The subscription it belongs to.
  final int? mediaSubscriptionId;

  /// Provider.
  final String? provider;

  /// What is recorded.
  final PlexMetadata? metadata;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds an operation.
  const PlexMediaGrabOperation({
    this.id,
    this.key,
    this.status,
    this.percent,
    this.currentSize,
    this.grabberIdentifier,
    this.grabberProtocol,
    this.mediaSubscriptionId,
    this.provider,
    this.metadata,
    this.raw = const {},
  });

  /// Parses one `MediaGrabOperation`.
  factory PlexMediaGrabOperation.fromJson(Map<String, Object?> json) {
    final m = json['Metadata'];
    return PlexMediaGrabOperation(
      id: asString(json['id']),
      key: asString(json['key']),
      status: asString(json['status']),
      percent: asDouble(json['percent']),
      currentSize: asInt(json['currentSize']),
      grabberIdentifier: asString(json['grabberIdentifier']),
      grabberProtocol: asString(json['grabberProtocol']),
      mediaSubscriptionId: asInt(json['mediaSubscriptionID']),
      provider: asString(json['provider']),
      metadata: m is Map<String, Object?> ? PlexMetadata.fromJson(m) : null,
      raw: json,
    );
  }
}
