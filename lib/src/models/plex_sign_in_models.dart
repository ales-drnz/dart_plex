// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The plex.tv account and the PIN that signs it in.
library;

import '../parsing/plex_json.dart';

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
    final src = asObject(json['user']) ?? json;
    final subs = asObject(src['subscription']);
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

/// PIN flow state returned by `POST /api/v2/pins` and `GET /api/v2/pins/{id}`.
///
/// The 4-character [code] is what the user types at <https://plex.tv/link>.
/// Poll `PlexAccountApi.pollPin` until [authToken] is non-null, or until
/// [expiresAt] passes.
///
/// {@category Client and sign-in}
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
