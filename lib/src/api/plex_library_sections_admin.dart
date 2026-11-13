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

  /// `GET /library/sections/{sectionId}?includeDetails={bool}` — the
  /// section's details and views (all items, by genre, search, …).
  Future<PlexSectionDetails> sectionDetails({
    required String sectionId,
    bool? includeDetails,
  }) async {
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}',
      queryParameters: {'includeDetails': ?_flag(includeDetails)},
      (json) => PlexSectionDetails.fromJson(
        json is Map<String, Object?> ? json : const {},
      ),
    );
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
    await _http.request<void>(
      '/library/sections/${seg(sectionId)}',
      method: 'PUT',
      queryParameters: {
        'name': ?name,
        'scanner': ?scanner,
        'agent': ?agent,
        'metadataAgentProviderGroupId': ?metadataAgentProviderGroupId,
        'language': ?language,
        'location': ?locations,
        ...?prefs?.map((k, v) => MapEntry('prefs[$k]', v)),
      },
    );
  }

  /// `DELETE /library/sections/{sectionId}?async={bool}` — delete
  /// a section.
  Future<void> deleteSection({
    required String sectionId,
    bool asyncMode = false,
  }) async {
    await _http.request<void>(
      '/library/sections/${seg(sectionId)}',
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
    await _http.request<void>(
      '/library/sections/${seg(sectionId)}/refresh',
      method: 'POST',
      queryParameters: {'force': force ? 1 : 0, 'path': ?path},
    );
  }

  /// `DELETE /library/sections/{sectionId}/refresh` — abort a
  /// running refresh.
  Future<void> cancelSectionRefresh({required String sectionId}) async {
    await _http.request<void>(
      '/library/sections/${seg(sectionId)}/refresh',
      method: 'DELETE',
    );
  }

  /// `PUT /library/sections/{sectionId}/analyze` — re-analyze every
  /// item in a section (loudness, intros, etc.).
  Future<void> analyzeSection({required String sectionId}) async {
    await _http.request<void>(
      '/library/sections/${seg(sectionId)}/analyze',
      method: 'PUT',
    );
  }

  /// `PUT /library/sections/{sectionId}/emptyTrash` — empty the
  /// section's recycle bin.
  Future<void> emptyTrash({required String sectionId}) async {
    await _http.request<void>(
      '/library/sections/${seg(sectionId)}/emptyTrash',
      method: 'PUT',
    );
  }

  /// `DELETE /library/sections/{sectionId}/indexes` — drop the
  /// section's indexes (forces a rebuild on next access).
  Future<void> deleteSectionIndexes({required String sectionId}) async {
    await _http.request<void>(
      '/library/sections/${seg(sectionId)}/indexes',
      method: 'DELETE',
    );
  }

  /// `DELETE /library/sections/{sectionId}/intros` — drop intro
  /// markers in a section so they can be regenerated.
  Future<void> deleteSectionIntros({required String sectionId}) async {
    await _http.request<void>(
      '/library/sections/${seg(sectionId)}/intros',
      method: 'DELETE',
    );
  }

  /// `GET /library/sections/{sectionId}/prefs` — section preferences.
  Future<Map<String, Object?>> sectionPreferences({
    required String sectionId,
    String? agent,
  }) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/sections/${seg(sectionId)}/prefs',
      queryParameters: {'agent': ?agent},
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
      '/library/sections/${seg(sectionId)}/prefs',
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
      '/library/sections/${seg(sectionId)}/autocomplete',
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
    PlexMetadataType? type,
    PlexSort? sort,
  }) async {
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/firstCharacter',
      queryParameters: {'type': ?type?.value, 'sort': ?sort},
      itemsOf('Directory', PlexMetadata.fromJson),
    );
  }

  /// `GET /library/sections/{sectionId}/sorts` — sorts available
  /// on the section.
  Future<List<PlexMetadata>> sectionSorts({required String sectionId}) async {
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/sorts',
      itemsOf('Directory', PlexMetadata.fromJson),
    );
  }

  /// `GET /library/sections/{sectionId}/collections` — collections
  /// inside a section.
  Future<List<PlexMetadata>> sectionCollections({
    required String sectionId,
  }) async {
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/collections',
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `GET /library/sections/{sectionId}/common?type=...` — common
  /// fields across items (shared genres, ratings, etc.).
  Future<Map<String, Object?>> sectionCommon({
    required String sectionId,
    required PlexMetadataType type,
  }) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/sections/${seg(sectionId)}/common',
      queryParameters: {'type': type.value},
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
      '/library/sections/${seg(sectionId)}/collection/${seg(collectionId)}',
      method: 'DELETE',
    );
  }

  /// `GET /library/sections/{sectionId}/composite/{updatedAt}` —
  /// URL for the section's auto-composed cover image.
  ///
  /// Throws a `state` [PlexException] before [PlexClient.connect]. The URL
  /// carries the token: keep it out of logs.
  String sectionCompositeImageUrl({
    required String sectionId,
    required int updatedAt,
  }) => _http.signedUrl(
    '/library/sections/${seg(sectionId)}/composite/$updatedAt',
  );
}
