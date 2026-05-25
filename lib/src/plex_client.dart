// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:dio/dio.dart';

import 'api/plex_account_api.dart';
import 'api/plex_collections_api.dart';
import 'api/plex_devices_api.dart';
import 'api/plex_download_queue_api.dart';
import 'api/plex_dvrs_api.dart';
import 'api/plex_epg_api.dart';
import 'api/plex_activities_api.dart';
import 'api/plex_butler_api.dart';
import 'api/plex_log_api.dart';
import 'api/plex_notifications_api.dart';
import 'api/plex_preferences_api.dart';
import 'api/plex_providers_api.dart';
import 'api/plex_subscriptions_api.dart';
import 'api/plex_transcoder_api.dart';
import 'api/plex_updater_api.dart';
import 'api/plex_hubs_api.dart';
import 'api/plex_images_api.dart';
import 'api/plex_library_api.dart';
import 'api/plex_live_tv_api.dart';
import 'api/plex_play_queues_api.dart';
import 'api/plex_playback_api.dart';
import 'api/plex_playlists_api.dart';
import 'api/plex_search_api.dart';
import 'api/plex_server_api.dart';
import 'api/plex_sessions_api.dart';
import 'api/plex_streaming_api.dart';
import 'api/plex_ultra_blur_api.dart';
import 'plex_connection.dart';
import 'plex_credentials.dart';

/// Stateful façade over the Plex API.
///
/// One [PlexClient] = one identity (set of `X-Plex-*` headers). After
/// authenticating against plex.tv and choosing a server, call [connect]
/// and the same client serves every endpoint:
///
/// ```dart
/// final plex = PlexClient(credentials: myCredentials);
///
/// final user = await plex.account.signInWithPassword(
///   username: 'me', password: 'pw',
/// );
/// plex.setToken(user.authToken);
///
/// final servers = await plex.account.fetchResources();
/// final server = servers.firstWhere((s) => s.owned);
/// final conn = server.bestConnection()!;
/// plex.connect(conn.uri, accessToken: server.accessToken);
///
/// final sections = await plex.library.sections();
/// ```
class PlexClient {
  final PlexConnection _http;

  /// `https://plex.tv/api/v2` operations — server identity, user info, friends.
  late final PlexAccountApi account;

  /// Top-level PMS endpoints — `/`, `/identity`, `/capabilities`.
  late final PlexServerApi server;

  /// `/library/sections` and `/library/metadata/{id}` browsing.
  late final PlexLibraryApi library;

  /// `/playlists` and `/playlists/{id}/items` — create, list, mutate playlists.
  late final PlexPlaylistsApi playlists;

  /// `/hubs/search` and legacy `/search` — global and per-section search.
  late final PlexSearchApi search;

  /// `/:/timeline`, `/:/scrobble`, `/:/rate` — playback reporting and ratings.
  late final PlexPlaybackApi playback;

  /// Build signed `/music/:/transcode/universal/*` streaming URLs.
  late final PlexStreamingApi streaming;

  /// `/photo/:/transcode` — resized artwork URLs.
  late final PlexImagesApi images;

  /// `/status/sessions` — currently active playback sessions.
  late final PlexSessionsApi sessions;

  /// `/hubs` — home-screen rails (Recently Added, Continue Listening, …).
  late final PlexHubsApi hubs;

  /// `/playQueues` — server-side queues for cast / multi-device playback.
  late final PlexPlayQueuesApi playQueues;

  /// `/livetv/sessions` and related Live TV consumer endpoints.
  late final PlexLiveTvApi liveTv;

  /// `/services/ultrablur/colors` — corner-colour artwork gradients.
  late final PlexUltraBlurApi ultraBlur;

  /// `/library/collections` — create / add / remove / reorder collections.
  late final PlexCollectionsApi collections;

  /// `/media/grabbers` and related tuner / grabber device endpoints.
  late final PlexDevicesApi devices;

  /// `/livetv/dvrs` — DVR configuration (admin).
  late final PlexDVRsApi dvrs;

  /// `/media/subscriptions` — DVR recording rules.
  late final PlexSubscriptionsApi subscriptions;

  /// `/downloadQueue` — legacy mobile sync surface.
  late final PlexDownloadQueueApi downloadQueue;

  /// `/livetv/epg/*` — electronic program guide.
  late final PlexEpgApi epg;

  /// `/butler` — scheduled maintenance tasks (thumbnails, intro detection, …).
  late final PlexButlerApi butler;

  /// `/:/transcode/*` — subtitle/image transcode endpoints not covered by [streaming].
  late final PlexTranscoderApi transcoder;

  /// `/media/providers` — registered media providers.
  late final PlexProvidersApi providers;

  /// `/:/prefs` — server preferences (settings).
  late final PlexPreferencesApi preferences;

  /// `/log` — write entries into the server log stream.
  late final PlexLogApi log;

  /// `/updater/*` — server software update lifecycle (admin).
  late final PlexUpdaterApi updater;

  /// `/activities` — list and cancel running background activities.
  late final PlexActivitiesApi activities;

  /// `/:/websockets/notifications` and `/:/eventsource/notifications` — server-push events.
  late final PlexNotificationsApi notifications;

