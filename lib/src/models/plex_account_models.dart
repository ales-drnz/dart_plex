// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of '../plex_models.dart';

// ---------------------------------------------------------------------------
// plex.tv account
// ---------------------------------------------------------------------------

/// User profile returned by `/api/v2/user`, `/users/sign_in.json` and
/// a Plex Home switch.
///
/// {@category Client and sign-in}
final class PlexUser {
  /// Numeric plex.tv account id.
  final int id;

  /// Stable account UUID.
  final String uuid;

  /// Plex username (handle).
  final String username;

  /// Account email address.
  final String email;

  /// Avatar URL, when the user has set one.
  final String? thumb;

  /// X-Plex-Token used to authenticate subsequent requests as this user.
  final String authToken;

  /// Whether the account currently has an active Plex Pass subscription.
  final bool hasPlexPass;

  /// Display name: the username, or the name of a managed user.
  final String? title;

  /// Whether this is a managed user of a Plex Home (`restricted`).
  final bool restricted;

  /// Whether the account is in a Plex Home (`home`).
  final bool home;

  /// Whether it administers that Home (`homeAdmin`).
  final bool homeAdmin;

  /// Whether the account has a Plex Home PIN (`protected`).
  final bool protected;

  /// The Plex Pass features the account has (`subscription.features`).
  final List<String> subscriptionFeatures;

  /// The answer as received, for fields not lifted here.
  final Map<String, Object?> raw;

  /// Creates a user with the given fields; [thumb] is optional.
  const PlexUser({
    required this.id,
    required this.uuid,
    required this.username,
    required this.email,
    required this.authToken,
    required this.hasPlexPass,
    this.thumb,
    this.title,
    this.restricted = false,
    this.home = false,
    this.homeAdmin = false,
    this.protected = false,
    this.subscriptionFeatures = const [],
    this.raw = const {},
  });

  /// Parses either the flat `/api/v2/user` shape or the legacy
  /// `{"user": {...}}` envelope returned by `/users/sign_in.json` (and, as
  /// XML, by a Plex Home switch).
  factory PlexUser.fromJson(Map<String, Object?> json) {
    // Legacy /users/sign_in.json wraps it in {"user": {...}}; v2 returns flat.
    final wrapped = json['user'];
    final src = wrapped is Map<String, Object?>
        ? wrapped
        : wrapped is List && wrapped.firstOrNull is Map<String, Object?>
        ? wrapped.first as Map<String, Object?>
        : json;
    final subs = _first(src['subscription']);
    final features = subs?['features'] ?? subs?['feature'];
    return PlexUser(
      id: asInt(src['id']) ?? 0,
      uuid: asString(src['uuid']) ?? '',
      username: asString(src['username']) ?? '',
      email: asString(src['email']) ?? '',
      thumb: asString(src['thumb']),
      authToken:
          asString(src['authToken']) ??
          asString(src['auth_token']) ??
          asString(src['authenticationToken']) ??
          '',
      hasPlexPass:
          subs != null &&
          (asBool(subs['active']) || asString(subs['status']) == 'Active'),
      title: asString(src['title']),
      restricted: asBool(src['restricted']),
      home: asBool(src['home']),
      homeAdmin: asBool(src['homeAdmin']),
      protected: asBool(src['protected']),
      subscriptionFeatures: [
        if (features is List)
          for (final f in features)
            if (f is Map) ?asString(f['id']) else ?asString(f),
      ],
      raw: src,
    );
  }
}

/// [v] itself when it is a map, its first element when it is a list of
/// maps (the XML shape of a single child).
Map<String, Object?>? _first(Object? v) => switch (v) {
  final Map<String, Object?> m => m,
  [final Map<String, Object?> m, ...] => m,
  _ => null,
};

/// One server entry from `plex.tv/api/v2/resources`.
///
/// `connections` is the list of candidate URIs to reach the server —
/// pick the best one with [bestConnection].
///
/// {@category Client and sign-in}
final class PlexResource {
  /// Friendly display name of the resource (server or player).
  final String name;

  /// Stable per-install identifier (matches `X-Plex-Client-Identifier`).
  final String clientIdentifier;

  /// Product name, e.g. `Plex Media Server` or `Plex for iOS`.
  final String product;

  /// Product version string reported by the resource.
  final String productVersion;

