// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of '../plex_models.dart';

// ---------------------------------------------------------------------------
// Live TV, DVR, tuners, EPG, recordings
//
// Shapes from the pinned API document; the test server has no tuner, so
// beyond the grabber list and the EPG languages they are not checked
// against a live answer. Every model keeps its entry in `raw`.
// ---------------------------------------------------------------------------

/// A DVR: a lineup with the tuners that record from it (`/livetv/dvrs`).
///
/// {@category Live TV}
final class PlexDvr {
  /// Path of the DVR (`/livetv/dvrs/{id}`), what `PlexLiveTvApi.dvrChannels`
  /// takes.
  final String key;

  /// The DVR's UUID.
  final String? uuid;

  /// Guide language.
  final String? language;

  /// The lineup it records from.
  final String? lineup;

  /// Its tuner devices.
  final List<PlexTunerDevice> devices;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a DVR.
  const PlexDvr({
    required this.key,
    required this.devices,
    this.uuid,
    this.language,
    this.lineup,
    this.raw = const {},
  });

  /// Parses one `Dvr` entry.
  factory PlexDvr.fromJson(Map<String, Object?> json) => PlexDvr(
    key: asString(json['key']) ?? '',
    uuid: asString(json['uuid']),
    language: asString(json['language']),
    lineup: asString(json['lineup']),
    devices: asObjectList(json['Device'], PlexTunerDevice.fromJson),
    raw: json,
  );
}

/// A tuner or other grabber device (`/media/grabbers/devices`).
///
/// {@category Live TV}
final class PlexTunerDevice {
  /// Device id.
  final int? id;

  /// Path of the device.
  final String? key;

  /// UUID.
  final String? uuid;

  /// The device's own identifier.
  final String? deviceIdentifier;

  /// Name.
  final String? name;

  /// Display title.
  final String? title;

  /// Maker.
  final String? make;

  /// Model.
  final String? model;

  /// Model number.
  final String? modelNumber;

  /// Grabber protocol (`livetv`, `stream`, …).
  final String? protocol;

  /// Signal sources (`antenna`, `cable`, …).
  final String? sources;

  /// State.
  final String? state;

  /// Status.
  final String? status;

  /// Whether it is enabled.
  final bool enabled;

  /// Lineup.
  final String? lineup;

  /// Kind of lineup (`lineupType`).
  final String? lineupType;

  /// Number of tuners.
  final int? tuners;

  /// The device's URI.
  final String? uri;

  /// Thumbnail path.
  final String? thumb;

  /// When it was last seen.
  final DateTime? lastSeenAt;

  /// How its channels map to the lineup.
  final List<PlexChannelMapping> channelMappings;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a device.
  const PlexTunerDevice({
    required this.enabled,
    required this.channelMappings,
    this.id,
    this.key,
    this.uuid,
    this.deviceIdentifier,
    this.name,
    this.title,
    this.make,
    this.model,
    this.modelNumber,
    this.protocol,
    this.sources,
    this.state,
    this.status,
    this.lineup,
    this.lineupType,
    this.tuners,
    this.uri,
    this.thumb,
    this.lastSeenAt,
    this.raw = const {},
  });

  /// Parses one `Device` entry.
  factory PlexTunerDevice.fromJson(Map<String, Object?> json) =>
      PlexTunerDevice(
        id: asInt(json['id']),
        key: asString(json['key']),
        uuid: asString(json['uuid']),
        deviceIdentifier: asString(json['deviceIdentifier']),
        name: asString(json['name']),
        title: asString(json['title']),
        make: asString(json['make']),
        model: asString(json['model']),
        modelNumber: asString(json['modelNumber']),
        protocol: asString(json['protocol']),
        sources: asString(json['sources']),
        state: asString(json['state']),
        status: asString(json['status']),
        enabled: asBool(json['enabled']),
        lineup: asString(json['lineup']),
        lineupType: asString(json['lineupType']),
        tuners: asInt(json['tuners']),
        uri: asString(json['uri']),
        thumb: asString(json['thumb']),
        lastSeenAt: asEpochSeconds(json['lastSeenAt']),
        channelMappings: asObjectList(
          json['ChannelMapping'],
          PlexChannelMapping.fromJson,
        ),
        raw: json,
      );
}

