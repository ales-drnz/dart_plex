// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of 'plex_library_api.dart';

/// Creating, editing, scanning and deleting library sections. Mixed into [PlexLibraryApi].
mixin _PlexSectionAdmin {
  PlexConnection get _http;

  // -------------------------------------------------------------------------
  // Section management
  // -------------------------------------------------------------------------

  /// `GET /library/sections/{sectionId}?includeDetails={bool}` —
  /// full section details.
  Future<Map<String, Object?>> sectionDetails({
    required String sectionId,
    bool? includeDetails,
  }) async {
    final qp = <String, Object?>{};
    if (includeDetails != null) qp['includeDetails'] = includeDetails ? 1 : 0;
    final res = await _http.request<Map<String, Object?>>(
      '/library/sections/$sectionId',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `PUT /library/sections/{sectionId}` — edit a section.
  ///
  /// Pass [prefs] using bare preference names (e.g.
  /// `{'enableCinemaTrailers': 0}`); they are auto-wrapped into the
  /// `prefs[<name>]=<value>` form the server requires.
  Future<void> editSection({
    required String sectionId,
    String? name,
    String? scanner,
    String? agent,
    String? metadataAgentProviderGroupId,
    String? language,
    List<String>? locations,
    Map<String, Object?>? prefs,
  }) async {
    final qp = <String, Object?>{};
    if (name != null) qp['name'] = name;
    if (scanner != null) qp['scanner'] = scanner;
    if (agent != null) qp['agent'] = agent;
    if (metadataAgentProviderGroupId != null) {
      qp['metadataAgentProviderGroupId'] = metadataAgentProviderGroupId;
    }
    if (language != null) qp['language'] = language;
    if (locations != null) qp['location'] = locations;
    prefs?.forEach((k, v) => qp['prefs[$k]'] = v);
    await _http.request<void>(
      '/library/sections/$sectionId',
      method: 'PUT',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// `DELETE /library/sections/{sectionId}?async={bool}` — delete
  /// a section.
  Future<void> deleteSection({
    required String sectionId,
    bool asyncMode = false,
  }) async {
    await _http.request<void>(
      '/library/sections/$sectionId',
      method: 'DELETE',
      queryParameters: {'async': asyncMode ? 1 : 0},
    );
  }

  /// `POST /library/sections/{sectionId}/refresh` — kick off a
  /// section refresh.
  Future<void> refreshSection({
    required String sectionId,
    bool force = false,
    String? path,
  }) async {
    final qp = <String, Object?>{'force': force ? 1 : 0};
    if (path != null) qp['path'] = path;
    await _http.request<void>(
      '/library/sections/$sectionId/refresh',
      method: 'POST',
      queryParameters: qp,
    );
  }

  /// `DELETE /library/sections/{sectionId}/refresh` — abort a
  /// running refresh.
  Future<void> cancelSectionRefresh({required String sectionId}) async {
    await _http.request<void>(
      '/library/sections/$sectionId/refresh',
      method: 'DELETE',
    );
  }

  /// `PUT /library/sections/{sectionId}/analyze` — re-analyze every
  /// item in a section (loudness, intros, etc.).
  Future<void> analyzeSection({required String sectionId}) async {
    await _http.request<void>(
      '/library/sections/$sectionId/analyze',
      method: 'PUT',
    );
  }

  /// `PUT /library/sections/{sectionId}/emptyTrash` — empty the
  /// section's recycle bin.
  Future<void> emptyTrash({required String sectionId}) async {
    await _http.request<void>(
      '/library/sections/$sectionId/emptyTrash',
      method: 'PUT',
    );
  }

  /// `DELETE /library/sections/{sectionId}/indexes` — drop the
  /// section's indexes (forces a rebuild on next access).
  Future<void> deleteSectionIndexes({required String sectionId}) async {
    await _http.request<void>(
      '/library/sections/$sectionId/indexes',
      method: 'DELETE',
    );
  }

  /// `DELETE /library/sections/{sectionId}/intros` — drop intro
  /// markers in a section so they can be regenerated.
  Future<void> deleteSectionIntros({required String sectionId}) async {
    await _http.request<void>(
      '/library/sections/$sectionId/intros',
      method: 'DELETE',
    );
  }

  /// `GET /library/sections/{sectionId}/prefs` — section preferences.
  Future<Map<String, Object?>> sectionPreferences({
    required String sectionId,
    String? agent,
  }) async {
    final qp = <String, Object?>{};
    if (agent != null) qp['agent'] = agent;
    final res = await _http.request<Map<String, Object?>>(
      '/library/sections/$sectionId/prefs',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `PUT /library/sections/{sectionId}/prefs` — replace the
  /// section preferences.
  Future<void> setSectionPreferences({
    required String sectionId,
    required Map<String, Object?> prefs,
  }) async {
    await _http.request<void>(
      '/library/sections/$sectionId/prefs',
      method: 'PUT',
      queryParameters: prefs,
    );
  }

  /// `GET /library/sections/{sectionId}/autocomplete?type=...&field.query=...`
  /// — autocomplete suggestions for a search field, e.g.
  /// `fieldQuery: {'title.query': 'Tra'}`.
  ///
  /// [type] is required: PMS 1.43.2 answers 400 without it (verified).
  Future<Map<String, Object?>> autocomplete({
    required String sectionId,
    required PlexMetadataType type,
    Map<String, Object?>? fieldQuery,
  }) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/sections/$sectionId/autocomplete',
      queryParameters: {'type': type.value, ...?fieldQuery},
    );
    return res.data ?? const {};
  }

  /// `GET /library/sections/{sectionId}/firstCharacter?type=...&sort=...` (singular:
  /// `firstCharacters`, as the community API document spells it, answers
  /// 404 on PMS 1.43.2)
  /// — A-Z scrubber index.
  Future<List<PlexMetadata>> firstCharacters({
    required String sectionId,
    String? type,
    String? sort,
  }) async {
    final qp = <String, Object?>{};
    if (type != null) qp['type'] = type;
    if (sort != null) qp['sort'] = sort;
    return _http.requestJson(
      '/library/sections/$sectionId/firstCharacter',
      queryParameters: qp.isEmpty ? null : qp,
      itemsOf('Directory', PlexMetadata.fromJson),
    );
  }

  /// `GET /library/sections/{sectionId}/sorts` — sorts available
  /// on the section.
  Future<List<PlexMetadata>> sectionSorts({required String sectionId}) async {
    return _http.requestJson(
      '/library/sections/$sectionId/sorts',
      itemsOf('Directory', PlexMetadata.fromJson),
    );
  }

  /// `GET /library/sections/{sectionId}/collections` — collections
  /// inside a section.
  Future<List<PlexMetadata>> sectionCollections({
    required String sectionId,
  }) async {
    return _http.requestJson(
      '/library/sections/$sectionId/collections',
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `GET /library/sections/{sectionId}/common?type=...` — common
  /// fields across items (shared genres, ratings, etc.).
  Future<Map<String, Object?>> sectionCommon({
    required String sectionId,
    String? type,
  }) async {
    final qp = <String, Object?>{};
    if (type != null) qp['type'] = type;
    final res = await _http.request<Map<String, Object?>>(
      '/library/sections/$sectionId/common',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `DELETE /library/sections/{sectionId}/collection/{collectionId}`
  /// — delete a collection from a section.
  Future<void> deleteSectionCollection({
    required String sectionId,
    required String collectionId,
  }) async {
    await _http.request<void>(
      '/library/sections/$sectionId/collection/$collectionId',
      method: 'DELETE',
    );
  }

  /// `GET /library/sections/{sectionId}/composite/{updatedAt}` —
  /// URL for the section's auto-composed cover image.
  String sectionCompositeImageUrl({
    required String sectionId,
    required int updatedAt,
  }) {
    final base = _http.baseUrl;
    final token = _http.token ?? '';
    return '$base/library/sections/$sectionId/composite/$updatedAt?X-Plex-Token=$token';
  }
}
