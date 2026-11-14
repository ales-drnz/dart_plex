// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// DVRs, tuners and their channels.
library;

import '../parsing/plex_json.dart';

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
