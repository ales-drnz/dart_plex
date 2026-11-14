// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Plex Home, shared users and where a device is.
library;

import '../plex_json.dart';

// ---------------------------------------------------------------------------
// Plex Home, friends and sharing
// ---------------------------------------------------------------------------

/// A member of the account's Plex Home (`plex.tv/api/home/users`): the
/// admin, other full accounts, and managed users.
///
/// Switch to one with `PlexAccountApi.switchHomeUser`.
///
/// {@category Client and sign-in}
final class PlexHomeUser {
  /// Numeric plex.tv id — what `PlexAccountApi.switchHomeUser` takes.
  final int id;

  /// Account UUID.
  final String uuid;

  /// Display name.
  final String title;

  /// Username; empty for a managed user, which has none.
  final String username;

  /// Email; empty for a managed user.
  final String email;

  /// Avatar URL.
  final String? thumb;

  /// Whether this user administers the Home (`admin`).
  final bool admin;

  /// Whether this is the Home's guest account (`guest`).
  final bool guest;

  /// Whether this is a managed user (`restricted`): no plex.tv login of
  /// its own, content limited by [restrictionProfile].
  final bool restricted;

  /// The content restriction of a managed user (`restrictionProfile`):
  /// `little_kid`, `older_kid`, `teen`, or empty for a custom one.
  final String? restrictionProfile;

  /// Whether switching to this user needs a PIN (`protected`).
  final bool protected;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Creates a Home member.
  const PlexHomeUser({
    required this.id,
    required this.uuid,
    required this.title,
    required this.username,
    required this.email,
    required this.admin,
    required this.guest,
    required this.restricted,
    required this.protected,
    this.thumb,
    this.restrictionProfile,
    this.raw = const {},
  });

  /// Parses one `User` of `/api/home/users` (XML or JSON).
  factory PlexHomeUser.fromJson(Map<String, Object?> json) => PlexHomeUser(
    id: asInt(json['id']) ?? 0,
    uuid: asString(json['uuid']) ?? '',
    title: asString(json['title']) ?? '',
    username: asString(json['username']) ?? '',
    email: asString(json['email']) ?? '',
    thumb: asString(json['thumb']),
    admin: asBool(json['admin']),
    guest: asBool(json['guest']),
    restricted: asBool(json['restricted']),
    restrictionProfile: asString(json['restrictionProfile']),
    // Not `hasPassword`: that is the account's own password, "true" for
    // an admin plex.tv lists with `protected="0"`.
    protected: asBool(json['protected']),
    raw: json,
  );
}

/// A user the account shares servers with, or is in a Home with
/// (`plex.tv/api/users/`, python-plexapi's `MyPlexUser`).
///
/// {@category Client and sign-in}
final class PlexAccountUser {
  /// Numeric plex.tv id.
  final int id;

  /// Display name.
  final String title;

  /// Username; empty for a managed user.
  final String username;

  /// Email; empty for a managed user.
  final String email;

  /// Avatar URL.
  final String? thumb;

  /// Whether the user is in the account's Plex Home (`home`).
  final bool home;

  /// Whether this is a managed user (`restricted`).
  final bool restricted;

  /// Whether the user has a Plex Home PIN (`protected`).
  final bool protected;

  /// Whether the user may download (`allowSync`).
  final bool allowSync;

  /// Whether the user may upload from a camera (`allowCameraUpload`).
  final bool allowCameraUpload;

  /// Whether the user may use Live TV tuners (`allowTuners`).
  final bool allowTuners;

  /// The servers shared with this user, and how.
  final List<PlexServerShare> servers;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Creates a user entry.
  const PlexAccountUser({
    required this.id,
    required this.title,
    required this.username,
    required this.email,
    required this.home,
    required this.restricted,
    required this.protected,
    required this.allowSync,
    required this.allowCameraUpload,
    required this.allowTuners,
    required this.servers,
    this.thumb,
    this.raw = const {},
  });

  /// Parses one `User` of `/api/users/` (XML or JSON).
  factory PlexAccountUser.fromJson(Map<String, Object?> json) {
    final servers = json['Server'];
    return PlexAccountUser(
      id: asInt(json['id']) ?? 0,
      title: asString(json['title']) ?? '',
      username: asString(json['username']) ?? '',
      email: asString(json['email']) ?? '',
      thumb: asString(json['thumb']),
      home: asBool(json['home']),
      restricted: asBool(json['restricted']),
      protected: asBool(json['protected']),
      allowSync: asBool(json['allowSync']),
      allowCameraUpload: asBool(json['allowCameraUpload']),
      allowTuners: asBool(json['allowTuners']),
      servers: asObjectList(servers, PlexServerShare.fromJson),
      raw: json,
    );
  }
}

/// One server shared with a [PlexAccountUser] (python-plexapi's
/// `MyPlexServerShare`).
///
/// {@category Client and sign-in}
final class PlexServerShare {
  /// Id of the share.
  final int? id;

  /// plex.tv's id of the server (`serverId`).
  final int? serverId;

