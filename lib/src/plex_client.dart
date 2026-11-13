// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api/plex_account_api.dart';
import 'api/plex_activities_api.dart';
import 'api/plex_butler_api.dart';
import 'api/plex_collections_api.dart';
import 'api/plex_devices_api.dart';
import 'api/plex_download_queue_api.dart';
import 'api/plex_dvrs_api.dart';
import 'api/plex_epg_api.dart';
import 'api/plex_hubs_api.dart';
import 'api/plex_images_api.dart';
import 'api/plex_library_api.dart';
import 'api/plex_live_tv_api.dart';
import 'api/plex_log_api.dart';
import 'api/plex_notifications_api.dart';
import 'api/plex_play_queues_api.dart';
import 'api/plex_playback_api.dart';
import 'api/plex_playlists_api.dart';
import 'api/plex_preferences_api.dart';
import 'api/plex_providers_api.dart';
import 'api/plex_search_api.dart';
import 'api/plex_server_api.dart';
import 'api/plex_sessions_api.dart';
import 'api/plex_streaming_api.dart';
import 'api/plex_subscriptions_api.dart';
import 'api/plex_transcoder_api.dart';
import 'api/plex_ultra_blur_api.dart';
import 'api/plex_updater_api.dart';
import 'plex_connection.dart';
import 'plex_credentials.dart';
import 'plex_error_type.dart';
import 'plex_exception.dart';
import 'plex_jwt.dart';
import 'plex_models.dart';
import 'plex_session_state.dart';
import 'transport/plex_cancel_token.dart';
import 'transport/plex_response.dart';
import 'transport/plex_retry_policy.dart';

/// Stateful façade over the Plex API.
///
/// One [PlexClient] = one identity (set of `X-Plex-*` headers). After
/// signing in to plex.tv and choosing a server, connect to it and the
/// same client serves every endpoint:
///
/// ```dart
/// final plex = PlexClient(credentials: myCredentials);
///
/// await plex.useJwt(session); // a PlexJwtSession, see account.createJwtPin
///
/// final servers = await plex.account.fetchResources();
/// final server = servers.firstWhere((s) => s.owned);
/// await plex.connectToResource(server);
///
/// final sections = await plex.library.sections();
/// ```
///
/// Two tokens are in play: the account token ([accountToken]) for
/// plex.tv, and the server's ([token]), which [connectToResource] takes
/// from the resource. Neither is assumed to last: a JWT expires after 7
/// days, and [useJwt] has the client refresh it, ahead of time and after
/// a server or plex.tv refuses it.
///
/// The client and its sub-API classes are deliberately not `final`, so an
/// app's tests can stand in for them (`class FakeClient implements
/// PlexClient`, or a mocking library). The models are `final`: they are
/// data, built by the library.
///
/// {@category Client and sign-in}
/// {@category Raw requests}
class PlexClient {
  final PlexConnection _http;
  final PlexSessionState _state;

  /// `https://plex.tv/api/v2` operations — server identity, user info, friends.
  late final PlexAccountApi account = PlexAccountApi(_http, state: _state);

  /// Top-level PMS endpoints — `/`, `/identity`, `/capabilities`.
  late final PlexServerApi server = PlexServerApi(_http);

  /// `/library/sections` and `/library/metadata/{id}` browsing.
  late final PlexLibraryApi library = PlexLibraryApi(_http);

  /// `/playlists` and `/playlists/{id}/items` — create, list, mutate playlists.
  late final PlexPlaylistsApi playlists = PlexPlaylistsApi(_http);

  /// `/hubs/search` and legacy `/search` — global and per-section search.
  late final PlexSearchApi search = PlexSearchApi(_http);

  /// `/:/timeline`, `/:/scrobble`, `/:/rate` — playback reporting and ratings.
  late final PlexPlaybackApi playback = PlexPlaybackApi(_http);

  /// Build signed `/music/:/transcode/universal/*` streaming URLs.
  late final PlexStreamingApi streaming = PlexStreamingApi(_http);

  /// `/photo/:/transcode` — resized artwork URLs.
  late final PlexImagesApi images = PlexImagesApi(_http);

  /// `/status/sessions` — currently active playback sessions.
  late final PlexSessionsApi sessions = PlexSessionsApi(_http);

  /// `/hubs` — home-screen rails (Recently Added, Continue Listening, …).
  late final PlexHubsApi hubs = PlexHubsApi(_http);