/// How a device channel maps to a lineup channel (`ChannelMapping`).
///
/// {@category Live TV}
final class PlexChannelMapping {
  /// The device's channel.
  final String? deviceIdentifier;

  /// The lineup channel key.
  final String? channelKey;

  /// The lineup.
  final String? lineupIdentifier;

  /// Whether the channel is enabled.
  final bool enabled;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a mapping.
  const PlexChannelMapping({
    required this.enabled,
    this.deviceIdentifier,
    this.channelKey,
    this.lineupIdentifier,
    this.raw = const {},
  });

  /// Parses one `ChannelMapping`.
  factory PlexChannelMapping.fromJson(Map<String, Object?> json) =>
      PlexChannelMapping(
        deviceIdentifier: asString(json['deviceIdentifier']),
        channelKey: asString(json['channelKey']),
        lineupIdentifier: asString(json['lineupIdentifier']),
        enabled: asBool(json['enabled']),
        raw: json,
      );
}

/// A grabber type the server supports (`/media/grabbers`).
///
/// {@category Live TV}
final class PlexMediaGrabber {
  /// Name (`HDHomerun`, `Stream`, …).
  final String title;

  /// Identifier (`tv.plex.grabbers.hdhomerun`).
  final String identifier;

  /// Protocol (`livetv`, `stream`, `download`).
  final String protocol;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a grabber.
  const PlexMediaGrabber({
    required this.title,
    required this.identifier,
    required this.protocol,
    this.raw = const {},
  });

  /// Parses one `MediaGrabber`.
  factory PlexMediaGrabber.fromJson(Map<String, Object?> json) =>
      PlexMediaGrabber(
        title: asString(json['title']) ?? '',
        identifier: asString(json['identifier']) ?? '',
        protocol: asString(json['protocol']) ?? '',
        raw: json,
      );
}

/// A channel a tuner device can receive
/// (`/media/grabbers/devices/{id}/channels`).
///
/// {@category Live TV}
final class PlexDeviceChannel {
  /// Channel key.
  final String? key;

  /// Channel identifier.
  final String? identifier;

  /// Name.
  final String? name;

  /// Whether it is DRM-protected.
  final bool drm;

  /// Whether it is a favourite.
  final bool favorite;

  /// Whether it is HD.
  final bool hd;

  /// Signal quality.
  final int? signalQuality;

  /// Signal strength.
  final int? signalStrength;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a channel.
  const PlexDeviceChannel({
    required this.drm,
    required this.favorite,
    required this.hd,
    this.key,
    this.identifier,
    this.name,
    this.signalQuality,
    this.signalStrength,
    this.raw = const {},
  });

  /// Parses one `DeviceChannel`.
  factory PlexDeviceChannel.fromJson(Map<String, Object?> json) =>
      PlexDeviceChannel(
        key: asString(json['key']),
        identifier: asString(json['identifier']),
        name: asString(json['name']),
        drm: asBool(json['drm']),
        favorite: asBool(json['favorite']),
        hd: asBool(json['hd']),
        signalQuality: asInt(json['signalQuality']),
        signalStrength: asInt(json['signalStrength']),
        raw: json,
      );
}

/// A country (or a region of one) with program guide data
/// (`/livetv/epg/countries`, `…/regions`).
///
/// {@category Live TV}
final class PlexEpgCountry {
  /// Path for its lineups or regions.
  final String? key;

  /// Country code.
  final String? code;

  /// Name.
  final String title;

  /// Guide flavour (`flavor`): which kind of lookup it takes.
  final int? flavor;

  /// What to enter, e.g. a postal code example (`example`).
  final String? example;

  /// Language code.
  final String? language;

  /// Language name.
  final String? languageTitle;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a country.
  const PlexEpgCountry({
    required this.title,
    this.key,
    this.code,
    this.flavor,
    this.example,
    this.language,
    this.languageTitle,
    this.raw = const {},
  });

