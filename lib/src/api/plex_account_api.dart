// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';
import '../plex_json.dart';
import '../plex_jwt.dart';
import '../plex_models.dart';
import '../plex_query.dart';
import '../plex_session_state.dart';
import '../plex_vocabulary.dart';
import '../plex_xml.dart';
import '../transport/plex_cancel_token.dart';
import '../transport/plex_response.dart';

/// Talks to plex.tv for everything that lives outside a specific Plex
/// Media Server: sign-in (PIN, JWT, password), server discovery, the
/// user's profile, Plex Home, friends, the watchlist.
///
/// plex.tv calls carry the account token ([PlexClient.accountToken]),
/// which after [PlexClient.useJwt] is a JWT this API refreshes when it is
/// about to expire or plex.tv answers `401` / `498` to it.
///
/// {@category Client and sign-in}
class PlexAccountApi {
  static const String _v2 = 'https://plex.tv/api/v2';
  static const String _plexTvLegacy = 'https://plex.tv';
  static const String _clients = 'https://clients.plex.tv/api/v2';
  static const String _discover = 'https://discover.provider.plex.tv';

  final PlexConnection _http;
  final PlexSessionState _state;

  /// Construct from a [PlexConnection]. Typically obtained via
  /// [PlexClient.account].
  PlexAccountApi(this._http, {@internal PlexSessionState? state})
    : _state = state ?? PlexSessionState();

  // -------------------------------------------------------------------------
  // Legacy username/password sign-in
  // -------------------------------------------------------------------------

  /// Authenticate with username and password against the legacy
  /// `/users/sign_in.json` endpoint.
  ///
  /// This is the simplest flow for desktop apps that already collect
  /// credentials, but Plex officially recommends the PIN flow for new
  /// integrations — accounts with 2FA enabled cannot use this path.
  ///
  /// On success the returned [PlexUser] contains `authToken`, a legacy
  /// token. The token is not applied to the client: call
  /// [PlexClient.setToken] with it before the next plex.tv call. The
  /// credentials travel as a form body (`user[login]=…&user[password]=…`),
  /// the shape the endpoint reads.
  Future<PlexUser> signInWithPassword({
    required String username,
    required String password,
  }) async {
    final res = await _http.request<Map<String, Object?>>(
      '$_plexTvLegacy/users/sign_in.json',
      method: 'POST',
      absoluteUrl: true,
      data: {'user[login]': username, 'user[password]': password},
      extraHeaders: const {'Content-Type': 'application/x-www-form-urlencoded'},
    );
    final data = res.data;
    if (data == null) {
      throw const PlexException(
        'Empty response from /users/sign_in.json',
        type: PlexErrorType.parse,
      );
    }
    final user = PlexUser.fromJson(data);
    if (user.authToken.isEmpty) {
      throw const PlexException(
        'Sign-in succeeded but no authToken was returned',
        type: PlexErrorType.auth,
      );
    }
    return user;
  }

  // -------------------------------------------------------------------------
  // PIN flow (legacy token)
  // -------------------------------------------------------------------------

  /// Start a PIN flow that ends with a legacy (non-expiring) token.
  ///
  /// Plex returns a [PlexPin] with a [PlexPin.code] the user enters at
  /// <https://plex.tv/link> (or a longer one, for an Auth App URL, when
  /// [strong]). Poll [pollPin] until [PlexPin.authToken] is non-null, or
  /// until [PlexPin.expiresAt] passes.
  ///
  /// New apps should prefer [createJwtPin], which signs the device in with
  /// a key pair and a 7-day JWT.
  Future<PlexPin> createPin({bool strong = true}) async {
    final res = await _http.request<Map<String, Object?>>(
      '$_v2/pins',
      method: 'POST',
      absoluteUrl: true,
      queryParameters: {'strong': strong ? 'true' : 'false'},
    );
    final data = res.data;
    if (data == null) {
      throw const PlexException(
        'Empty response from POST /pins',
        type: PlexErrorType.parse,
      );
    }
    return PlexPin.fromJson(data);
  }

  /// Poll the state of a previously created PIN.
  ///
  /// The returned pin is the freshest state — once [PlexPin.isAuthenticated]
  /// is true, save [PlexPin.authToken] and stop polling.
  Future<PlexPin> pollPin({required int id}) async {
    final res = await _http.request<Map<String, Object?>>(
      '$_v2/pins/$id',
      absoluteUrl: true,
    );
    final data = res.data;
    if (data == null) {
      throw const PlexException(
        'Empty response from GET /pins/{id}',
        type: PlexErrorType.parse,
      );
    }
    return PlexPin.fromJson(data);
  }

