// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';

import 'api/plex_account_api.dart';
import 'plex_client.dart';
import 'plex_error_type.dart';
import 'plex_exception.dart';

/// The Ed25519 key pair a device signs in to plex.tv with.
///
/// plex.tv's JWT sign-in ([PlexAccountApi.createJwtPin],
/// [PlexAccountApi.refreshJwt]) identifies a device by the public half of
/// this key, registered once as a JSON Web Key. Every later token is
/// obtained by signing a short-lived JWT with the private half — no
/// password and no long-lived token involved. Generate the key once per
/// install and persist it with [toJson]: a lost key means signing in
/// again.
///
/// The signing is pure Dart (`package:cryptography`'s `DartEd25519`), so
/// it runs the same on every platform, the web included.
///
/// {@category Client and sign-in}
final class PlexDeviceKey {
  final Uint8List _privateKey;
  final Uint8List _publicKey;

  /// The 32-byte private seed (RFC 8032's "secret key"), as a copy. Keep
  /// it secret.
  Uint8List get privateKey => Uint8List.fromList(_privateKey);

  /// The 32-byte public key, derived from [privateKey], as a copy.
  Uint8List get publicKey => Uint8List.fromList(_publicKey);

  /// The key id sent as `kid`: the RFC 7638 JWK thumbprint of the public
  /// key (base64url SHA-256 of `{"crv":"Ed25519","kty":"OKP","x":…}`).
  final String keyId;

  PlexDeviceKey._(this._privateKey, this._publicKey, this.keyId);

  static final DartEd25519 _ed25519 = DartEd25519(sha512: const DartSha512());

  /// A new key pair from a cryptographically secure random seed.
  static Future<PlexDeviceKey> generate() {
    final random = Random.secure();
    return fromSeed([for (var i = 0; i < 32; i++) random.nextInt(256)]);
  }

  /// The key pair of a 32-byte [seed] (the private key).
  ///
  /// Throws an [ArgumentError] when [seed] is not 32 bytes long.
  static Future<PlexDeviceKey> fromSeed(List<int> seed) async {
    if (seed.length != 32) {
      throw ArgumentError.value(seed.length, 'seed', 'must be 32 bytes');
    }
    final pair = await _ed25519.newKeyPairFromSeed(seed);
    final public = Uint8List.fromList((await pair.extractPublicKey()).bytes);
    return PlexDeviceKey._(
      Uint8List.fromList(seed),
      public,
      thumbprint(public),
    );
  }

  /// Reads what [toJson] wrote (a private JWK). Throws a [FormatException]
  /// when the JSON is not an Ed25519 key, or its `x` does not belong to
  /// its `d`.
  static Future<PlexDeviceKey> fromJson(Map<String, Object?> json) async {
    if (json['kty'] != 'OKP' || json['crv'] != 'Ed25519') {
      throw const FormatException('Not an Ed25519 JWK');
    }
    final d = json['d'];
    if (d is! String) throw const FormatException('The JWK has no "d"');
    final key = await fromSeed(_base64UrlDecode(d));
    final x = json['x'];
    if (x is String && x != _base64UrlEncode(key._publicKey)) {
      throw const FormatException('The JWK "x" does not match its "d"');
    }
    return key;
  }

  /// The key pair as a private JWK — `kty`, `crv`, `x`, `d`, `kid` — to
  /// persist in secure storage (Keychain, Keystore, …) and read back with
  /// [fromJson].
  Map<String, Object?> toJson() => {
    'kty': 'OKP',
    'crv': 'Ed25519',
    'x': _base64UrlEncode(_publicKey),
    'd': _base64UrlEncode(_privateKey),
    'kid': keyId,
  };

  /// The public JWK registered with plex.tv: `kty`, `crv`, `x`, `kid`,
  /// `use` and `alg`. Holds nothing secret.
  Map<String, Object?> get publicJwk => {
    'kty': 'OKP',
    'crv': 'Ed25519',
    'x': _base64UrlEncode(_publicKey),
    'kid': keyId,
    'use': 'sig',
    'alg': 'EdDSA',
  };