  /// Parses one `Country`.
  factory PlexEpgCountry.fromJson(Map<String, Object?> json) => PlexEpgCountry(
    key: asString(json['key']),
    code: asString(json['code']),
    title: asString(json['title']) ?? '',
    flavor: asInt(json['flavor']),
    example: asString(json['example']),
    language: asString(json['language']),
    languageTitle: asString(json['languageTitle']),
    raw: json,
  );
}

/// A guide language (`/livetv/epg/languages`).
///
/// {@category Live TV}
final class PlexEpgLanguage {
  /// ISO 639-2 code (`eng`).
  final String code;

  /// Name, in that language.
  final String title;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a language.
  const PlexEpgLanguage({
    required this.code,
    required this.title,
    this.raw = const {},
  });

  /// Parses one `Language`.
  factory PlexEpgLanguage.fromJson(Map<String, Object?> json) =>
      PlexEpgLanguage(
        code: asString(json['code']) ?? '',
        title: asString(json['title']) ?? '',
        raw: json,
      );
}

/// A channel lineup (`/livetv/epg/…/lineups`, `lineupchannels`).
///
/// {@category Live TV}
final class PlexLineup {
  /// Path of the lineup.
  final String? key;

  /// Its UUID — what the DVR and channel calls take as `lineup`.
  final String? uuid;

  /// Name.
  final String? title;

  /// Type.
  final String? type;

  /// Identifier.
  final String? identifier;

  /// Kind of lineup (`lineupType`).
  final int? lineupType;

  /// Where it applies.
  final String? location;

  /// Its channels, in a `lineupchannels` answer.
  final List<PlexEpgChannel> channels;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a lineup.
  const PlexLineup({
    required this.channels,
    this.key,
    this.uuid,
    this.title,
    this.type,
    this.identifier,
    this.lineupType,
    this.location,
    this.raw = const {},
  });

  /// Parses one `Lineup`.
  factory PlexLineup.fromJson(Map<String, Object?> json) => PlexLineup(
    key: asString(json['key']),
    uuid: asString(json['uuid']),
    title: asString(json['title']),
    type: asString(json['type']),
    identifier: asString(json['identifier']),
    lineupType: asInt(json['lineupType']),
    location: asString(json['location']),
    channels: asObjectList(json['Channel'], PlexEpgChannel.fromJson),
    raw: json,
  );
}

/// A channel of a lineup (`Channel`).
///
/// {@category Live TV}
final class PlexEpgChannel {
  /// Channel key.
  final String? key;

  /// Identifier.
  final String? identifier;

  /// Name.
  final String? title;

  /// Call sign.
  final String? callSign;

  /// Virtual channel number (`channelVcn`).
  final String? channelVcn;

  /// Language.
  final String? language;

  /// Logo path.
  final String? thumb;

  /// Whether it is DRM-protected.
  final bool drm;

  /// Whether it is a favourite.
  final bool favorite;

  /// Whether it is HD.
  final bool hd;

  /// Signal quality.
  final int? signalQuality;

  /// Signal strength.
  final int? signalStrength;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a channel.
  const PlexEpgChannel({
    required this.drm,
    required this.favorite,
    required this.hd,
    this.key,
    this.identifier,
    this.title,
    this.callSign,
    this.channelVcn,
    this.language,
    this.thumb,
    this.signalQuality,
    this.signalStrength,
    this.raw = const {},
  });

  /// Parses one `Channel`.
  factory PlexEpgChannel.fromJson(Map<String, Object?> json) => PlexEpgChannel(
    key: asString(json['key']),
    identifier: asString(json['identifier']),
    title: asString(json['title']),
    callSign: asString(json['callSign']),
    channelVcn: asString(json['channelVcn']),
    language: asString(json['language']),
    thumb: asString(json['thumb']),
    drm: asBool(json['drm']),
    favorite: asBool(json['favorite']),
    hd: asBool(json['hd']),
    signalQuality: asInt(json['signalQuality']),
    signalStrength: asInt(json['signalStrength']),
    raw: json,
  );
}

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
