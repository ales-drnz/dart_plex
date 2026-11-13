// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of '../plex_models.dart';

// ---------------------------------------------------------------------------
// Server administration: updater, security, background jobs, providers,
// section details, people, playlist generators.
// ---------------------------------------------------------------------------

/// The server's update state (`/updater/status`).
///
/// {@category Server}
final class PlexUpdaterStatus {
  /// Whether a downloaded update can be installed (`canInstall`).
  final bool canInstall;

  /// When the server last checked; `null` when it never did (PMS sends
  /// `-1`).
  final DateTime? checkedAt;

  /// Updater state code (`status`).
  final int? status;

  /// Where the update downloads from.
  final String? downloadUrl;

  /// The release the server would update to automatically.
  final int? autoUpdateVersion;

  /// The releases offered (`Release`).
  final List<PlexRelease> releases;

  /// The answer as received.
  final Map<String, Object?> raw;

  /// Builds a status.
  const PlexUpdaterStatus({
    required this.canInstall,
    required this.releases,
    this.checkedAt,
    this.status,
    this.downloadUrl,
    this.autoUpdateVersion,
    this.raw = const {},
  });

  /// Parses the `MediaContainer` of `/updater/status` (or the answer).
  factory PlexUpdaterStatus.fromJson(Map<String, Object?> json) {
    final src = mediaContainer(json);
    final checked = asInt(src['checkedAt']);
    return PlexUpdaterStatus(
      canInstall: asBool(src['canInstall']),
      checkedAt: checked == null || checked < 0
          ? null
          : asEpochSeconds(checked),
      status: asInt(src['status']),
      downloadUrl: asString(src['downloadURL']),
      autoUpdateVersion: asInt(src['autoUpdateVersion']),
      releases: asObjectList(src['Release'], PlexRelease.fromJson),
      raw: src,
    );
  }
}

/// A server release on offer (`Release`).
///
/// {@category Server}
final class PlexRelease {
  /// Path of the release.
  final String? key;

  /// Version.
  final String? version;

  /// What it adds.
  final String? added;

  /// What it fixes.
  final String? fixed;

  /// Download URL.
  final String? downloadUrl;

  /// State (`notify`, `downloaded`, …).
  final String? state;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a release.
  const PlexRelease({
    this.key,
    this.version,
    this.added,
    this.fixed,
    this.downloadUrl,
    this.state,
    this.raw = const {},
  });

  /// Parses one `Release`.
  factory PlexRelease.fromJson(Map<String, Object?> json) => PlexRelease(
    key: asString(json['key']),
    version: asString(json['version']),
    added: asString(json['added']),
    fixed: asString(json['fixed']),
    downloadUrl: asString(json['downloadURL']),
    state: asString(json['state']),
    raw: json,
  );
}

/// How to reach a source and with which token (`/security/resources`).
///
/// {@category Server}
final class PlexSecurityResource {
  /// Name.
  final String? name;

  /// Client identifier.
  final String? clientIdentifier;

  /// Token for it.
  final String? accessToken;

  /// Its connections.
  final List<PlexServerConnection> connections;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a resource.
  const PlexSecurityResource({
    required this.connections,
    this.name,
    this.clientIdentifier,
    this.accessToken,
    this.raw = const {},
  });

  /// Parses the `Device` of `/security/resources` (an object, or a list
  /// of one).
  factory PlexSecurityResource.fromJson(Map<String, Object?> json) {
    final container = mediaContainer(json);
    final src = asObject(container['Device']) ?? container;
    return PlexSecurityResource(
      name: asString(src['name']),
      clientIdentifier: asString(src['clientIdentifier']),
      accessToken: asString(src['accessToken']),
      connections: asObjectList(
        src['Connection'],
        PlexServerConnection.fromJson,
      ),
      raw: src,
    );
  }
}

/// A background transcode job — an optimize or a sync conversion
/// (`/status/sessions/background`, `TranscodeJob`).
///
/// {@category Server}
final class PlexTranscodeJob {
  /// Title of the item.
  final String? title;

  /// Kind of job.
  final String? type;

  /// Path of the job.
  final String? key;

  /// The item's rating key.
  final String? ratingKey;

  /// Progress, 0–100.
  final double? progress;

  /// Seconds left.
  final int? remaining;

  /// Size, in bytes.
  final int? size;

  /// Speed, relative to real time.
  final double? speed;

  /// The generator that queued it.
  final int? generatorId;

  /// Thumbnail path.
  final String? thumb;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a job.
  const PlexTranscodeJob({
    this.title,
    this.type,
    this.key,
    this.ratingKey,
    this.progress,
    this.remaining,
    this.size,
    this.speed,
    this.generatorId,
    this.thumb,
    this.raw = const {},
  });

