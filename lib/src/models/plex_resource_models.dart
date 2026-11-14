// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Servers and devices of a plex.tv account, and how to reach them.
library;

import '../parsing/plex_json.dart';
import '../plex_error_type.dart';

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
      provides: asCsv(json['provides']),
      connections: asObjectList(conns, PlexServerConnection.fromJson),
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
  /// `PlexClient.connectToResource` tries them all in parallel.
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
  /// `PlexClient.connectToResource`.
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
  /// see `PlexClient.connectToResource`.
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
    provides: asCsv(json['provides']),
    token: asString(json['token']) ?? asString(json['accessToken']),
    lastSeenAt:
        asEpochSeconds(json['lastSeenAt']) ?? asUtcDateTime(json['lastSeenAt']),
    raw: json,
  );
}