  // -------------------------------------------------------------------------
  // JWT sign-in
  // -------------------------------------------------------------------------

  /// Start a JWT sign-in: a strong PIN that registers [key] with plex.tv
  /// (`POST clients.plex.tv/api/v2/pins` with the public JWK and
  /// `strong: true`).
  ///
  /// Send the user to an Auth App URL built from [PlexPin.code]
  /// ([authAppUrl]), then poll [pollJwtPin] about once a second. A strong
  /// code is too long to type at plex.tv/link; for a 4-character one pass
  /// `strong: false` and show the code.
  ///
  /// ```dart
  /// final key = await PlexDeviceKey.generate();
  /// var pin = await plex.account.createJwtPin(key: key);
  /// launchUrl(plex.account.authAppUrl(pin));
  /// while (!pin.isAuthenticated) {
  ///   await Future<void>.delayed(const Duration(seconds: 1));
  ///   pin = await plex.account.pollJwtPin(id: pin.id, key: key);
  /// }
  /// final session = PlexJwtSession(key: key, token: PlexJwt.parse(pin.authToken!));
  /// await plex.useJwt(session);
  /// ```
  Future<PlexPin> createJwtPin({
    required PlexDeviceKey key,
    bool strong = true,
  }) async {
    final res = await _http.request<Map<String, Object?>>(
      '$_clients/pins',
      method: 'POST',
      absoluteUrl: true,
      data: {'jwk': key.publicJwk, 'strong': strong},
      extraHeaders: const {'X-Plex-Token': ''},
    );
    final data = res.data;
    if (data == null) throw missingField('a pin', '$_clients/pins');
    return PlexPin.fromJson(data);
  }

  /// Poll a pin from [createJwtPin]: `GET clients.plex.tv/api/v2/pins/{id}`
  /// with a device JWT signed by [key]. Once the user has signed in,
  /// [PlexPin.authToken] is the plex.tv JWT (read it with [PlexJwt.parse]).
  ///
  /// The device JWT carries a nonce and lasts five minutes; it is reused
  /// across polls of the same pin — through any [PlexClient.withCancelToken]
  /// view of the client — until a minute before it expires: a nonce is
  /// rate-limited, and polling asks once a second.
  Future<PlexPin> pollJwtPin({
    required int id,
    required PlexDeviceKey key,
    List<String> scopes = PlexJwt.allScopes,
  }) async {
    final now = DateTime.now().toUtc();
    var deviceJwt = _state.pinJwt(id, now);
    if (deviceJwt == null) {
      deviceJwt = await key.deviceJwt(
        clientIdentifier: _http.credentials.clientIdentifier,
        nonce: await authNonce(),
        scopes: scopes,
        now: now,
      );
      _state.keepPinJwt(id, deviceJwt, now.add(const Duration(minutes: 4)));
    }
    final res = await _http.request<Map<String, Object?>>(
      '$_clients/pins/$id',
      absoluteUrl: true,
      queryParameters: {'deviceJWT': deviceJwt},
      extraHeaders: const {'X-Plex-Token': ''},
    );
    final data = res.data;
    if (data == null) throw missingField('a pin', '$_clients/pins/$id');
    final pin = PlexPin.fromJson(data);
    if (pin.isAuthenticated || pin.isExpired) _state.dropPinJwt(id);
    return pin;
  }

  /// The Auth App URL where the user signs in to claim [pin]
  /// (`https://app.plex.tv/auth#?clientID=…&code=…&context[device][product]=…`).
  /// Pass [forwardUrl] for a web app, to come back to it afterwards.
  String authAppUrl(PlexPin pin, {String? forwardUrl}) {
    final c = _http.credentials;
    final params = {
      'clientID': c.clientIdentifier,
      'code': pin.code,
      'context[device][product]': c.product,
      'context[device][version]': c.version,
      'context[device][platform]': c.platform,
      if (c.platformVersion != null)
        'context[device][platformVersion]': c.platformVersion!,
      'context[device][device]': c.device,
      'context[device][deviceName]': c.deviceName,
      'forwardUrl': ?forwardUrl,
    };
    final query = params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    return 'https://app.plex.tv/auth#?$query';
  }