  /// The RFC 7638 thumbprint of an Ed25519 public key.
  static String thumbprint(List<int> publicKey) {
    final canonical =
        '{"crv":"Ed25519","kty":"OKP","x":"'
        '${_base64UrlEncode(publicKey)}"}';
    return _base64UrlEncode(
      const DartSha256().hashSync(utf8.encode(canonical)).bytes,
    );
  }

  /// The raw Ed25519 signature of [message] (64 bytes).
  Future<Uint8List> sign(List<int> message) async {
    final pair = await _ed25519.newKeyPairFromSeed(_privateKey);
    final signature = await _ed25519.sign(message, keyPair: pair);
    return Uint8List.fromList(signature.bytes);
  }

  /// A compact JWT of [claims], signed with this key: header
  /// `{"alg":"EdDSA","typ":"JWT","kid":keyId}`.
  Future<String> signJwt(Map<String, Object?> claims) async {
    final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': keyId};
    final input = '${_segment(header)}.${_segment(claims)}';
    final signature = await sign(utf8.encode(input));
    return '$input.${_base64UrlEncode(signature)}';
  }

  /// The device JWT plex.tv exchanges for a token: `aud` `plex.tv`, `iss`
  /// [clientIdentifier], the [nonce] from `/auth/nonce` when given,
  /// `scope` (comma-separated [scopes]) and a [lifetime] from [now].
  Future<String> deviceJwt({
    required String clientIdentifier,
    String? nonce,
    List<String> scopes = PlexJwt.allScopes,
    DateTime? now,
    Duration lifetime = const Duration(minutes: 5),
  }) {
    final issued = (now ?? DateTime.now()).toUtc();
    final iat = issued.millisecondsSinceEpoch ~/ 1000;
    return signJwt({
      'nonce': ?nonce,
      'scope': scopes.join(','),
      'aud': 'plex.tv',
      'iss': clientIdentifier,
      'iat': iat,
      'exp': iat + lifetime.inSeconds,
    });
  }

  static String _segment(Map<String, Object?> json) =>
      _base64UrlEncode(utf8.encode(jsonEncode(json)));
}

/// A token plex.tv issued, with what its claims say about its lifetime.
///
/// A JWT from plex.tv lasts 7 days and can be refreshed at any time, also
/// after it has expired ([PlexAccountApi.refreshJwt]). A legacy token is
/// not a JWT: [PlexJwt.parse] still accepts it, with no expiry ([expiresAt] is
/// `null`), so code that handles both does not branch.
///
/// The claims are read, not verified: the token came from plex.tv over
/// HTTPS, and it is plex.tv and the servers that check it.
///
/// {@category Client and sign-in}
final class PlexJwt {
  /// The token, to send as `X-Plex-Token`.
  final String token;

  /// The decoded payload; empty for a token that is not a JWT.
  final Map<String, Object?> claims;

  /// Every scope the JWT can carry: what plex.tv puts in the token about
  /// the user. The device JWT asks for these by default.
  static const List<String> allScopes = [
    'username',
    'email',
    'friendly_name',
    'restricted',
    'anonymous',
    'joinedAt',
  ];

  /// When this object was made: the local time the token was received,
  /// for a token read from an answer.
  final DateTime _receivedAt;

  PlexJwt._(this.token, this.claims) : _receivedAt = DateTime.now().toUtc();

  /// Reads [token]'s payload. A token that is not a three-part JWT, or
  /// whose payload is not JSON, is kept with no claims.
  ///
  /// Throws a [PlexException] of type [PlexErrorType.parse] when `exp` or
  /// `iat` is not a time in seconds, or `thumbprint` not a string.
  factory PlexJwt.parse(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return PlexJwt._(token, const {});
    final Object? payload;
    try {
      payload = jsonDecode(utf8.decode(_base64UrlDecode(parts[1])));
    } on FormatException {
      return PlexJwt._(token, const {});
    }
    if (payload is! Map<String, Object?>) return PlexJwt._(token, const {});
    for (final name in const ['exp', 'iat']) {
      final v = payload[name];
      if (v != null && _epoch(v) == null) throw _badClaim(name, v);
    }
    final thumbprint = payload['thumbprint'];
    if (thumbprint != null && thumbprint is! String) {
      throw _badClaim('thumbprint', thumbprint);
    }
    return PlexJwt._(token, payload);
  }