  /// Host platform, e.g. `Linux`, `macOS`, `iOS`.
  final String platform;

  /// Optional device descriptor (model / form factor).
  final String? device;

  /// True when the resource is owned by the authenticated account.
  final bool owned;

  /// True when shared via Plex Home.
  final bool home;

  /// True when this is a synced/cloud resource.
  final bool synced;

  /// True when only reachable via Plex Relay (no direct path).
  final bool relay;

  /// True when the resource is currently online / presencing.
  final bool presence;

  /// True when the server requires HTTPS for non-local traffic.
  final bool httpsRequired;

  /// Account-scoped access token to use when connecting to this resource.
  final String accessToken;

  /// Public (WAN) IP address last reported by the resource, if any.
  final String? publicAddress;

  /// Capabilities advertised by the resource (`server`, `player`,
  /// `controller`, …), split and trimmed from Plex's comma-separated
  /// string. Empty when the resource advertises nothing.
  final List<String> provides;

  /// Candidate URIs to reach the resource — pass through [bestConnection]
  /// for the preferred one.
  final List<PlexServerConnection> connections;

  /// The entry as received, for fields not lifted here.
  final Map<String, Object?> raw;

  /// Creates a resource record; [device] and [publicAddress] are optional.
  const PlexResource({
    required this.name,
    required this.clientIdentifier,
    required this.product,
    required this.productVersion,
    required this.platform,
    required this.owned,
    required this.home,
    required this.synced,
    required this.relay,
    required this.presence,
    required this.httpsRequired,
    required this.accessToken,
    required this.provides,
    required this.connections,
    this.device,
    this.publicAddress,
    this.raw = const {},
  });

