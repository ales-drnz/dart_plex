// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of 'plex_account_api.dart';

/// Signing in to plex.tv: password, PIN and device JWT. Mixed into [PlexAccountApi].
mixin _PlexAccountSignIn {
  PlexConnection get _http;
  PlexSessionState get _state;

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
}
