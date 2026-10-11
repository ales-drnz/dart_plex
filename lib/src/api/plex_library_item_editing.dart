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
    final qp = <String, Object?>{};
    if (agent != null) qp['agent'] = agent;
    if (markUpdated != null) qp['markUpdated'] = markUpdated ? 1 : 0;
    await _http.request<void>(
      '/library/metadata/$ids/refresh',
      method: 'PUT',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// `PUT /library/metadata/{ids}/analyze` — re-run media analysis.
  Future<void> analyzeItem({
    required String ids,
    int? thumbOffset,
    int? artOffset,
  }) async {
    final qp = <String, Object?>{};
    if (thumbOffset != null) qp['thumbOffset'] = thumbOffset;
    if (artOffset != null) qp['artOffset'] = artOffset;
    await _http.request<void>(
      '/library/metadata/$ids/analyze',
      method: 'PUT',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// `PUT /library/metadata/{ids}/intro?force={b}&threshold={n}` —
  /// intro detection.
  Future<void> detectIntros({
    required String ids,
    bool force = false,
    double? threshold,
  }) async {
    final qp = <String, Object?>{'force': force ? 1 : 0};
    if (threshold != null) qp['threshold'] = threshold;
    await _http.request<void>(
      '/library/metadata/$ids/intro',
      method: 'PUT',
      queryParameters: qp,
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
      '/library/metadata/$ids/credits',
      method: 'PUT',
      queryParameters: {
        'force': force ? 1 : 0,
        'manual': manual ? 1 : 0,
      },
    );
  }

  /// `PUT /library/metadata/{ids}/addetect` — ad detection (on
  /// recorded TV).
  Future<void> detectAds({required String ids}) async {
    await _http.request<void>(
      '/library/metadata/$ids/addetect',
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
      '/library/metadata/$ids/voiceActivity',
      method: 'PUT',
      queryParameters: {
        'force': force ? 1 : 0,
        'manual': manual ? 1 : 0,
      },
    );
  }

  /// `PUT /library/metadata/{ids}/chapterThumbs?force={b}` —
  /// generate chapter thumbnails.
  Future<void> generateChapterThumbs({
    required String ids,
    bool force = false,
  }) async {
    await _http.request<void>(
      '/library/metadata/$ids/chapterThumbs',
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
      '/library/metadata/$ids/index',
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
    final qp = <String, Object?>{};
    if (guid != null) qp['guid'] = guid;
    if (name != null) qp['name'] = name;
    if (year != null) qp['year'] = year;
    await _http.request<void>(
      '/library/metadata/$ids/match',
      method: 'PUT',
      queryParameters: qp.isEmpty ? null : qp,
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
    final qp = <String, Object?>{};
    if (title != null) qp['title'] = title;
    if (parentTitle != null) qp['parentTitle'] = parentTitle;
    if (agent != null) qp['agent'] = agent;
    if (language != null) qp['language'] = language;
    if (year != null) qp['year'] = year;
    if (manual != null) qp['manual'] = manual ? 1 : 0;
    final res = await _http.request<Map<String, Object?>>(
      '/library/metadata/$ids/matches',
      method: 'PUT',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `PUT /library/metadata/{ids}/unmatch` — clear the upstream
  /// guid match.
  Future<void> unmatch({required String ids}) async {
    await _http.request<void>(
      '/library/metadata/$ids/unmatch',
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
      '/library/metadata/$primaryId/merge',
      method: 'PUT',
      queryParameters: {'ids': otherIds.join(',')},
    );
  }

  /// `PUT /library/metadata/{ids}/split` — undo a merge.
  Future<void> splitItem({required String ids}) async {
    await _http.request<void>(
      '/library/metadata/$ids/split',
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
      '/library/metadata/$ids/prefs',
      method: 'PUT',
      queryParameters: args,
    );
  }

  /// `GET /library/metadata/{ids}/related` — related-items hub for
  /// a metadata item.
  Future<List<PlexHub>> relatedItems({required String ids}) async {
    return _http.requestJson(
      '/library/metadata/$ids/related',
      itemsOf('Hub', PlexHub.fromJson),
    );
  }

  /// `GET /library/metadata/{ids}/extras` — bonus content
  /// (interviews, trailers) attached to an item.
  Future<List<PlexMetadata>> extras({required String ids}) async {
    return _http.requestJson(
      '/library/metadata/$ids/extras',
      itemsOf('Metadata', PlexMetadata.fromJson),
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
      '/library/metadata/$ids/extras',
      method: 'POST',
      queryParameters: {'extraType': extraType, 'url': url},
    );
  }

  /// `GET /library/metadata/{ids}/file?url={inBundlePath}` — fetch
  /// a file inside the item's metadata bundle.
  String itemFileUrl({required String ids, required String url}) {
    final base = _http.baseUrl;
    final token = _http.token ?? '';
    return '$base/library/metadata/$ids/file?url=${Uri.encodeQueryComponent(url)}&X-Plex-Token=$token';
  }

  /// `GET /library/metadata/{ids}/tree` — items as a hierarchical
  /// tree (parents → children).
  Future<Map<String, Object?>> itemTree({required String ids}) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/metadata/$ids/tree',
    );
    return res.data ?? const {};
  }

  /// `GET /library/metadata/{ids}/users/top` — top listeners /
  /// viewers for this item.
  Future<Map<String, Object?>> topUsers({required String ids}) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/metadata/$ids/users/top',
    );
    return res.data ?? const {};
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
    final qp = <String, Object?>{
      'title': title,
      'language': language,
      'url': url,
    };
    if (format != null) qp['format'] = format;
    if (mediaItemID != null) qp['mediaItemID'] = mediaItemID;
    if (forced != null) qp['forced'] = forced ? 1 : 0;
    if (hearingImpaired != null) {
      qp['hearingImpaired'] = hearingImpaired ? 1 : 0;
    }
    await _http.request<void>(
      '/library/metadata/$ids/subtitles',
      queryParameters: qp,
    );
  }

  /// `GET /library/metadata/{ids}/{element}/{timestamp}` — URL for
  /// an item's artwork, theme, or other typed asset.
  String itemArtworkUrl({
    required String ids,
    required String element,
    required int timestamp,
  }) {
    final base = _http.baseUrl;
    final token = _http.token ?? '';
    return '$base/library/metadata/$ids/$element/$timestamp?X-Plex-Token=$token';
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
      '/library/metadata/$ids/$element',
      method: update ? 'PUT' : 'POST',
      queryParameters: url != null ? {'url': url} : null,
      data: data,
    );
  }
}