  /// Parses one resource entry from `plex.tv/api/v2/resources`, including
  /// its nested `connections` array.
  factory PlexResource.fromJson(Map<String, Object?> json) {
    final conns = json['connections'];
    return PlexResource(
      name: asString(json['name']) ?? '',
      clientIdentifier: asString(json['clientIdentifier']) ?? '',
      product: asString(json['product']) ?? '',
      productVersion: asString(json['productVersion']) ?? '',
      platform: asString(json['platform']) ?? '',
      device: asString(json['device']),
      owned: asBool(json['owned']),
      home: asBool(json['home']),
      synced: asBool(json['synced']),
      relay: asBool(json['relay']),
      presence: asBool(json['presence']),
      httpsRequired: asBool(json['httpsRequired']),
      accessToken: asString(json['accessToken']) ?? '',
      publicAddress: asString(json['publicAddress']),
      provides: (asString(json['provides']) ?? '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false),
      connections: [
        if (conns is List)
          for (final c in conns)
            if (c is Map<String, Object?>) PlexServerConnection.fromJson(c),
      ],
      raw: json,
    );
  }

  /// Whether this resource is a Plex Media Server (vs. a player/client).
  bool get isServer => provides.contains('server');

  /// The connections worth trying, best first: local before remote before
  /// relay, HTTPS before HTTP, IPv4 before IPv6 (python-plexapi's order).
  ///
  /// The local addresses of a server neither owned nor shared through
  /// Plex Home are left out: they are on its owner's network, not yours.
  /// [PlexClient.connectToResource] tries them all in parallel.
  List<PlexServerConnection> rankedConnections() {
    final usable = [
      for (final c in connections)
        if (owned || home || !c.local || c.relay) c,
    ];
    int rank(PlexServerConnection c) =>
        c.kind.index * 4 + (c.protocol == 'https' ? 0 : 2) + (c.ipv6 ? 1 : 0);
    // A stable sort keeps plex.tv's own order within a rank.
    final indexed = [for (var i = 0; i < usable.length; i++) (i, usable[i])];
    indexed.sort((a, b) {
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
    return [for (final (_, c) in indexed) c];
  }

  /// The first of [rankedConnections], without checking that it answers;
  /// `null` when there is none. To pick one that answers, use
  /// [PlexClient.connectToResource].
  PlexServerConnection? bestConnection() =>
      rankedConnections().firstOrNull ?? connections.firstOrNull;
}

/// How a [PlexServerConnection] reaches the server, from what plex.tv
/// says about it.
///
/// It matters for playback: since April 2025 a server owner without a
/// Plex Pass cannot stream personal video to a device on a remote or
/// relay connection, unless that user has a Remote Watch Pass
/// ([PlexErrorType.passRequired]). Relay is also capped in bandwidth.
///
/// {@category Client and sign-in}
enum PlexConnectionKind {
  /// On the server's own network (`local`).
  local,

  /// Over the internet, straight to the server.
  remote,

  /// Through Plex Relay (`relay`), plex.tv's bandwidth-limited proxy.
  relay,
}

/// One candidate URI to reach a [PlexResource]. Roughly:
///   `https://192-168-0-2.{uuid}.plex.direct:32400` for local-https
///   `https://1-2-3-4.{uuid}.plex.direct:32400`     for remote-https
///   `https://relay-…plex.tv`                       for relay
///   `http://[2001:db8::2]:32400`                   for an IPv6 address
///
/// {@category Client and sign-in}
final class PlexServerConnection {
  /// `http` or `https`.
  final String protocol;

  /// Raw address (IP or hostname) advertised by the server.
  final String address;

  /// Listening port (typically `32400`).
  final int port;

  /// Full URI (`protocol://address:port`) ready to use. An IPv6 literal
  /// is in brackets (`http://[2001:db8::2]:32400`), as a URL needs it,
  /// even when plex.tv sent it without.
  final String uri;

  /// True when this candidate is on the same LAN as the requesting client.
  final bool local;

  /// True when reachable only through Plex Relay.
  final bool relay;

  /// True when [address] is an IPv6 literal.
  final bool ipv6;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Creates a connection candidate.
  const PlexServerConnection({
    required this.protocol,
    required this.address,
    required this.port,
    required this.uri,
    required this.local,
    required this.relay,
    required this.ipv6,
    this.raw = const {},
  });

  /// Parses one `<Connection>` entry from a `/api/v2/resources` payload.
  factory PlexServerConnection.fromJson(Map<String, Object?> json) {
    final address = asString(json['address']) ?? '';
    final ipv6 =
        asBool(json['IPv6']) ||
        asBool(json['ipv6']) ||
        (address.contains(':') && !address.contains('.plex.direct'));
    return PlexServerConnection(
      protocol: asString(json['protocol']) ?? '',
      address: address,
      port: asInt(json['port']) ?? 0,
      uri: bracketIpv6(asString(json['uri']) ?? ''),
      local: asBool(json['local']),
      relay: asBool(json['relay']),
      ipv6: ipv6,
      raw: json,
    );
  }

  /// Whether this is a local, remote or relay connection.
  PlexConnectionKind get kind => relay
      ? PlexConnectionKind.relay
      : local
      ? PlexConnectionKind.local
      : PlexConnectionKind.remote;

  /// The plain-HTTP form of the same address (`http://address:port`,
  /// IPv6 in brackets), for a server whose certificate the device cannot
  /// validate. plex.tv lists only [uri].
  String get httpUri {
    final host = address.contains(':') && !address.startsWith('[')
        ? '[$address]'
        : address;
    return 'http://$host:$port';
  }

  /// [url] with an unbracketed IPv6 host put in brackets:
  /// `http://2001:db8::1:32400` becomes `http://[2001:db8::1]:32400`. The
  /// URL is not parsed: one whose host is already in brackets, or whose
  /// host and port hold fewer than two colons, comes back unchanged.
  ///
  /// The last group of an unbracketed address cannot be told from a port,
  /// so the last `:n` is read as the port when there are more than seven
  /// colons or the address uses `::`; `http://2001:db8::1` (no port) is
  /// taken as host `2001:db8:` and port 1 — always send the port.
  static String bracketIpv6(String url) {
    final scheme = url.indexOf('://');
    if (scheme < 0) return url;
    final rest = url.substring(scheme + 3);
    final slash = rest.indexOf('/');
    final authority = slash < 0 ? rest : rest.substring(0, slash);
    final tail = slash < 0 ? '' : rest.substring(slash);
    if (authority.startsWith('[') || ':'.allMatches(authority).length < 2) {
      return url;
    }
    final lastColon = authority.lastIndexOf(':');
    final colons = ':'.allMatches(authority).length;
    final hasPort = colons > 7 || authority.contains('::');
    final host = hasPort ? authority.substring(0, lastColon) : authority;
    final port = hasPort ? authority.substring(lastColon) : '';
    return '${url.substring(0, scheme + 3)}[$host]$port$tail';
  }
}

/// PIN flow state returned by `POST /api/v2/pins` and `GET /api/v2/pins/{id}`.
///
/// The 4-character [code] is what the user types at <https://plex.tv/link>.
/// Poll [PlexAccountApi.pollPin] until [authToken] is non-null, or until
/// [expiresAt] passes.
final class PlexPin {
  /// Server-assigned pin id used to poll for completion.
  final int id;

  /// 4-character code the user types at <https://plex.tv/link>.
  final String code;

  /// Client identifier the pin was created with (must match on poll).
  final String clientIdentifier;

  /// X-Plex-Token, populated once the user has linked the pin; null until
  /// then.
  final String? authToken;

  /// Pin creation timestamp (UTC).
  final DateTime createdAt;

  /// Pin expiry timestamp (UTC); after this the pin can no longer be
  /// completed.
  final DateTime expiresAt;

  /// Creates a pin state snapshot.
  const PlexPin({
    required this.id,
    required this.code,
    required this.clientIdentifier,
    required this.createdAt,
    required this.expiresAt,
    this.authToken,
  });

  /// True once the user has approved the pin and an [authToken] is present.
  bool get isAuthenticated => authToken != null && authToken!.isNotEmpty;

  /// True when [expiresAt] is in the past.
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  /// Parses the response of `POST /api/v2/pins` or `GET /api/v2/pins/{id}`.
  factory PlexPin.fromJson(Map<String, Object?> json) => PlexPin(
    id: asInt(json['id']) ?? 0,
    code: asString(json['code']) ?? '',
    clientIdentifier: asString(json['clientIdentifier']) ?? '',
    authToken: asString(json['authToken']),
    createdAt: asUtcDateTime(json['createdAt']) ?? DateTime.now().toUtc(),
    expiresAt: asUtcDateTime(json['expiresAt']) ?? DateTime.now().toUtc(),
  );
}

// ---------------------------------------------------------------------------
// Plex Home, friends and sharing
// ---------------------------------------------------------------------------

/// A member of the account's Plex Home (`plex.tv/api/home/users`): the
/// admin, other full accounts, and managed users.
///
/// Switch to one with [PlexAccountApi.switchHomeUser].
///
/// {@category Client and sign-in}
final class PlexHomeUser {
  /// Numeric plex.tv id — what [PlexAccountApi.switchHomeUser] takes.
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
    protected: asBool(json['protected']) || asBool(json['hasPassword']),
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
      servers: [
        if (servers is List)
          for (final s in servers)
            if (s is Map<String, Object?>) PlexServerShare.fromJson(s),
      ],
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

/// A device signed in to the account (`plex.tv/api/v2/devices`).
///
/// {@category Client and sign-in}
final class PlexDevice {
  /// Device name.
  final String name;

  /// Its `X-Plex-Client-Identifier` — for a server, its machine
  /// identifier.
  final String clientIdentifier;

  /// Product (`Plex Media Server`, `Plexamp`, …).
  final String product;

  /// Product version.
  final String? productVersion;

  /// Platform.
  final String? platform;

  /// What it provides (`server`, `player`, …).
  final List<String> provides;

  /// The device's own token, when plex.tv lists it (`token` or
  /// `accessToken`). For a server, a legacy token that server accepts:
  /// see [PlexClient.connectToResource].
  final String? token;

  /// When it was last seen.
  final DateTime? lastSeenAt;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Creates a device entry.
  const PlexDevice({
    required this.name,
    required this.clientIdentifier,
    required this.product,
    required this.provides,
    this.productVersion,
    this.platform,
    this.token,
    this.lastSeenAt,
    this.raw = const {},
  });

  /// Parses one device. Timestamps may be epoch seconds or ISO-8601.
  factory PlexDevice.fromJson(Map<String, Object?> json) => PlexDevice(
    name: asString(json['name']) ?? '',
    clientIdentifier: asString(json['clientIdentifier']) ?? '',
    product: asString(json['product']) ?? '',
    productVersion: asString(json['productVersion']),
    platform: asString(json['platform']),
    provides: (asString(json['provides']) ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false),
    token: asString(json['token']) ?? asString(json['accessToken']),
    lastSeenAt:
        asEpochSeconds(json['lastSeenAt']) ?? asUtcDateTime(json['lastSeenAt']),
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
    final src = _first(json['location']) ?? json;
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
