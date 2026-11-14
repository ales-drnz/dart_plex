// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// A Dart client for Plex Media Server 1.43 and plex.tv.
///
/// [PlexClient] holds the client identity, the server and the tokens, and
/// exposes one sub-API per domain:
///
/// ```dart
/// final plex = PlexClient(
///   credentials: const PlexCredentials(
///     clientIdentifier: 'a-stable-id-per-install',
///     product: 'MyApp',
///     version: '1.0.0',
///     device: 'iPhone',
///     deviceName: 'My iPhone',
///     platform: 'iOS',
///   ),
/// );
///
/// // Sign in with a device key: the user approves the pin in a browser.
/// final key = await PlexDeviceKey.generate();
/// var pin = await plex.account.createJwtPin(key: key);
/// openBrowser(plex.account.authAppUrl(pin));
/// while (!pin.isAuthenticated) {
///   await Future<void>.delayed(const Duration(seconds: 1));
///   pin = await plex.account.pollJwtPin(id: pin.id, key: key);
/// }
/// await plex.useJwt(
///   PlexJwtSession(key: key, token: PlexJwt.parse(pin.authToken!)),
/// );
///
/// final servers = await plex.account.fetchResources();
/// final server = servers.firstWhere((s) => s.owned);
/// await plex.connectToResource(server);
///
/// final sections = await plex.library.sections();
/// final music = sections.firstWhere((s) => s.type == PlexLibraryType.music);
/// final albums = await plex.library.allByType(
///   sectionId: music.id,
///   type: PlexMetadataType.album,
///   size: 50,
/// );
/// ```
/// @docImport 'src/plex_client.dart';
library;

export 'src/api/plex_account_api.dart';
export 'src/api/plex_activities_api.dart';
export 'src/api/plex_butler_api.dart';
export 'src/api/plex_collections_api.dart';
export 'src/api/plex_devices_api.dart';
export 'src/api/plex_download_queue_api.dart';
export 'src/api/plex_dvrs_api.dart';
export 'src/api/plex_epg_api.dart';
export 'src/api/plex_hubs_api.dart';
export 'src/api/plex_images_api.dart';
export 'src/api/plex_library_api.dart';
export 'src/api/plex_live_tv_api.dart';
export 'src/api/plex_log_api.dart';
export 'src/api/plex_notifications_api.dart';
export 'src/api/plex_play_queues_api.dart';
export 'src/api/plex_playback_api.dart';
export 'src/api/plex_playlists_api.dart';
export 'src/api/plex_preferences_api.dart';
export 'src/api/plex_providers_api.dart';
export 'src/api/plex_search_api.dart';
export 'src/api/plex_server_api.dart';
export 'src/api/plex_sessions_api.dart';
export 'src/api/plex_streaming_api.dart';
export 'src/api/plex_subscriptions_api.dart';
export 'src/api/plex_transcoder_api.dart';
export 'src/api/plex_ultra_blur_api.dart';
export 'src/api/plex_updater_api.dart';
export 'src/models/plex_server_models.dart';
export 'src/plex_client.dart';
export 'src/plex_credentials.dart';
export 'src/plex_error_type.dart';
export 'src/plex_events.dart';
export 'src/plex_exception.dart';
export 'src/plex_filter.dart';
export 'src/plex_jwt.dart' show PlexDeviceKey, PlexJwt, PlexJwtSession;
export 'src/plex_models.dart';
export 'src/plex_paging.dart';
export 'src/plex_vocabulary.dart';
export 'src/transport/plex_cancel_token.dart';
export 'src/transport/plex_response.dart';
export 'src/transport/plex_retry_policy.dart';
