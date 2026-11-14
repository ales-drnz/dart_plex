// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of 'plex_library_api.dart';

/// Editing, matching, refreshing and deleting single items. Mixed into [PlexLibraryApi].
mixin _PlexItemEditing {
  PlexConnection get _http;

  // -------------------------------------------------------------------------
  // Per-item operations
  // -------------------------------------------------------------------------

  /// `PUT /library/metadata/{ids}/refresh?agent=...` — refresh
  /// metadata on a single item or a comma-joined list.
  Future<void> refreshItems({
    required String ids,
    String? agent,
    bool? markUpdated,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/refresh',
      method: 'PUT',
      queryParameters: {'agent': ?agent, 'markUpdated': ?_flag(markUpdated)},
    );
  }

  /// `PUT /library/metadata/{ids}/analyze` — re-run media analysis.
  Future<void> analyzeItem({
    required String ids,
    int? thumbOffset,
    int? artOffset,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/analyze',
      method: 'PUT',
      queryParameters: {'thumbOffset': ?thumbOffset, 'artOffset': ?artOffset},
    );
  }

  /// `PUT /library/metadata/{ids}/intro?force={b}&threshold={n}` —
  /// intro detection.
  Future<void> detectIntros({
    required String ids,
    bool force = false,
    double? threshold,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/intro',
      method: 'PUT',
      queryParameters: {'force': force ? 1 : 0, 'threshold': ?threshold},
    );
  }

  /// `PUT /library/metadata/{ids}/credits?force={b}&manual={b}` —
  /// credits detection.
  Future<void> detectCredits({
    required String ids,
    bool force = false,
    bool manual = false,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/credits',
      method: 'PUT',
      queryParameters: {'force': force ? 1 : 0, 'manual': manual ? 1 : 0},
    );
  }

  /// `PUT /library/metadata/{ids}/addetect` — ad detection (on
  /// recorded TV).
  Future<void> detectAds({required String ids}) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/addetect',
      method: 'PUT',
    );
  }

  /// `PUT /library/metadata/{ids}/voiceActivity?force={b}&manual={b}`
  /// — voice-activity detection.
  Future<void> detectVoiceActivity({
    required String ids,
    bool force = false,
    bool manual = false,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/voiceActivity',
      method: 'PUT',
      queryParameters: {'force': force ? 1 : 0, 'manual': manual ? 1 : 0},
    );
  }

  /// `PUT /library/metadata/{ids}/chapterThumbs?force={b}` —
  /// generate chapter thumbnails.
  Future<void> generateChapterThumbs({
    required String ids,
    bool force = false,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/chapterThumbs',
      method: 'PUT',
      queryParameters: {'force': force ? 1 : 0},
    );
  }

  /// `PUT /library/metadata/{ids}/index?force={b}` — start BIF
  /// (Base Index File) generation for scrubbing thumbnails.
  Future<void> startBifGeneration({
    required String ids,
    bool force = false,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/index',
      method: 'PUT',
      queryParameters: {'force': force ? 1 : 0},
    );
  }

  /// `PUT /library/metadata/{ids}/match?guid=...&name=...&year=...`
  /// — pin an item to a specific upstream guid.
  Future<void> matchItem({
    required String ids,
    String? guid,
    String? name,
    int? year,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/match',
      method: 'PUT',
      queryParameters: {'guid': ?guid, 'name': ?name, 'year': ?year},
    );
  }

  /// `PUT /library/metadata/{ids}/matches?title=...&year=...&...` —
  /// list candidate matches for an item.
  Future<Map<String, Object?>> listMatches({
    required String ids,
    String? title,
    String? parentTitle,
    String? agent,
    String? language,
    int? year,
    bool? manual,
  }) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/metadata/${seg(ids)}/matches',
      method: 'PUT',
      queryParameters: {
        'title': ?title,
        'parentTitle': ?parentTitle,
        'agent': ?agent,
        'language': ?language,
        'year': ?year,
        'manual': ?_flag(manual),
      },
    );
    return res.data ?? const {};
  }

  /// `PUT /library/metadata/{ids}/unmatch` — clear the upstream
  /// guid match.
  Future<void> unmatch({required String ids}) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/unmatch',
      method: 'PUT',
    );
  }

  /// `PUT /library/metadata/{ids}/merge?ids={otherIds}` — merge
  /// multiple items into one (handy for de-duping artists).
  Future<void> mergeItems({
    required String primaryId,
    required List<String> otherIds,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(primaryId)}/merge',
      method: 'PUT',
      queryParameters: {'ids': otherIds.join(',')},
    );
  }

  /// `PUT /library/metadata/{ids}/split` — undo a merge.
  Future<void> splitItem({required String ids}) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/split',
      method: 'PUT',
    );
  }

  /// `PUT /library/metadata/{ids}/prefs` — set metadata-edit
  /// locks/overrides.
  Future<void> setItemPreferences({
    required String ids,
    required Map<String, Object?> args,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/prefs',
      method: 'PUT',
      queryParameters: args,
    );
  }

  /// `PUT /library/metadata/{ids}` — edit metadata fields on one item
  /// (or a comma-joined list of `ids`). Admin-token only.
  ///
  /// [args] holds already-flattened Plex query keys. Each field is set
  /// with `<field>.value` and optionally locked against agent
  /// overwrites with `<field>.locked` (`1`/`0`), e.g.
  /// `{'title.value': 'New title', 'title.locked': 1}`. Pass [type]
  /// (the item's [PlexMetadataType]) when the server needs the type
  /// discriminator, mirroring plexapi's `Movie.edit`.
  Future<void> editItem({
    required String ids,
    required Map<String, Object?> args,
    PlexMetadataType? type,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}',
      method: 'PUT',
      queryParameters: {if (type != null) 'type': type.value, ...args},
    );
  }

  /// `DELETE /library/metadata/{ids}` — delete a metadata item from
  /// the library, removing its underlying media as well. Distinct from
  /// [PlexLibraryApi.deleteMediaItem], which only removes one media version.
  ///
  /// Set [proxy] to also delete proxy items associated with the item.
  Future<void> deleteMetadataItem({required String ids, bool? proxy}) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}',
      method: 'DELETE',
      queryParameters: {'proxy': ?_flag(proxy)},
    );
  }

  /// `POST /library/metadata/{ids}/extras?extraType=...&url=...` —
  /// attach a new extra item.
  Future<void> addExtra({
    required String ids,
    required String extraType,
    required String url,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/extras',
      method: 'POST',
      queryParameters: {'extraType': extraType, 'url': url},
    );
  }

  /// `GET /library/metadata/{ids}/subtitles?title=...&language=...&url=...`
  /// — attach an external subtitle file.
  Future<void> addSubtitles({
    required String ids,
    required String title,
    required String language,
    required String url,
    String? format,
    String? mediaItemID,
    bool? forced,
    bool? hearingImpaired,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/subtitles',
      queryParameters: {
        'title': title,
        'language': language,
        'url': url,
        'format': ?format,
        'mediaItemID': ?mediaItemID,
        'forced': ?_flag(forced),
        'hearingImpaired': ?_flag(hearingImpaired),
      },
    );
  }

  /// `POST|PUT /library/metadata/{ids}/{element}?url={url}` — set a
  /// custom artwork/theme asset on an item (e.g. change its poster).
  /// Generally admin-only, except for playlists owned by the user.
  ///
  /// [element] is one of `thumb`, `art`, `clearLogo`, `banner`,
  /// `poster`, `theme`. Provide [url] to pull the asset from a remote
  /// URL, or [data] to upload the asset binary in the request body
  /// (supply exactly one). Uses POST when [update] is false (the
  /// default) and PUT when true; both map to the same server action.
  Future<void> setItemArtwork({
    required String ids,
    required String element,
    String? url,
    List<int>? data,
    bool update = false,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/${seg(element)}',
      method: update ? 'PUT' : 'POST',
      queryParameters: {'url': ?url},
      data: data,
    );
  }
}