  /// Register [key] with plex.tv using an existing token
  /// (`POST clients.plex.tv/api/v2/auth/jwk`): the way an app signed in
  /// with a legacy token moves to JWTs. [token] defaults to the account
  /// token.
  ///
  /// Then call [refreshJwt] for the first JWT. Plex's documentation says
  /// the legacy token stops working once the device has a JWT.
  Future<void> registerJwtKey({
    required PlexDeviceKey key,
    String? token,
  }) async {
    final auth = token ?? _state.accountToken ?? _http.token;
    if (auth == null) {
      throw const PlexException(
        'Registering a device key needs a token: sign in first.',
        type: PlexErrorType.state,
      );
    }
    await _http.request<void>(
      '$_clients/auth/jwk',
      method: 'POST',
      absoluteUrl: true,
      data: {'jwk': key.publicJwk},
      extraHeaders: {'X-Plex-Token': auth},
    );
  }

  /// A fresh nonce for a device JWT (`GET clients.plex.tv/api/v2/auth/nonce`),
  /// valid five minutes. plex.tv rate-limits it.
  Future<String> authNonce() async {
    final res = await _http.request<Map<String, Object?>>(
      '$_clients/auth/nonce',
      absoluteUrl: true,
      extraHeaders: const {'X-Plex-Token': ''},
    );
    final nonce = res.data?['nonce'];
    if (nonce is! String) throw missingField('a nonce', '$_clients/auth/nonce');
    return nonce;
  }

  /// Exchange a signed device JWT for a plex.tv JWT
  /// (`POST clients.plex.tv/api/v2/auth/token`).
  Future<PlexJwt> exchangeDeviceJwt(String deviceJwt) async {
    final res = await _http.request<Map<String, Object?>>(
      '$_clients/auth/token',
      method: 'POST',
      absoluteUrl: true,
      data: {'jwt': deviceJwt},
      extraHeaders: const {'X-Plex-Token': ''},
    );
    final data = res.data ?? const {};
    // Plex's documentation shows `auth_token`, the community document
    // `authToken`: take either.
    final token = data['auth_token'] ?? data['authToken'];
    if (token is! String || token.isEmpty) {
      throw missingField('a token', '$_clients/auth/token');
    }
    return PlexJwt.parse(token);
  }

  /// A new plex.tv JWT for the device of [key]: a nonce, a device JWT
  /// signed with [key], and the exchange. No token is needed, so it works
  /// after the old JWT expired — the refresh Plex documents for every 7
  /// days. The key must have been registered ([createJwtPin] or
  /// [registerJwtKey]).
  ///
  /// plex.tv answers `422` when the signature does not verify (a key it
  /// does not know) and `429` when nonces are asked for too often.
  Future<PlexJwt> refreshJwt({
    required PlexDeviceKey key,
    List<String> scopes = PlexJwt.allScopes,
  }) async {
    final nonce = await authNonce();
    final deviceJwt = await key.deviceJwt(
      clientIdentifier: _http.credentials.clientIdentifier,
      nonce: nonce,
      scopes: scopes,
    );
    return exchangeDeviceJwt(deviceJwt);
  }

  // -------------------------------------------------------------------------
  // Account info & sign-out
  // -------------------------------------------------------------------------

  /// Fetch the signed-in user's profile (`GET plex.tv/api/v2/user`).
  Future<PlexUser> currentUser() =>
      _plexTv('$_v2/user', (json) => PlexUser.fromJson(_object(json)));

  /// The user the server token belongs to (`GET plex.tv/api/v2/user` with
  /// [PlexClient.token], the token sent to the server, rather than the
  /// account token): after [PlexClient.connectToResource], whose token the
  /// server got.
  Future<PlexUser> tokenDetails() => _plexTv(
    '$_v2/user',
    (json) => PlexUser.fromJson(_object(json)),
    token: _http.token ?? '',
  );

  /// Sign out the account token at plex.tv.
  Future<void> signOut() => _plexTv<void>(
    '$_plexTvLegacy/api/v2/users/signout',
    (_) {},
    method: 'DELETE',
  );

  // -------------------------------------------------------------------------
  // Server discovery
  // -------------------------------------------------------------------------

