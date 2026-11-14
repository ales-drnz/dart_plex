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

part 'plex_account_discovery.dart';
part 'plex_account_home.dart';
part 'plex_account_sign_in.dart';

/// Talks to plex.tv for everything that lives outside a specific Plex
/// Media Server: sign-in (PIN, JWT, password), server discovery, the
/// user's profile, Plex Home, friends, the watchlist.
///
/// plex.tv calls carry the account token ([PlexClient.accountToken]),
/// which after [PlexClient.useJwt] is a JWT this API refreshes when it is
/// about to expire or plex.tv answers `401` / `498` to it.
///
/// {@category Client and sign-in}
class PlexAccountApi
    with _PlexAccountSignIn, _PlexAccountDiscovery, _PlexAccountHome {
  @override
  final PlexConnection _http;
  @override
  final PlexSessionState _state;

  /// Construct from a [PlexConnection]. Typically obtained via
  /// [PlexClient.account].
  PlexAccountApi(this._http, {@internal PlexSessionState? state})
    : _state = state ?? PlexSessionState();

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

  /// The discover key of an item from its `plex://` [guid]: the last path
  /// segment (`plex://movie/5d776…` → `5d776…`).
  static String discoverKeyOf(String guid) => guid.split('/').last;

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
  @override
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
        queryParameters: query,
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
}

const String _v2 = 'https://plex.tv/api/v2';
const String _plexTvLegacy = 'https://plex.tv';
const String _clients = 'https://clients.plex.tv/api/v2';
const String _discover = 'https://discover.provider.plex.tv';

Map<String, Object?> _object(Object? json) {
  if (json is Map<String, Object?>) return json;
  throw PlexException(
    'Expected a JSON object, got ${json.runtimeType}',
    type: PlexErrorType.parse,
  );
}

/// The [key] entries of a `MediaContainer` (JSON or XML), of a bare
/// object holding them, or of a bare list.
List<T> _list<T>(
  Object? json,
  String key,
  T Function(Map<String, Object?>) parser,
) => json is List
    ? asObjectList(json, parser)
    : asObjectList(mediaContainer(json)[key], parser);