  static PlexException _badClaim(String name, Object value) => PlexException(
    'The JWT claim "$name" is not valid: $value',
    type: PlexErrorType.parse,
  );

  /// Whether [token] is a JWT with claims (a legacy token is not).
  bool get isJwt => claims.isNotEmpty;

  /// When the token expires (`exp`), or `null` when it does not say.
  DateTime? get expiresAt => _epoch(claims['exp']);

  /// When it was issued (`iat`).
  DateTime? get issuedAt => _epoch(claims['iat']);

  /// The thumbprint of the device key the token is bound to
  /// (`thumbprint`), when plex.tv put one in.
  String? get thumbprint => claims['thumbprint'] as String?;

  /// `exp - iat`: how long the token was issued for, or `null` when a
  /// claim is missing.
  Duration? get _lifetime {
    final exp = expiresAt;
    final iat = issuedAt;
    return exp == null || iat == null ? null : exp.difference(iat);
  }

  /// Whether [expiresAt] has passed (compared with [now], or the clock).
  bool isExpired([DateTime? now]) => expiresWithin(Duration.zero, now);

  /// Whether the token expires within [margin] of [now]. `false` for a
  /// token with no expiry.
  bool expiresWithin(Duration margin, [DateTime? now]) {
    final exp = expiresAt;
    if (exp == null) return false;
    return !(now ?? DateTime.now()).toUtc().add(margin).isBefore(exp);
  }

  /// Seconds since the epoch, or `null` when [v] is not a number in
  /// [DateTime]'s range.
  static DateTime? _epoch(Object? v) {
    if (v is! num || !v.isFinite || v.abs() > 8640000000000) return null;
    return DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000, isUtc: true);
  }

  @override
  String toString() => 'PlexJwt(expiresAt: $expiresAt)';
}

/// A device's plex.tv sign-in: its [key] and current [token], kept fresh.
///
/// Hand it to [PlexClient.useJwt]: the client refreshes the token when it
/// is about to expire or a server refuses it as expired, and calls
/// [onChanged] each time, so the app can persist the session with
/// [toJson]:
///
/// ```dart
/// final session = await PlexJwtSession.fromJson(
///   jsonDecode(await storage.read('plex')) as Map<String, Object?>,
///   onChanged: (s) => storage.write('plex', jsonEncode(s.toJson())),
/// );
/// await plex.useJwt(session);
/// ```
///
/// {@category Client and sign-in}
final class PlexJwtSession {
  /// The device key. Never changes for a session.
  final PlexDeviceKey key;

  /// What the device JWT asks plex.tv to put in the token.
  final List<String> scopes;

  /// How long before [PlexJwt.expiresAt] the token is renewed ahead of
  /// time (a day by default, as python-plexapi does). For a token issued
  /// for less than twice that, half its lifetime instead.
  final Duration refreshBefore;

  /// Called after each change of [token], to persist the session.
  final void Function(PlexJwtSession session)? onChanged;

  PlexJwt? _token;

  /// Whether [_token] was received in this run (a refresh or
  /// [updateToken]), so that its local receipt time is known.
  bool _received = false;
  Future<PlexJwt>? _refreshing;

  /// A session for [key], with the [token] already obtained, if any.
  PlexJwtSession({
    required this.key,
    PlexJwt? token,
    this.scopes = PlexJwt.allScopes,
    this.refreshBefore = const Duration(days: 1),
    this.onChanged,
  }) : _token = token;