  /// List the servers the account has access to
  /// (`GET plex.tv/api/v2/resources`).
  ///
  /// Pass `serverOnly = true` (default) to filter out player/client
  /// resources — i.e. keep only resources whose `provides` includes
  /// `'server'`. Use [PlexClient.connectToResource] to reach one.
  ///
  /// A resource's [PlexResource.accessToken] is the token for that server.
  /// For an owned server it can be the account token itself; what plex.tv
  /// hands out when the account token is a JWT is not documented — see
  /// [PlexClient.connectToResource] for the fallback when a server
  /// refuses it.
  Future<List<PlexResource>> fetchResources({
    bool includeHttps = true,
    bool includeRelay = true,
    bool includeIPv6 = true,
    bool serverOnly = true,
  }) async {
    final all = await _plexTv(
      '$_v2/resources',
      (json) => asObjectList(json, PlexResource.fromJson),
      query: {
        'includeHttps': includeHttps ? 1 : 0,
        'includeRelay': includeRelay ? 1 : 0,
        'includeIPv6': includeIPv6 ? 1 : 0,
      },
    );
    if (!serverOnly) return all;
    return all.where((r) => r.isServer).toList(growable: false);
  }

  /// The devices signed in to the account (`GET plex.tv/api/v2/devices`).
  ///
  /// Whether plex.tv lists a [PlexDevice.token] for each, and for which
  /// devices, is not documented; python-plexapi reads them from the older
  /// `plex.tv/devices.xml`. [PlexClient.connectToResource] uses this list
  /// as a fallback when a server refuses the token from [fetchResources].
  Future<List<PlexDevice>> devices() => _plexTv(
    '$_v2/devices',
    (json) => _list(json, 'Device', PlexDevice.fromJson),
  );

  /// The connection of [resource] to use: every one in
  /// [PlexResource.rankedConnections] is tried at once (`GET /identity`,
  /// which needs no token), and the best-ranked one that answers wins —
  /// without waiting for worse ones once it has. A connection counts only
  /// when its server reports the resource's machine identifier, so the
  /// token is never sent to another host that happens to answer.
  ///
  /// Returns `null` when none answers within [timeout]; when some
  /// answered but a better one was still pending, the best of those.
  Future<PlexServerConnection?> findConnection(
    PlexResource resource, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final ranked = resource.rankedConnections();
    if (ranked.isEmpty) return null;
    final cancel = PlexCancelToken();
    final answered = List<bool?>.filled(ranked.length, null);
    final done = Completer<PlexServerConnection?>();

    PlexServerConnection? best({required bool wait}) {
      for (var i = 0; i < ranked.length; i++) {
        final ok = answered[i];
        if (ok == true) return ranked[i];
        if (ok == null && wait) return null;
      }
      return null;
    }

    void settle() {
      if (done.isCompleted) return;
      final pick = best(wait: true);
      if (pick != null) {
        done.complete(pick);
      } else if (!answered.contains(null)) {
        done.complete(null);
      }
    }

    for (var i = 0; i < ranked.length; i++) {
      unawaited(
        _probe(ranked[i], resource.clientIdentifier, cancel).then((ok) {
          answered[i] = ok;
          settle();
        }),
      );
    }
    final timer = Timer(timeout, () {
      if (!done.isCompleted) done.complete(best(wait: false));
    });
    try {
      return await done.future;
    } finally {
      timer.cancel();
      cancel.cancel();
    }
  }

  Future<bool> _probe(
    PlexServerConnection connection,
    String machineIdentifier,
    PlexCancelToken cancel,
  ) async {
    try {
      final id = await _http.requestJson(
        '${connection.uri}/identity',
        _machineIdentifier,
        absoluteUrl: true,
        cancelToken: cancel,
        extraHeaders: const {'X-Plex-Token': ''},
      );
      return machineIdentifier.isEmpty || id == machineIdentifier;
    } on PlexException {
      return false;
    }
  }

  static String? _machineIdentifier(Object? json) {
    final id = mediaContainer(json)['machineIdentifier'];
    return id is String ? id : null;
  }