  /// Build a client carrying [credentials]; optionally inject a custom [dio]
  /// and override the default timeouts.
  PlexClient({
    required PlexCredentials credentials,
    Dio? dio,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) : _http = PlexConnection(
          credentials: credentials,
          dio: dio,
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
        ) {
    account = PlexAccountApi(_http);
    server = PlexServerApi(_http);
    library = PlexLibraryApi(_http);
    playlists = PlexPlaylistsApi(_http);
    search = PlexSearchApi(_http);
    playback = PlexPlaybackApi(_http);
    streaming = PlexStreamingApi(_http);
    images = PlexImagesApi(_http);
    sessions = PlexSessionsApi(_http);
    hubs = PlexHubsApi(_http);
    playQueues = PlexPlayQueuesApi(_http);
    liveTv = PlexLiveTvApi(_http);
    ultraBlur = PlexUltraBlurApi(_http);
    collections = PlexCollectionsApi(_http);
    devices = PlexDevicesApi(_http);
    dvrs = PlexDVRsApi(_http);
    subscriptions = PlexSubscriptionsApi(_http);
    downloadQueue = PlexDownloadQueueApi(_http);
    epg = PlexEpgApi(_http);
    butler = PlexButlerApi(_http);
    transcoder = PlexTranscoderApi(_http);
    providers = PlexProvidersApi(_http);
    preferences = PlexPreferencesApi(_http);
    log = PlexLogApi(_http);
    updater = PlexUpdaterApi(_http);
    activities = PlexActivitiesApi(_http);
    notifications = PlexNotificationsApi(_http);
  }

  /// The credentials this client was created with.
  PlexCredentials get credentials => _http.credentials;

  /// Active PMS base URL, or null if [connect] has not been called.
  String? get baseUrl => _http.baseUrl;

  /// Active `X-Plex-Token`, or null if not authenticated.
  String? get token => _http.token;

  /// `true` after both [setToken] and [connect] have been called.
  bool get isAuthenticated => _http.isAuthenticated;

  /// Update the active token. The next request will carry it.
  void setToken(String? value) {
    _http.token = value;
  }

  /// Point the client at a specific PMS.
  ///
  /// [baseUrl] should be one of the URIs returned by
  /// `PlexAccountApi.fetchResources` (use
  /// `resource.bestConnection().uri`). The optional [accessToken]
  /// overrides the current token — useful when switching to a
  /// shared server which has its own per-server token.
  void connect(String baseUrl, {String? accessToken}) {
    _http.baseUrl = baseUrl;
    if (accessToken != null) _http.token = accessToken;
  }

  /// Drop the active token and base URL.
  void disconnect() {
    _http.baseUrl = null;
    _http.token = null;
  }

  /// Escape hatch: issue an arbitrary request through the same Dio
  /// instance + headers as the sub-APIs.
  ///
  /// Use this for endpoints not yet covered by the typed sub-APIs (e.g.
  /// `/music/:/transcode/universal/decision`, custom HLS variants, …).
  /// Throws [PlexException] on failure (same as every other call).
  ///
  /// Prefer the typed sub-APIs when one fits — they handle envelope
  /// unwrapping and DTO parsing for you.
  Future<Response<T>> request<T>(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? queryParameters,
    Object? data,
    Map<String, String>? extraHeaders,
    bool absoluteUrl = false,
    ResponseType? responseType,
  }) =>
      _http.request<T>(
        path,
        method: method,
        queryParameters: queryParameters,
        data: data,
        extraHeaders: extraHeaders,
        absoluteUrl: absoluteUrl,
        responseType: responseType,
      );

  /// Convenience for byte-stream GETs (artwork, downloads).
  Future<Response<List<int>>> requestBytes(
    String url, {
    Map<String, dynamic>? queryParameters,
    bool absoluteUrl = true,
  }) =>
      _http.requestBytes(
        url,
        queryParameters: queryParameters,
        absoluteUrl: absoluteUrl,
      );

  // ─── Lightweight method aliases ────────────────────────────────────
  //
  // These exist so calling code reads the same as a raw Dio call.
  // Prefer the typed sub-APIs (account, library, …) when possible —
  // these are the escape hatch for endpoints not yet covered.

  /// Issue a `GET` via [request].
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? extraHeaders,
  }) =>
      request<T>(
        path,
        queryParameters: queryParameters,
        extraHeaders: extraHeaders,
      );

  /// Issue a `POST` via [request].
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? extraHeaders,
  }) =>
      request<T>(
        path,
        method: 'POST',
        data: data,
        queryParameters: queryParameters,
        extraHeaders: extraHeaders,
      );

  /// Issue a `PUT` via [request].
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? extraHeaders,
  }) =>
      request<T>(
        path,
        method: 'PUT',
        data: data,
        queryParameters: queryParameters,
        extraHeaders: extraHeaders,
      );

  /// Issue a `DELETE` via [request].
  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? extraHeaders,
  }) =>
      request<T>(
        path,
        method: 'DELETE',
        queryParameters: queryParameters,
        extraHeaders: extraHeaders,
      );

  /// Alias for [requestBytes] — kept so the calling code can read like
  /// the original Dio-based wrapper it replaced.
  Future<Response<List<int>>> fetchBytes(String url) =>
      requestBytes(url, absoluteUrl: true);
}
