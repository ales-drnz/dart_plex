// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Pure-Dart client for Plex Media Server.
///
/// Entry point is [PlexClient] — a stateful façade that holds the
/// credentials/token across calls and exposes one sub-API per domain:
///
/// ```dart
/// final plex = PlexClient(
///   credentials: const PlexCredentials(
///     clientIdentifier: '2f5b…-uuid',
///     product: 'Finova',
///     version: '1.0.0',
///     device: 'iPhone',
///     deviceName: "Alex's iPhone",
///     platform: 'iOS',
///   ),
/// );
///
/// // 1. Authenticate against plex.tv
/// final user = await plex.account.signInWithPassword(username: 'alex', password: 'hunter2');
///
/// // 2. Discover the user's servers and connect to one
/// final resources = await plex.account.fetchResources();
/// final server = resources.firstWhere((r) => r.owned);
/// plex.connect(server.bestConnection()!.uri, accessToken: server.accessToken);
///
/// // 3. Browse libraries
/// final libs = await plex.library.sections();
/// final musicLib = libs.firstWhere((l) => l.type == PlexLibraryType.music);
/// final albums = await plex.library.allByType(
///   sectionId: musicLib.id,
///   type: PlexMetadataType.album,
///   limit: 50,
/// );
/// ```
///
/// Higher-level use cases (artwork URLs, transcode session URLs,
/// playback reporting) are exposed through dedicated sub-APIs:
/// [PlexClient.images], [PlexClient.streaming], [PlexClient.playback].
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
export 'src/plex_client.dart';
export 'src/plex_credentials.dart';
export 'src/plex_error_type.dart';
export 'src/plex_exception.dart';
export 'src/plex_models.dart';