  /// The token [devices] lists for the server [machineIdentifier], or
  /// `null`.
  Future<String?> serverTokenFromDevices(String machineIdentifier) async {
    final all = await devices();
    for (final d in all) {
      if (d.clientIdentifier == machineIdentifier &&
          (d.token?.isNotEmpty ?? false)) {
        return d.token;
      }
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Plex Home, friends and sharing
  // -------------------------------------------------------------------------

  /// The members of the account's Plex Home (`GET plex.tv/api/home/users`,
  /// as python-plexapi reads it; plex.tv answers it in XML).
  Future<List<PlexHomeUser>> homeUsers() => _plexTv(
    '$_plexTvLegacy/api/home/users',
    (json) => _list(json, 'User', PlexHomeUser.fromJson),
  );

  /// The managed users of the Home: [homeUsers] that are
  /// [PlexHomeUser.restricted].
  Future<List<PlexHomeUser>> managedUsers() async => [
    for (final u in await homeUsers())
      if (u.restricted) u,
  ];

  /// Switch to the Home member [userId]
  /// (`POST plex.tv/api/home/users/{id}/switch`), with their [pin] when
  /// they have one.
  ///
  /// Returns that user, whose [PlexUser.authToken] is their own plex.tv
  /// token — a legacy token, as far as is known: python-plexapi reads it
  /// from the same route. Apply it with [PlexClient.setAccountToken] (and
  /// fetch the servers again: they come with that user's tokens).
  Future<PlexUser> switchHomeUser({required int userId, String? pin}) async {
    final user = await _plexTv(
      '$_plexTvLegacy/api/home/users/$userId/switch',
      (json) => PlexUser.fromJson(_object(json)),
      method: 'POST',
      query: {'pin': ?pin},
    );
    if (user.authToken.isEmpty) {
      throw const PlexException(
        'The switch answered no token for the user',
        type: PlexErrorType.auth,
      );
    }
    return user;
  }

  /// The users the account shares servers with, or shares a Home with,
  /// each with the servers shared (`GET plex.tv/api/users/`, python-plexapi's
  /// `MyPlexAccount.users()`; XML).
  Future<List<PlexAccountUser>> connectedUsers() => _plexTv(
    '$_plexTvLegacy/api/users/',
    (json) => _list(json, 'User', PlexAccountUser.fromJson),
  );

  /// The account's friends (`GET plex.tv/api/v2/friends`).
  ///
  /// plex.tv removed this endpoint: it answers `410 Gone`, as do
  /// `plex.tv/api/friends/all` and `clients.plex.tv/api/v2/friends`
  /// (verified in November 2026), so this throws a [PlexException] with
  /// that status. No REST route lists friends any more; the closest is
  /// [connectedUsers], the users the account shares servers or a Home
  /// with.
  @Deprecated(
    'plex.tv removed this endpoint (410 Gone): use connectedUsers() for '
    'the users servers are shared with. Will be removed in 0.4.0.',
  )
  Future<List<PlexFriend>> friends() => _plexTv(
    '$_v2/friends',
    (json) => switch (json) {
      final List<Object?> list => asObjectList(list, PlexFriend.fromJson),
      _ => _list(json, 'users', PlexFriend.fromJson),
    },
  );

  // -------------------------------------------------------------------------
  // Watchlist (discover provider)
  // -------------------------------------------------------------------------

  /// The user's watchlist, from Plex's online metadata
  /// (`GET discover.provider.plex.tv/library/sections/watchlist/{filter}`).
  ///
  /// The items are plex.tv metadata, not a server's: their
  /// [PlexMetadata.guid] (`plex://movie/…`) finds the same item on a
  /// server (`PlexFilter.text('guid', guid)`), and [discoverKeyOf] gives
  /// the key [addToWatchlist] takes. [sort] takes
  /// [PlexSort.watchlistedAt], [PlexSort.titleSort],
  /// [PlexSort.originallyAvailableAt] or [PlexSort.rating]; [type] narrows
  /// to [PlexMetadataType.movie] or [PlexMetadataType.show].
  Future<PlexMediaContainer<PlexMetadata>> watchlist({
    PlexWatchlistFilter filter = PlexWatchlistFilter.all,
    PlexSort? sort,
    PlexMetadataType? type,
    int start = 0,
    int size = 50,
  }) => _plexTv(
    '$_discover/library/sections/watchlist/${filter.name}',
    (json) => PlexMediaContainer.fromJson(
      _object(json),
      'Metadata',
      PlexMetadata.fromJson,
    ),
    query: {
      'includeCollections': 1,
      'includeExternalMedia': 1,
      'sort': ?sort,
      'type': ?type?.value,
      ...containerPage(start: start, size: size),
    },
  );

  /// Add the item with discover key [ratingKey] to the watchlist
  /// (`PUT discover.provider.plex.tv/actions/addToWatchlist`, as
  /// python-plexapi sends it). See [discoverKeyOf].
  Future<void> addToWatchlist({required String ratingKey}) => _plexTv<void>(
    '$_discover/actions/addToWatchlist',
    (_) {},
    method: 'PUT',
    query: {'ratingKey': ratingKey},
  );

  /// Remove it (`PUT …/actions/removeFromWatchlist`).
  Future<void> removeFromWatchlist({required String ratingKey}) =>
      _plexTv<void>(
        '$_discover/actions/removeFromWatchlist',
        (_) {},
        method: 'PUT',
        query: {'ratingKey': ratingKey},
      );

  /// The discover key of an item from its `plex://` [guid]: the last path
  /// segment (`plex://movie/5d776…` → `5d776…`).
  static String discoverKeyOf(String guid) => guid.split('/').last;

  // -------------------------------------------------------------------------
  // GeoIP
  // -------------------------------------------------------------------------

  /// Where [ipAddress] is (`GET plex.tv/api/v2/geoip`), or where this
  /// device's public address is when it is omitted.
  Future<PlexGeoLocation> geoip({String? ipAddress}) => _plexTv(
    '$_v2/geoip',
    (json) => PlexGeoLocation.fromJson(_object(json)),
    query: {'ip_address': ?ipAddress},
  );

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  /// A plex.tv request with the account token, JSON or XML, refreshing a
  /// JWT session's token ahead of time and once more after a `401` or
  /// `498`. An explicit [token] is sent as it is (`''` sends none).
  ///
  /// The connection's own token is renewed by the connection
  /// ([PlexClient.tokenRenewer]); this retries only an account token sent
  /// as a header, which the connection leaves alone.
  Future<T> _plexTv<T>(
    String url,
    T Function(Object? json) parse, {
    String method = 'GET',
    Map<String, Object?>? query,
    String? token,
  }) async {
    Future<T> send(String? auth) async {
      final res = await _http.request<Object>(
        url,
        method: method,
        absoluteUrl: true,
        queryParameters: query == null || query.isEmpty ? null : query,
        // The connection's own token goes as it is, so that its renewer
        // can replace it on a retry; another one goes as a header.
        extraHeaders: {'X-Plex-Token': ?(auth == _http.token ? null : auth)},
        responseType: PlexResponseType.plain,
      );
      final text = res.data as String?;
      try {
        if (text == null || text.trim().isEmpty) return parse(null);
        return parse(
          looksLikeXml(text) ? plexXmlToJson(text) : jsonDecode(text),
        );
      } on PlexException {
        rethrow;
        // A parser's TypeError or a FormatException: a body of the wrong
        // shape, reported as one.
        // ignore: avoid_catching_errors
      } catch (e, st) {
        throw PlexException(
          'Could not read the answer of $url: $e',
          type: PlexErrorType.parse,
          path: url,
          cause: e,
          stackTrace: st,
        );
      }
    }

    if (token != null) return send(token);
    final auth = await _accountToken();
    final session = _state.jwt;
    if (session == null ||
        auth == _http.token ||
        auth != session.token?.token) {
      return send(auth);
    }
    try {
      return await send(auth);
    } on PlexException catch (e) {
      if (e.statusCode != 401 && e.statusCode != 498) rethrow;
      // Renewed meanwhile (by the connection's renewer, or a concurrent
      // call): retry with that; otherwise refresh now.
      final current = session.token;
      final fresh = current != null && current.token != auth
          ? current
          : await session.refresh(this);
      _replaceToken(auth, fresh.token);
      return send(fresh.token);
    }
  }

  /// The account token, refreshed first when a JWT session says so.
  Future<String?> _accountToken() async {
    final session = _state.jwt;
    final current = _state.accountToken ?? _http.token;
    if (session != null &&
        session.needsRefresh &&
        current == session.token?.token) {
      final fresh = await session.freshToken(this);
      _replaceToken(current, fresh.token);
      return fresh.token;
    }
    return current;
  }

  void _replaceToken(String? old, String fresh) {
    if (_state.accountToken == old) _state.accountToken = fresh;
    if (_http.token == old) _http.token = fresh;
  }

  static Map<String, Object?> _object(Object? json) {
    if (json is Map<String, Object?>) return json;
    throw PlexException(
      'Expected a JSON object, got ${json.runtimeType}',
      type: PlexErrorType.parse,
    );
  }

  /// The [key] entries of a `MediaContainer` (JSON or XML), of a bare
  /// object holding them, or of a bare list.
  static List<T> _list<T>(
    Object? json,
    String key,
    T Function(Map<String, Object?>) parser,
  ) => json is List
      ? asObjectList(json, parser)
      : asObjectList(mediaContainer(json)[key], parser);
}
