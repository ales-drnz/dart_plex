// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Typed answers of the server, history and housekeeping endpoints.
///
/// Every model keeps the decoded entry in `raw`, so a field not lifted here
/// is still one map lookup away. Shapes were checked against PMS 1.43.2
/// responses, not only the API document.
library;

/// `GET /identity` — who the server is. Answers without a token.
final class PlexServerIdentity {
  /// The server's unique id — what playlist and play-queue URIs need
  /// (`server://{machineIdentifier}/…`).
  final String machineIdentifier;

  /// Server version, e.g. `1.43.2.10687-563d026ea`.
  final String? version;

  /// API version, e.g. `1.2.2`.
  final String? apiVersion;

  /// Whether the server is claimed by a plex.tv account.
  final bool claimed;

  /// The decoded `MediaContainer`.
  final Map<String, Object?> raw;

  /// Builds an identity from already-parsed components.
  const PlexServerIdentity({
    required this.machineIdentifier,
    required this.claimed,
    required this.raw,
    this.version,
    this.apiVersion,
  });

  /// Decodes the `/identity` `MediaContainer`.
  factory PlexServerIdentity.fromJson(Map<String, Object?> json) =>
      PlexServerIdentity(
        machineIdentifier: _str(json['machineIdentifier']) ?? '',
        version: _str(json['version']),
        apiVersion: _str(json['apiVersion']),
        claimed: json['claimed'] == true || json['claimed'] == 1,
        raw: json,
      );
}

/// `GET /` — the server's capabilities and account state.
final class PlexServerInfo {
  /// Display name.
  final String? friendlyName;

  /// See [PlexServerIdentity.machineIdentifier].
  final String machineIdentifier;

  /// Server version.
  final String? version;

  /// e.g. `Linux`.
  final String? platform;

  /// e.g. the kernel or OS version.
  final String? platformVersion;

  /// Signed in to plex.tv.
  final bool myPlex;

  /// The plex.tv account, when signed in.
  final String? myPlexUsername;

  /// Whether that account has Plex Pass (needed for sonic analysis,
  /// `nearestToTrack` and lyrics).
  final bool myPlexSubscription;

  /// Whether music analysis (sonic) is available.
  final bool musicAnalysis;

  /// Whether the server can transcode audio.
  final bool transcoderAudio;

  /// Whether the server can transcode lyrics.
  final bool transcoderLyrics;

  /// Whether downloads (sync) are allowed.
  final bool allowSync;

  /// Two-letter country code.
  final String? countryCode;

  /// When the server state last changed.
  final DateTime? updatedAt;

  /// The decoded `MediaContainer`.
  final Map<String, Object?> raw;

  /// Builds server info from already-parsed components.
  const PlexServerInfo({
    required this.machineIdentifier,
    required this.myPlex,
    required this.myPlexSubscription,
    required this.musicAnalysis,
    required this.transcoderAudio,
    required this.transcoderLyrics,
    required this.allowSync,
    required this.raw,
    this.friendlyName,
    this.version,
    this.platform,
    this.platformVersion,
    this.myPlexUsername,
    this.countryCode,
    this.updatedAt,
  });

  /// Decodes the `/` `MediaContainer`.
  factory PlexServerInfo.fromJson(Map<String, Object?> json) => PlexServerInfo(
        friendlyName: _str(json['friendlyName']),
        machineIdentifier: _str(json['machineIdentifier']) ?? '',
        version: _str(json['version']),
        platform: _str(json['platform']),
        platformVersion: _str(json['platformVersion']),
        myPlex: _bool(json['myPlex']),
        myPlexUsername: _str(json['myPlexUsername']),
        myPlexSubscription: _bool(json['myPlexSubscription']),
        musicAnalysis: _bool(json['musicAnalysis']),
        transcoderAudio: _bool(json['transcoderAudio']),
        transcoderLyrics: _bool(json['transcoderLyrics']),
        allowSync: _bool(json['allowSync']),
        countryCode: _str(json['countryCode']),
        updatedAt: _epoch(json['updatedAt']),
        raw: json,
      );
}

/// One play in `/status/sessions/history/all`.
final class PlexHistoryEntry {
  /// `/status/sessions/history/{id}` — delete it to forget the play.
  final String historyKey;

  /// Rating key of the item played, when sent.
  final String? ratingKey;

  /// Item title.
  final String title;

  /// Album title, for a track.
  final String? parentTitle;

  /// Artist name, for a track.
  final String? grandparentTitle;

  /// The item kind, as the server spells it (`track`, `episode`, …).
  final String? type;

  /// When it was played.
  final DateTime? viewedAt;

  /// The account that played it.
  final int? accountId;

  /// The device it was played on.
  final int? deviceId;

  /// The section the item belongs to.
  final String? librarySectionId;

  /// The decoded entry.
  final Map<String, Object?> raw;

  /// Builds a history entry from already-parsed components.
  const PlexHistoryEntry({
    required this.historyKey,
    required this.title,
    required this.raw,
    this.ratingKey,
    this.parentTitle,
    this.grandparentTitle,
    this.type,
    this.viewedAt,
    this.accountId,
    this.deviceId,
    this.librarySectionId,
  });