  /// Parses one `TranscodeJob`.
  factory PlexTranscodeJob.fromJson(Map<String, Object?> json) =>
      PlexTranscodeJob(
        title: asString(json['title']),
        type: asString(json['type']),
        key: asString(json['key']),
        ratingKey: asString(json['ratingKey']),
        progress: asDouble(json['progress']),
        remaining: asInt(json['remaining']),
        size: asInt(json['size']),
        speed: asDouble(json['speed']),
        generatorId: asInt(json['generatorID']),
        thumb: asString(json['thumb']),
        raw: json,
      );
}

/// A media provider registered on the server (`/media/providers`): the
/// library itself, or an online source.
///
/// {@category Server}
final class PlexMediaProvider {
  /// Identifier (`com.plexapp.plugins.library`, …).
  final String identifier;

  /// Name.
  final String title;

  /// Media types it serves (`video`, `audio`, `photo`).
  final List<String> types;

  /// Protocols (`stream`, `download`, …).
  final List<String> protocols;

  /// What it offers (`Feature`): content, search, timeline, …
  final List<PlexProviderFeature> features;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a provider.
  const PlexMediaProvider({
    required this.identifier,
    required this.title,
    required this.types,
    required this.protocols,
    required this.features,
    this.raw = const {},
  });

  /// Parses one `MediaProvider` (the API document calls it `Provider`).
  factory PlexMediaProvider.fromJson(Map<String, Object?> json) =>
      PlexMediaProvider(
        identifier: asString(json['identifier']) ?? '',
        title: asString(json['title']) ?? '',
        types: asCsv(json['types']),
        protocols: asCsv(json['protocols'] ?? json['Protocol']),
        features: asObjectList(json['Feature'], PlexProviderFeature.fromJson),
        raw: json,
      );
}

/// One feature of a [PlexMediaProvider] (`Feature`).
///
/// {@category Server}
final class PlexProviderFeature {
  /// Kind (`content`, `search`, `timeline`, `playqueue`, …).
  final String type;

  /// Path of the feature, when it has one.
  final String? key;

  /// Flavour (`universal`, `download`).
  final String? flavor;

  /// The entry as received (with its `Directory` list, for `content`).
  final Map<String, Object?> raw;

  /// Builds a feature.
  const PlexProviderFeature({
    required this.type,
    this.key,
    this.flavor,
    this.raw = const {},
  });

  /// Parses one `Feature`.
  factory PlexProviderFeature.fromJson(Map<String, Object?> json) =>
      PlexProviderFeature(
        type: asString(json['type']) ?? '',
        key: asString(json['key']),
        flavor: asString(json['flavor']),
        raw: json,
      );
}

/// A section's details (`/library/sections/{id}`): its views, as
/// directories to browse.
///
/// {@category Library}
final class PlexSectionDetails {
  /// The section id (`librarySectionID`).
  final String? librarySectionId;

  /// Its title (`title1`).
  final String? title;

  /// Content kind (`content`).
  final String? content;

  /// Art path.
  final String? art;

  /// Thumbnail path.
  final String? thumb;

  /// View group (`viewGroup`).
  final String? viewGroup;

  /// Whether items can be downloaded (`allowSync`).
  final bool allowSync;

  /// The views: all items, by genre, by year, search, …
  final List<PlexSectionView> views;

  /// The `MediaContainer` as received, without the views.
  final Map<String, Object?> raw;

  /// Builds details.
  const PlexSectionDetails({
    required this.allowSync,
    required this.views,
    this.librarySectionId,
    this.title,
    this.content,
    this.art,
    this.thumb,
    this.viewGroup,
    this.raw = const {},
  });

  /// Parses the answer.
  factory PlexSectionDetails.fromJson(Map<String, Object?> json) {
    final src = mediaContainer(json);
    return PlexSectionDetails(
      librarySectionId: asString(src['librarySectionID']),
      title: asString(src['title1']),
      content: asString(src['content']),
      art: asString(src['art']),
      thumb: asString(src['thumb']),
      viewGroup: asString(src['viewGroup']),
      allowSync: asBool(src['allowSync']),
      views: asObjectList(src['Directory'], PlexSectionView.fromJson),
      raw: {
        for (final e in src.entries)
          if (e.key != 'Directory') e.key: e.value,
      },
    );
  }
}

/// A view of a section (`Directory` of `/library/sections/{id}`).
///
/// {@category Library}
final class PlexSectionView {
  /// The path, relative to the section (`all`, `genre`, `search?type=8`).
  final String key;

  /// Name.
  final String title;

  /// Whether it lists values to pick (genres, years) rather than items
  /// (`secondary`).
  final bool secondary;

  /// Whether it is a search, which takes `query` (`search`).
  final bool search;

  /// The search prompt.
  final String? prompt;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a view.
  const PlexSectionView({
    required this.key,
    required this.title,
    required this.secondary,
    required this.search,
    this.prompt,
    this.raw = const {},
  });

  /// Parses one `Directory`.
  factory PlexSectionView.fromJson(Map<String, Object?> json) =>
      PlexSectionView(
        key: asString(json['key']) ?? '',
        title: asString(json['title']) ?? '',
        secondary: asBool(json['secondary']),
        search: asBool(json['search']),
        prompt: asString(json['prompt']),
        raw: json,
      );
}