  /// Reads what [toJson] wrote.
  static Future<PlexJwtSession> fromJson(
    Map<String, Object?> json, {
    void Function(PlexJwtSession session)? onChanged,
    Duration refreshBefore = const Duration(days: 1),
  }) async {
    final key = json['key'];
    if (key is! Map<String, Object?>) {
      throw const FormatException('The session has no "key"');
    }
    final token = json['token'];
    final scopes = json['scopes'];
    return PlexJwtSession(
      key: await PlexDeviceKey.fromJson(key),
      token: token is String ? PlexJwt.parse(token) : null,
      scopes: scopes is List
          ? [for (final s in scopes) '$s']
          : PlexJwt.allScopes,
      refreshBefore: refreshBefore,
      onChanged: onChanged,
    );
  }

  /// The session as JSON: the private key, the token and the scopes.
  /// Secret: store it where the platform keeps secrets.
  Map<String, Object?> toJson() => {
    'key': key.toJson(),
    if (_token != null) 'token': _token!.token,
    'scopes': scopes,
  };

  /// The current token, or `null` before the first sign-in.
  PlexJwt? get token => _token;

  /// Whether the token is missing, expired, or expires within
  /// [refreshBefore].
  ///
  /// A token received in this run is timed from when it arrived, by its
  /// `exp - iat`, so a device clock that disagrees with plex.tv's does not
  /// make every call refresh it.
  bool get needsRefresh => _expiresWithin(_margin);

  /// [refreshBefore], or half the token's lifetime when that is shorter.
  Duration get _margin {
    final lifetime = _token?._lifetime;
    if (lifetime == null || lifetime > refreshBefore * 2) return refreshBefore;
    return lifetime ~/ 2;
  }

  bool _expiresWithin(Duration margin) {
    final t = _token;
    if (t == null) return true;
    final lifetime = t._lifetime;
    if (_received && lifetime != null) {
      final now = DateTime.now().toUtc();
      return !now.add(margin).isBefore(t._receivedAt.add(lifetime));
    }
    return t.expiresWithin(margin);
  }

  /// Replaces the token (after a PIN sign-in, say) and calls [onChanged].
  void updateToken(PlexJwt token) {
    _token = token;
    _received = true;
    onChanged?.call(this);
  }

  /// Refreshes the token through [account], once even when several
  /// callers ask at the same time.
  ///
  /// Throws a [PlexException] of type [PlexErrorType.auth] when plex.tv
  /// answers a token bound to another key (its `thumbprint` is not
  /// [PlexDeviceKey.keyId]), and one of type [PlexErrorType.unknown] when
  /// [onChanged] throws; the new token is kept then.
  Future<PlexJwt> refresh(PlexAccountApi account) => _refreshing ??= () async {
    try {
      final fresh = await account.refreshJwt(key: key, scopes: scopes);
      final thumbprint = fresh.thumbprint;
      if (thumbprint != null && thumbprint != key.keyId) {
        throw const PlexException(
          'plex.tv answered a token bound to another device key',
          type: PlexErrorType.auth,
        );
      }
      try {
        updateToken(fresh);
      } on Object catch (e, st) {
        throw PlexException(
          'PlexJwtSession.onChanged threw: $e',
          cause: e,
          stackTrace: st,
        );
      }
      return fresh;
    } finally {
      _refreshing = null;
    }
  }();

  /// The token, refreshed first when [needsRefresh].
  Future<PlexJwt> freshToken(PlexAccountApi account) async {
    final t = _token;
    if (t != null && !needsRefresh) return t;
    try {
      return await refresh(account);
    } on PlexException catch (e) {
      // Still valid for a while: a failed early refresh is not fatal.
      if (t != null &&
          identical(t, _token) &&
          !_expiresWithin(Duration.zero) &&
          !e.isAuthError) {
        return t;
      }
      rethrow;
    }
  }
}

/// base64url without the `=` padding, as JOSE writes it.
String _base64UrlEncode(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// Decodes base64url with or without padding.
Uint8List _base64UrlDecode(String text) =>
    base64Url.decode(base64Url.normalize(text));

/// A [PlexException] for a plex.tv answer that lacks what it should carry.
PlexException missingField(String what, String route) => PlexException(
  'plex.tv answered $route without $what',
  type: PlexErrorType.parse,
  path: route,
);