  /// `/playQueues` — server-side queues for cast / multi-device playback.
  late final PlexPlayQueuesApi playQueues = PlexPlayQueuesApi(_http);

  /// `/livetv/sessions` and related Live TV consumer endpoints.
  late final PlexLiveTvApi liveTv = PlexLiveTvApi(_http);

  /// `/services/ultrablur/colors` — corner-colour artwork gradients.
  late final PlexUltraBlurApi ultraBlur = PlexUltraBlurApi(_http);

  /// `/library/collections` — create / add / remove / reorder collections.
  late final PlexCollectionsApi collections = PlexCollectionsApi(_http);

  /// `/media/grabbers` and related tuner / grabber device endpoints.
  late final PlexDevicesApi devices = PlexDevicesApi(_http);

  /// `/livetv/dvrs` — DVR configuration (admin).
  late final PlexDvrsApi dvrs = PlexDvrsApi(_http);

  /// `/media/subscriptions` — DVR recording rules.
  late final PlexSubscriptionsApi subscriptions = PlexSubscriptionsApi(_http);

  /// `/downloadQueue` — legacy mobile sync surface.
  late final PlexDownloadQueueApi downloadQueue = PlexDownloadQueueApi(_http);

  /// `/livetv/epg/*` — electronic program guide.
  late final PlexEpgApi epg = PlexEpgApi(_http);

  /// `/butler` — scheduled maintenance tasks (thumbnails, intro detection, …).
  late final PlexButlerApi butler = PlexButlerApi(_http);

  /// `/:/transcode/*` — subtitle/image transcode endpoints not covered by [streaming].
  late final PlexTranscoderApi transcoder = PlexTranscoderApi(_http);

  /// `/media/providers` — registered media providers.
  late final PlexProvidersApi providers = PlexProvidersApi(_http);

  /// `/:/prefs` — server preferences (settings).
  late final PlexPreferencesApi preferences = PlexPreferencesApi(_http);

  /// `/log` — write entries into the server log stream.
  late final PlexLogApi log = PlexLogApi(_http);

  /// `/updater/*` — server software update lifecycle (admin).
  late final PlexUpdaterApi updater = PlexUpdaterApi(_http);

  /// `/activities` — list and cancel running background activities.
  late final PlexActivitiesApi activities = PlexActivitiesApi(_http);

  /// `/:/websockets/notifications` and `/:/eventsource/notifications` — server-push events.
  late final PlexNotificationsApi notifications;

