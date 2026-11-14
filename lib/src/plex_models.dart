// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Plain immutable DTOs for the Plex API.
///
/// All models are plain Dart classes (no freezed / json_serializable) so
/// the package stays codegen-free. `fromJson` factories accept either the
/// shape returned by `plex.tv/api/v2/*` (top-level object) or the shape
/// nested inside a `MediaContainer` envelope (PMS endpoints).
library;

export 'models/plex_base_models.dart';
export 'models/plex_download_queue_models.dart';
export 'models/plex_dvr_models.dart';
export 'models/plex_epg_models.dart';
export 'models/plex_home_models.dart';
export 'models/plex_hub_models.dart';
export 'models/plex_library_models.dart';
export 'models/plex_lyrics_models.dart';
export 'models/plex_media_models.dart';
export 'models/plex_metadata_models.dart';
export 'models/plex_play_queue_models.dart';
export 'models/plex_recording_models.dart';
export 'models/plex_resource_models.dart';
export 'models/plex_server_admin_models.dart';
export 'models/plex_server_models.dart';
export 'models/plex_session_models.dart';
export 'models/plex_sign_in_models.dart';
export 'models/plex_transcode_models.dart';
export 'models/plex_ultra_blur_models.dart';