  /// The server's machine identifier.
  final String machineIdentifier;

  /// The server's name.
  final String name;

  /// When the user last reached the server.
  final DateTime? lastSeenAt;

  /// How many libraries are shared.
  final int? numLibraries;

  /// Whether every library is shared (`allLibraries`).
  final bool allLibraries;

  /// Whether the user owns the server (`owned`).
  final bool owned;

  /// Whether the invitation is still pending (`pending`).
  final bool pending;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Creates a share.
  const PlexServerShare({
    required this.machineIdentifier,
    required this.name,
    required this.allLibraries,
    required this.owned,
    required this.pending,
    this.id,
    this.serverId,
    this.lastSeenAt,
    this.numLibraries,
    this.raw = const {},
  });

  /// Parses one `Server` of a `/api/users/` user.
  factory PlexServerShare.fromJson(Map<String, Object?> json) =>
      PlexServerShare(
        id: asInt(json['id']),
        serverId: asInt(json['serverId']),
        machineIdentifier: asString(json['machineIdentifier']) ?? '',
        name: asString(json['name']) ?? '',
        lastSeenAt: asEpochSeconds(json['lastSeenAt']),
        numLibraries: asInt(json['numLibraries']),
        allLibraries: asBool(json['allLibraries']),
        owned: asBool(json['owned']),
        pending: asBool(json['pending']),
        raw: json,
      );
}

/// A friend of the account (`plex.tv/api/v2/friends`).
///
/// {@category Client and sign-in}
final class PlexFriend {
  /// Numeric plex.tv id.
  final int id;

  /// Account UUID.
  final String uuid;

  /// Display name.
  final String title;

  /// Username.
  final String username;

  /// Email, when plex.tv shows it.
  final String? email;

  /// Avatar URL.
  final String? thumb;

  /// The entry as received: sharing details plex.tv adds live here.
  final Map<String, Object?> raw;

  /// Creates a friend entry.
  const PlexFriend({
    required this.id,
    required this.uuid,
    required this.title,
    required this.username,
    this.email,
    this.thumb,
    this.raw = const {},
  });

  /// Parses one friend.
  factory PlexFriend.fromJson(Map<String, Object?> json) => PlexFriend(
    id: asInt(json['id']) ?? 0,
    uuid: asString(json['uuid']) ?? '',
    title: asString(json['title']) ?? asString(json['username']) ?? '',
    username: asString(json['username']) ?? '',
    email: asString(json['email']),
    thumb: asString(json['thumb']),
    raw: json,
  );
}

/// Where an IP address is, by plex.tv's GeoIP database
/// (`plex.tv/api/v2/geoip`).
///
/// {@category Client and sign-in}
final class PlexGeoLocation {
  /// City.
  final String? city;

  /// ISO country code.
  final String? code;

  /// Country name.
  final String? country;

  /// Continent code.
  final String? continentCode;

  /// Region (state, province).
  final String? subdivisions;

  /// Postal code.
  final String? postalCode;

  /// IANA time zone.
  final String? timeZone;

  /// Latitude, when given.
  final double? latitude;

  /// Longitude, when given.
  final double? longitude;

  /// Whether the country is in the European Union.
  final bool europeanUnionMember;

  /// Whether the country has privacy restrictions.
  final bool inPrivacyRestrictedCountry;

  /// The answer as received.
  final Map<String, Object?> raw;

  /// Creates a location.
  const PlexGeoLocation({
    required this.europeanUnionMember,
    required this.inPrivacyRestrictedCountry,
    this.city,
    this.code,
    this.country,
    this.continentCode,
    this.subdivisions,
    this.postalCode,
    this.timeZone,
    this.latitude,
    this.longitude,
    this.raw = const {},
  });

  /// Parses the answer, in the snake_case plex.tv uses (`continent_code`,
  /// `time_zone`) or camelCase.
  factory PlexGeoLocation.fromJson(Map<String, Object?> json) {
    final src = asObject(json['location']) ?? json;
    final coords = (asString(src['coordinates']) ?? '').split(',');
    return PlexGeoLocation(
      city: asString(src['city']),
      code: asString(src['code']) ?? asString(src['country_code']),
      country: asString(src['country']),
      continentCode:
          asString(src['continent_code']) ?? asString(src['continentCode']),
      subdivisions: asString(src['subdivisions']),
      postalCode: asString(src['postal_code']) ?? asString(src['postalCode']),
      timeZone:
          asString(src['time_zone']) ??
          asString(src['timezone']) ??
          asString(src['timeZone']),
      latitude: coords.length == 2 ? double.tryParse(coords[0].trim()) : null,
      longitude: coords.length == 2 ? double.tryParse(coords[1].trim()) : null,
      europeanUnionMember:
          asBool(src['european_union_member']) ||
          asBool(src['europeanUnionMember']),
      inPrivacyRestrictedCountry:
          asBool(src['in_privacy_restricted_country']) ||
          asBool(src['inPrivacyRestrictedCountry']),
      raw: src,
    );
  }
}