  /// Decodes a history `Metadata` entry.
  factory PlexHistoryEntry.fromJson(Map<String, Object?> json) =>
      PlexHistoryEntry(
        historyKey: _str(json['historyKey']) ?? '',
        ratingKey: _str(json['ratingKey']),
        title: _str(json['title']) ?? '',
        parentTitle: _str(json['parentTitle']),
        grandparentTitle: _str(json['grandparentTitle']),
        type: _str(json['type']),
        viewedAt: _epoch(json['viewedAt']),
        accountId: _int(json['accountID']),
        deviceId: _int(json['deviceID']),
        librarySectionId: _str(json['librarySectionID']),
        raw: json,
      );
}

/// A running background activity (`/activities` → `Activity`), e.g. a
/// library scan. The same activities arrive live as `PlexActivityEvent`s.
final class PlexActivity {
  /// Id, for `activities.cancel`.
  final String uuid;

  /// e.g. `library.update.section`.
  final String type;

  /// e.g. `Scanning Music`.
  final String title;

  /// e.g. the album being scanned.
  final String? subtitle;

  /// 0–100.
  final int? progress;

  /// Whether it can be cancelled.
  final bool cancellable;

  /// The section it works on, when it names one.
  final String? librarySectionId;

  /// The decoded entry.
  final Map<String, Object?> raw;

  /// Builds an activity from already-parsed components.
  const PlexActivity({
    required this.uuid,
    required this.type,
    required this.title,
    required this.cancellable,
    required this.raw,
    this.subtitle,
    this.progress,
    this.librarySectionId,
  });

  /// Decodes an `Activity` entry.
  factory PlexActivity.fromJson(Map<String, Object?> json) {
    final context = json['Context'];
    return PlexActivity(
      uuid: _str(json['uuid']) ?? '',
      type: _str(json['type']) ?? '',
      title: _str(json['title']) ?? '',
      subtitle: _str(json['subtitle']),
      progress: _int(json['progress']),
      cancellable: json['cancellable'] == true,
      librarySectionId: context is Map<String, Object?>
          ? _str(context['librarySectionID'])
          : null,
      raw: json,
    );
  }
}

/// A scheduled maintenance task (`/butler` → `ButlerTask`).
final class PlexButlerTask {
  /// Task name, for `butler.start` / `stop` (e.g. `BackupDatabase`).
  final String name;

  /// Display title.
  final String? title;

  /// What it does.
  final String? description;

  /// Run every this many days.
  final int? intervalDays;

  /// Whether it is scheduled at all.
  final bool enabled;

  /// Whether the start time is randomised inside the maintenance window.
  final bool scheduleRandomized;

  /// The decoded entry.
  final Map<String, Object?> raw;

  /// Builds a butler task from already-parsed components.
  const PlexButlerTask({
    required this.name,
    required this.enabled,
    required this.scheduleRandomized,
    required this.raw,
    this.title,
    this.description,
    this.intervalDays,
  });

  /// Decodes a `ButlerTask` entry.
  factory PlexButlerTask.fromJson(Map<String, Object?> json) => PlexButlerTask(
        name: _str(json['name']) ?? '',
        title: _str(json['title']),
        description: _str(json['description']),
        intervalDays: _int(json['interval']),
        enabled: json['enabled'] == true,
        scheduleRandomized: json['scheduleRandomized'] == true,
        raw: json,
      );
}

/// One server preference (`/:/prefs` → `Setting`).
final class PlexSetting {
  /// Preference id, e.g. `LoudnessAnalysisBehavior`.
  final String id;

  /// Display label.
  final String? label;

  /// Help text.
  final String? summary;

  /// `bool`, `int`, `double` or `text`.
  final String type;

  /// The current value, as the server typed it.
  final Object? value;

  /// The default value.
  final Object? defaultValue;

  /// Hidden from the settings UI.
  final bool hidden;

  /// Listed under "advanced".
  final bool advanced;

  /// Settings group, e.g. `library`.
  final String? group;

  /// The allowed values and their labels, parsed from `enumValues`
  /// (`"never:never|asap:as soon as possible"`); empty when free-form.
  final Map<String, String> enumValues;

  /// The decoded entry.
  final Map<String, Object?> raw;

  /// Builds a setting from already-parsed components.
  const PlexSetting({
    required this.id,
    required this.type,
    required this.hidden,
    required this.advanced,
    required this.enumValues,
    required this.raw,
    this.label,
    this.summary,
    this.value,
    this.defaultValue,
    this.group,
  });

  /// Decodes a `Setting` entry.
  factory PlexSetting.fromJson(Map<String, Object?> json) {
    final enums = <String, String>{};
    final rawEnums = json['enumValues'];
    if (rawEnums is String && rawEnums.isNotEmpty) {
      for (final pair in rawEnums.split('|')) {
        final i = pair.indexOf(':');
        if (i < 0) {
          enums[pair] = pair;
        } else {
          enums[pair.substring(0, i)] = pair.substring(i + 1);
        }
      }
    }
    return PlexSetting(
      id: _str(json['id']) ?? '',
      label: _str(json['label']),
      summary: _str(json['summary']),
      type: _str(json['type']) ?? '',
      value: json['value'],
      defaultValue: json['default'],
      hidden: json['hidden'] == true,
      advanced: json['advanced'] == true,
      group: _str(json['group']),
      enumValues: enums,
      raw: json,
    );
  }
}

String? _str(Object? v) => v == null ? null : '$v';

int? _int(Object? v) => switch (v) {
      int() => v,
      double() => v.toInt(),
      String() => int.tryParse(v),
      _ => null,
    };

bool _bool(Object? v) => v == true || v == 1 || v == '1';

DateTime? _epoch(Object? v) {
  final s = _int(v);
  return s == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);
}
