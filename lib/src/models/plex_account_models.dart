// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of '../plex_models.dart';

// ---------------------------------------------------------------------------
// plex.tv account
// ---------------------------------------------------------------------------

/// User profile returned by `/api/v2/user` and `/users/sign_in.json`.
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

  /// Creates a user with the given fields; [thumb] is optional.
  const PlexUser({
    required this.id,
    required this.uuid,
    required this.username,
    required this.email,
    required this.authToken,
    required this.hasPlexPass,
    this.thumb,
  });

  /// Parses either the flat `/api/v2/user` shape or the legacy
  /// `{"user": {...}}` envelope returned by `/users/sign_in.json`.
  factory PlexUser.fromJson(Map<String, Object?> json) {
    // Legacy /users/sign_in.json wraps it in {"user": {...}}; v2 returns flat.
    final src = json['user'] is Map<String, Object?>
        ? json['user'] as Map<String, Object?>
        : json;
    final subs = src['subscription'];
    return PlexUser(
      id: asInt(src['id']) ?? 0,
      uuid: asString(src['uuid']) ?? '',
      username: asString(src['username']) ?? '',
      email: asString(src['email']) ?? '',
      thumb: asString(src['thumb']),
      authToken:
          asString(src['authToken']) ?? asString(src['auth_token']) ?? '',
      hasPlexPass: subs is Map &&
          (subs['active'] == true || asString(subs['status']) == 'Active'),
    );
  }
}

/// One server entry from `plex.tv/api/v2/resources`.
///
/// `connections` is the list of candidate URIs to reach the server —
/// pick the best one with [bestConnection].
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
      owned: json['owned'] == true,
      home: json['home'] == true,
      synced: json['synced'] == true,
      relay: json['relay'] == true,
      presence: json['presence'] == true,
      httpsRequired: json['httpsRequired'] == true,
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
    );
  }

  /// Whether this resource is a Plex Media Server (vs. a player/client).
  bool get isServer => provides.contains('server');

  /// Pick the most desirable connection URI in this order:
  ///   1. local, non-relay
  ///   2. https, non-relay
  ///   3. any non-relay
  ///   4. relay (last resort)
  PlexServerConnection? bestConnection() {
    if (connections.isEmpty) return null;
    final localDirect =
        connections.where((c) => c.local && !c.relay).toList(growable: false);
    if (localDirect.isNotEmpty) return localDirect.first;
    final httpsDirect = connections
        .where((c) => c.protocol == 'https' && !c.relay)
        .toList(growable: false);
    if (httpsDirect.isNotEmpty) return httpsDirect.first;
    final direct = connections.where((c) => !c.relay).toList(growable: false);
    if (direct.isNotEmpty) return direct.first;
    return connections.first;
  }
}

/// One candidate URI to reach a [PlexResource]. Roughly:
///   `https://192-168-0-2.{uuid}.plex.direct:32400` for local-https
///   `https://1-2-3-4.{uuid}.plex.direct:32400`     for remote-https
///   `https://relay-…plex.tv`                       for relay
final class PlexServerConnection {
  /// `http` or `https`.
  final String protocol;

  /// Raw address (IP or hostname) advertised by the server.
  final String address;

  /// Listening port (typically `32400`).
  final int port;

  /// Full URI (`protocol://address:port`) ready to use.
  final String uri;

  /// True when this candidate is on the same LAN as the requesting client.
  final bool local;

  /// True when reachable only through Plex Relay.
  final bool relay;

  /// True when [address] is an IPv6 literal.
  final bool ipv6;

  /// Creates a connection candidate.
  const PlexServerConnection({
    required this.protocol,
    required this.address,
    required this.port,
    required this.uri,
    required this.local,
    required this.relay,
    required this.ipv6,
  });

  /// Parses one `<Connection>` entry from a `/api/v2/resources` payload.
  factory PlexServerConnection.fromJson(Map<String, Object?> json) =>
      PlexServerConnection(
        protocol: asString(json['protocol']) ?? '',
        address: asString(json['address']) ?? '',
        port: asInt(json['port']) ?? 0,
        uri: asString(json['uri']) ?? '',
        local: json['local'] == true,
        relay: json['relay'] == true,
        ipv6: json['IPv6'] == true || json['ipv6'] == true,
      );
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
