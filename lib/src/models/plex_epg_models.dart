// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The electronic programme guide.
library;

import '../plex_json.dart';

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
