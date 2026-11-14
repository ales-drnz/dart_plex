// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of 'plex_library_api.dart';

/// Creating, editing, scanning and deleting library sections, and the
/// housekeeping of the whole library. Mixed into [PlexLibraryApi].
mixin _PlexSectionAdmin {
  PlexConnection get _http;

  // -------------------------------------------------------------------------
  // Section management
  // -------------------------------------------------------------------------

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

  /// `PUT /library/sections/{sectionId}/all` — bulk-edit the fields
  /// and tags of every item matching a filter, in a single call
  /// (cheaper than N per-item [PlexLibraryApi.editItem] calls for batch tagging or
  /// curation).
  ///
  /// All mutations travel as query parameters (the endpoint has no
  /// request body). [type] is the item type integer.
  ///
  /// [filterExpression] selects the items to mutate and is sent under
  /// the PUT route's own `filters` parameter, which takes one whole
  /// expression as a string (e.g. `'genre=6'`). It is a different
  /// mechanism from the per-parameter [PlexFilter] list that
  /// [PlexLibraryApi.allByType] takes — the read and write routes genuinely disagree
  /// here.
  ///
  /// [changes] holds already-flattened Plex keys, e.g.
  /// `<field>.value` to set a value and `<field>.locked` (`1`/`0`) to
  /// lock it. Tags are added with `<tagtype>[<idx>].tag.tag` and
  /// removed with a trailing `-` on the key
  /// (`<tagtype>[<idx>].tag.tag-`); the `<idx>` must increment per tag.
  Future<void> updateSectionItems({
    required String sectionId,
    int? type,
    String? filterExpression,
    required Map<String, Object?> changes,
  }) async {
    await _http.request<void>(
      '/library/sections/${seg(sectionId)}/all',
      method: 'PUT',
      queryParameters: {
        'type': ?type,
        'filters': ?filterExpression,
        ...changes,
      },
    );
  }

  /// `POST /library/sections` — add a new section to the server.
  /// The spec lists this as `/library/sections/all`, but in practice
  /// the server only accepts POST at `/library/sections` (the `/all`
  /// suffix is for GET reads). Verified against PMS 1.43.x.
  ///
  /// Pass [prefs] using bare preference names (e.g.
  /// `{'enableCinemaTrailers': 0}`); they are auto-wrapped into the
  /// `prefs[<name>]=<value>` form the server requires.
  Future<void> addSection({
    required String name,
    required PlexLibraryType type,
    required String scanner,
    required String agent,
    required List<String> locations,
    String? metadataAgentProviderGroupId,
    String? language,
    Map<String, Object?>? prefs,
    bool? relative,
    bool? importFromiTunes,
  }) async {
    await _http.request<void>(
      '/library/sections',
      method: 'POST',
      queryParameters: {
        'name': name,
        'type': type.wire,
        'scanner': scanner,
        'agent': agent,
        'location': locations,
        'metadataAgentProviderGroupId': ?metadataAgentProviderGroupId,
        'language': ?language,
        'relative': ?_flag(relative),
        'importFromiTunes': ?_flag(importFromiTunes),
        ...?prefs?.map((k, v) => MapEntry('prefs[$k]', v)),
      },
    );
  }

  /// `POST /library/sections/refresh?force={bool}` — refresh every
  /// section.
  Future<void> refreshAllSections({bool force = false}) async {
    await _http.request<void>(
      '/library/sections/refresh',
      method: 'POST',
      queryParameters: {'force': force ? 1 : 0},
    );
  }

  /// `DELETE /library/sections/all/refresh` — stop every running
  /// section refresh.
  Future<void> stopAllRefreshes() async {
    await _http.request<void>(
      '/library/sections/all/refresh',
      method: 'DELETE',
    );
  }

  /// `DELETE /library/caches` — drop the library caches.
  Future<void> deleteCaches() async {
    await _http.request<void>('/library/caches', method: 'DELETE');
  }

  /// `PUT /library/clean/bundles` — clean orphaned metadata
  /// bundles on disk.
  Future<void> cleanBundles() async {
    await _http.request<void>('/library/clean/bundles', method: 'PUT');
  }

  /// `PUT /library/optimize?async={bool}` — re-optimize the SQLite
  /// database.
  Future<void> optimizeDatabase({bool asyncMode = false}) async {
    await _http.request<void>(
      '/library/optimize',
      method: 'PUT',
      queryParameters: {'async': asyncMode ? 1 : 0},
    );
  }
}