  /// Build a client carrying [credentials].
  ///
  /// Pass an [httpClient] to choose the HTTP stack — for example a
  /// `CupertinoClient` (`package:cupertino_http`) or a `CronetClient`
  /// (`package:cronet_http`) for HTTP/2 and the system proxy, or a
  /// `MockClient` in tests. An injected client is yours to close; the one
  /// created when you pass none is closed by [close].
  ///
  /// [connectTimeout] bounds the handshake (on the default client) and,
  /// together with [receiveTimeout], the wait for the response headers.
  /// [receiveTimeout] also bounds every pause in a response body.
  ///
  /// Responses of [jsonIsolateThreshold] bytes or more are decoded, and
  /// for the typed calls parsed into models, on a background isolate.
  ///
  /// [retryPolicy] resends idempotent requests after transient failures;
  /// it is off ([PlexRetryPolicy.none]) unless you pass one.
  ///
  /// [tokenRenewer] is called when a request is refused with `401` or
  /// `498`; see the setter of the same name.
  PlexClient({
    required PlexCredentials credentials,
    http.Client? httpClient,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 30),
    int jsonIsolateThreshold = PlexConnection.defaultJsonIsolateThreshold,
    PlexRetryPolicy retryPolicy = PlexRetryPolicy.none,
    PlexTokenRenewer? tokenRenewer,
  }) : _http = PlexConnection(
         credentials: credentials,
         httpClient: httpClient,
         connectTimeout: connectTimeout,
         receiveTimeout: receiveTimeout,
         jsonIsolateThreshold: jsonIsolateThreshold,
         retryPolicy: retryPolicy,
       ),
       _state = PlexSessionState() {
    _http.renewal.renewer = tokenRenewer;
    notifications = PlexNotificationsApi(_http);
  }

  PlexClient._scoped(PlexClient parent, PlexCancelToken token)
    : _http = PlexConnection.scoped(parent._http, token),
      _state = parent._state {
    notifications = parent.notifications;
  }

  /// A view of this client whose every request is cancelled by
  /// [cancelToken].
  ///
  /// The view shares this client's HTTP connection pool, server and token
  /// — `connect`, `setToken` and `close` on either affect both — and costs
  /// nothing to create, so make one per page, filter or search term and
  /// cancel it when that is abandoned:
  ///
  /// ```dart
  /// _pageToken?.cancel();
  /// final token = _pageToken = PlexCancelToken();
  /// final page = await plex.withCancelToken(token).library.allByType(
  ///       sectionId: sectionId,
  ///       type: PlexMetadataType.album,
  ///     );
  /// ```
  ///
  /// A cancelled call throws a [PlexException] of type
  /// [PlexErrorType.cancelled]. [notifications] is the same object as on
  /// this client: a WebSocket or event stream is not a request and is not
  /// cancelled.
  PlexClient withCancelToken(PlexCancelToken cancelToken) =>
      PlexClient._scoped(this, cancelToken);

  /// The credentials this client was created with.
  PlexCredentials get credentials => _http.credentials;

  /// Active PMS base URL, or null if [connect] has not been called.
  String? get baseUrl => _http.baseUrl;

  /// The `X-Plex-Token` sent to the server, or null if not authenticated.
  /// Also sent to plex.tv while there is no separate [accountToken].
  String? get token => _http.token;

  /// The token for plex.tv calls ([account]). `null` until it differs
  /// from [token]: [connect] with an `accessToken` keeps the token it
  /// replaces here, and [useJwt] puts the JWT here.
  String? get accountToken => _state.accountToken ?? _http.token;

  /// `true` after both [setToken] and [connect] have been called.
  bool get isAuthenticated => _http.isAuthenticated;

  /// Update the token sent to the server. The next request will carry it.
  void setToken(String? value) {
    _http.token = value;
  }

  /// Set the token for plex.tv calls apart from [token] — after
  /// [PlexAccountApi.switchHomeUser], say. `null` goes back to sending
  /// [token].
  void setAccountToken(String? value) {
    _state.accountToken = value;
  }

  /// Called with the refused token when a request is answered `401`, or
  /// `498` (an expired plex.tv JWT); the request is retried once with the
  /// token it returns, or fails when it returns `null` or throws.
  /// Concurrent refusals share one call.
  ///
  /// A request that sets `X-Plex-Token` in its `extraHeaders` (another
  /// token, or `''` for none) is not renewed, and neither are the
  /// requests the renewer makes.
  ///
  /// [useJwt] installs one that refreshes the session's JWT. Set your own
  /// to renew tokens some other way — for example to ask the user to sign
  /// in again.
  PlexTokenRenewer? get tokenRenewer => _http.renewal.renewer;

  /// Sets or clears [tokenRenewer].
  set tokenRenewer(PlexTokenRenewer? value) => _http.renewal.renewer = value;

  /// Sign in with a plex.tv JWT [session] and keep it fresh.
  ///
  /// The session's token is refreshed now when it is missing or expires
  /// within [PlexJwtSession.refreshBefore], becomes [accountToken] (and
  /// [token] when there is none yet), and from then on is refreshed when
  /// it nears expiry before a plex.tv call, and when plex.tv or a server
  /// refuses it with `401` / `498` ([tokenRenewer]). Each new token goes
  /// to [PlexJwtSession.onChanged], for the app to persist.
  ///
  /// A server token from [PlexAccountApi.fetchResources] that is not the
  /// session's JWT is not renewed this way: see [connectToResource].
  ///
  /// When the first refresh fails, the client is left as it was.
  Future<void> useJwt(PlexJwtSession session) async {
    final jwt = await session.freshToken(account);
    _state.jwt = session;
    _state.accountToken = jwt.token;
    _http.token ??= jwt.token;
    _http.renewal.renewer = _renewJwt;
  }

  Future<String?> _renewJwt(String? rejected) async {
    final session = _state.jwt;
    if (session == null || rejected != session.token?.token) return null;
    final fresh = await session.refresh(account);
    if (_state.accountToken == rejected) _state.accountToken = fresh.token;
    return fresh.token;
  }

  /// The connection picked by [connectTo] or [connectToResource]; `null`
  /// after a plain [connect] to a URL.
  PlexServerConnection? get connection => _state.connection;

  /// Whether the server is reached locally, remotely or through Plex
  /// Relay; `null` when unknown (a plain [connect] to a URL). Remote and
  /// relay playback of video can need a Plex Pass or Remote Watch Pass
  /// ([PlexErrorType.passRequired]).
  PlexConnectionKind? get connectionKind => _state.connection?.kind;

  /// Point the client at a specific PMS.
  ///
  /// Prefer [connectToResource], which picks a connection that answers.
  /// The optional [accessToken] replaces [token] — the server's own token
  /// for a shared server; the token it replaces stays the
  /// [accountToken] for plex.tv calls, when none was set apart.
  ///
  /// [baseUrl] may hold an IPv6 literal in brackets
  /// (`http://[2001:db8::2]:32400`).
  void connect(String baseUrl, {String? accessToken}) {
    _connect(baseUrl, accessToken, null);
  }

  /// [connect] to [connection] (from [PlexResource.connections]),
  /// remembering how it reaches the server ([connectionKind]).
  void connectTo(PlexServerConnection connection, {String? accessToken}) {
    _connect(connection.uri, accessToken, connection);
  }

  void _connect(
    String baseUrl,
    String? accessToken,
    PlexServerConnection? connection,
  ) {
    _http.baseUrl = PlexServerConnection.bracketIpv6(baseUrl);
    _state.connection = connection;
    if (accessToken == null) return;
    final previous = _http.token;
    if (_state.accountToken == null &&
        previous != null &&
        previous != accessToken) {
      _state.accountToken = previous;
    }
    _http.token = accessToken;
  }

  /// Connect to [resource] (from [PlexAccountApi.fetchResources]) through
  /// the best of its connections that answers within [timeout]
  /// ([PlexAccountApi.findConnection]), with its access token, and return
  /// the connection picked.
  ///
  /// With [verifyToken] (the default) the token is then tried on the
  /// server (`GET /`, which needs one). When the server refuses it with
  /// `401`, the token [PlexAccountApi.devices] lists for the server, if
  /// any, is tried instead.
  ///
  /// For an owned server the resource's token can be the account's JWT;
  /// [useJwt] then renews it on the server too.
  ///
  /// Throws a [PlexException] of type [PlexErrorType.connection] when no
  /// connection answers, and the server's error when no token works. On
  /// a failure the client keeps its previous server, connection and
  /// tokens.
  Future<PlexServerConnection> connectToResource(
    PlexResource resource, {
    Duration timeout = const Duration(seconds: 10),
    bool verifyToken = true,
  }) async {
    final picked = await account.findConnection(resource, timeout: timeout);
    if (picked == null) {
      throw PlexException(
        'No connection of "${resource.name}" answered within $timeout',
        type: PlexErrorType.connection,
      );
    }
    final baseUrl = _http.baseUrl;
    final token = _http.token;
    final accountToken = _state.accountToken;
    final connection = _state.connection;
    connectTo(
      picked,
      accessToken: resource.accessToken.isEmpty ? null : resource.accessToken,
    );
    if (!verifyToken) return picked;
    try {
      try {
        await _http.request<Object>('/');
      } on PlexException catch (e) {
        if (e.statusCode != 401) rethrow;
        final fallback = await account.serverTokenFromDevices(
          resource.clientIdentifier,
        );
        if (fallback == null || fallback == _http.token) rethrow;
        _http.token = fallback;
        await _http.request<Object>('/');
      }
    } catch (_) {
      _http.baseUrl = baseUrl;
      _http.token = token;
      _state.accountToken = accountToken;
      _state.connection = connection;
      rethrow;
    }
    return picked;
  }

  /// Clear the server token, the account token and any JWT session while
  /// keeping the base URL, so the client stays pointed at the same PMS but
  /// unauthenticated.
  ///
  /// Mirrors `JellyfinClient.clearSession()`.
  void clearSession() {
    _http.token = null;
    _state.accountToken = null;
    if (_state.jwt != null) _http.renewal.renewer = null;
    _state.jwt = null;
  }

  /// Drop the tokens and the base URL.
  void disconnect() {
    clearSession();
    _http.baseUrl = null;
    _state.connection = null;
  }

  /// Closes the HTTP client this client created. Requests made afterwards
  /// — through this client or any [withCancelToken] view — fail with
  /// [PlexErrorType.state]. Does nothing to an injected `httpClient`.
  ///
  /// Also closes the notification WebSocket and event source, if open or
  /// still connecting: their streams end. The closes are not awaited; use
  /// `notifications.closeWebSocket()` / `closeEventSource()` to wait.
  void close() {
    unawaited(notifications.closeWebSocket());
    unawaited(notifications.closeEventSource());
    _http.close();
  }

  /// Escape hatch: issue an arbitrary request through the same HTTP client
  /// and headers as the sub-APIs.
  ///
  /// Use this for endpoints not yet covered by the typed sub-APIs (e.g.
  /// `/music/:/transcode/universal/decision`, custom HLS variants, …).
  /// Throws [PlexException] on failure (same as every other call).
  ///
  /// Prefer the typed sub-APIs when one fits — they handle envelope
  /// unwrapping and DTO parsing for you.
  Future<PlexResponse<T>> request<T>(
    String path, {
    String method = 'GET',
    Map<String, Object?>? queryParameters,
    Object? data,
    Map<String, String>? extraHeaders,
    bool absoluteUrl = false,
    PlexResponseType? responseType,
    PlexCancelToken? cancelToken,
  }) => _http.request<T>(
    path,
    method: method,
    queryParameters: queryParameters,
    data: data,
    extraHeaders: extraHeaders,
    absoluteUrl: absoluteUrl,
    responseType: responseType,
    cancelToken: cancelToken,
  );

  /// Convenience for byte GETs (artwork, small files). The whole body is
  /// held in memory; use [requestStream] for media downloads.
  Future<PlexResponse<Uint8List>> requestBytes(
    String url, {
    Map<String, Object?>? queryParameters,
    bool absoluteUrl = true,
    PlexCancelToken? cancelToken,
  }) => _http.requestBytes(
    url,
    queryParameters: queryParameters,
    absoluteUrl: absoluteUrl,
    cancelToken: cancelToken,
  );

  /// Streams a GET body as it arrives — for downloads, so a whole track
  /// never sits in memory. Write [PlexStreamedResponse.stream] to a file
  /// sink; cancelling the subscription closes the connection.
  ///
  /// A pause in the body longer than the receive timeout fails the stream
  /// unless [stallTimeout] is `false`.
  Future<PlexStreamedResponse> requestStream(
    String url, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? extraHeaders,
    bool absoluteUrl = true,
    bool stallTimeout = true,
    PlexCancelToken? cancelToken,
  }) => _http.requestStream(
    url,
    queryParameters: queryParameters,
    extraHeaders: extraHeaders,
    absoluteUrl: absoluteUrl,
    stallTimeout: stallTimeout,
    cancelToken: cancelToken,
  );

  // ─── Lightweight method aliases ────────────────────────────────────
  //
  // Prefer the typed sub-APIs (account, library, …) when possible — these
  // are the escape hatch for endpoints not yet covered.

  /// Issue a `GET` via [request].
  Future<PlexResponse<T>> get<T>(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? extraHeaders,
    PlexCancelToken? cancelToken,
  }) => request<T>(
    path,
    queryParameters: queryParameters,
    extraHeaders: extraHeaders,
    cancelToken: cancelToken,
  );

  /// Issue a `POST` via [request].
  Future<PlexResponse<T>> post<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    Map<String, String>? extraHeaders,
    PlexCancelToken? cancelToken,
  }) => request<T>(
    path,
    method: 'POST',
    data: data,
    queryParameters: queryParameters,
    extraHeaders: extraHeaders,
    cancelToken: cancelToken,
  );

  /// Issue a `PUT` via [request].
  Future<PlexResponse<T>> put<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    Map<String, String>? extraHeaders,
    PlexCancelToken? cancelToken,
  }) => request<T>(
    path,
    method: 'PUT',
    data: data,
    queryParameters: queryParameters,
    extraHeaders: extraHeaders,
    cancelToken: cancelToken,
  );

  /// Issue a `DELETE` via [request].
  Future<PlexResponse<T>> delete<T>(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? extraHeaders,
    PlexCancelToken? cancelToken,
  }) => request<T>(
    path,
    method: 'DELETE',
    queryParameters: queryParameters,
    extraHeaders: extraHeaders,
    cancelToken: cancelToken,
  );
}

/// Renews a refused token; see [PlexClient.tokenRenewer].
///
/// {@category Client and sign-in}
typedef PlexTokenRenewer = Future<String?> Function(String? rejected);
