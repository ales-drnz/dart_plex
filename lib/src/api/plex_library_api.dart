// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';
import '../plex_models.dart';

/// Browse `/library/sections` and `/library/metadata/{id}`.
class PlexLibraryApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.library].
  PlexLibraryApi(this._http);

  // -------------------------------------------------------------------------
  // Sections
  // -------------------------------------------------------------------------

  /// List every library section on the server (`/library/sections`).
  ///
  /// `type` (`artist|movie|show|photo`) reveals which content kind is
  /// served. Music apps typically pick the first
  /// [PlexLibraryType.music] entry.
  Future<List<PlexLibrarySection>> sections() async {
    final res = await _http.request<Map<String, dynamic>>('/library/sections');
    final c = PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Directory',
      PlexLibrarySection.fromJson,
    );
    return c.items;
  }

  // -------------------------------------------------------------------------
  // Items inside a section
  // -------------------------------------------------------------------------

  /// Paged list of items inside a section, filtered by [type].
  ///
  /// Pass a [PlexMetadataType]; see its members for the wire integers
  /// the server expects (the single source of truth for those values).
  ///
  /// `sort` examples: `'titleSort:asc'`, `'addedAt:desc'`,
  /// `'lastViewedAt:desc'`, `'originallyAvailableAt:desc'`.
  ///
  /// [filter] gives you the raw filter expression Plex expects, e.g.
  /// `'genre=Rock'`, `'year>=2010'`. Pass as already-encoded value.
  Future<PlexMediaContainer<PlexMetadata>> allByType({
    required String sectionId,
    required PlexMetadataType type,
    int start = 0,
    int size = 50,
    String? sort,
    String? title,
    String? filter,
  }) async {
    final qp = <String, dynamic>{
      'type': type.value,
      'X-Plex-Container-Start': start,
      'X-Plex-Container-Size': size,
    };
    if (sort != null) qp['sort'] = sort;
    if (title != null) qp['title'] = title;
    if (filter != null) qp['filter'] = filter;
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/all',
      queryParameters: qp,
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    );
  }

  /// Count-only variant of [allByType] — returns the section's
  /// `totalSize` without paying the cost of streaming the items down.
  ///
  /// Implemented with `X-Plex-Container-Size=0` which Plex honours.
  Future<int> countByType({
    required String sectionId,
    required PlexMetadataType type,
    String? filter,
  }) async {
    final qp = <String, dynamic>{
      'type': type.value,
      'X-Plex-Container-Start': 0,
      'X-Plex-Container-Size': 0,
    };
    if (filter != null) qp['filter'] = filter;
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/all',
      queryParameters: qp,
    );
    final raw = res.data ?? const <String, dynamic>{};
    final container = raw['MediaContainer'];
    if (container is Map<String, dynamic>) {
      final v = container['totalSize'] ?? container['size'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
    }
    return 0;
  }

  /// `PUT /library/sections/{sectionId}/all` — bulk-edit the fields
  /// and tags of every item matching a filter, in a single call
  /// (cheaper than N per-item [editItem] calls for batch tagging or
  /// curation).
  ///
  /// All mutations travel as query parameters (the endpoint has no
  /// request body). [type] is the item type integer and [filters] is
  /// the filter expression selecting the items to mutate.
  ///
  /// [changes] holds already-flattened Plex keys, e.g.
  /// `<field>.value` to set a value and `<field>.locked` (`1`/`0`) to
  /// lock it. Tags are added with `<tagtype>[<idx>].tag.tag` and
  /// removed with a trailing `-` on the key
  /// (`<tagtype>[<idx>].tag.tag-`); the `<idx>` must increment per tag.
  Future<void> updateSectionItems({
    required String sectionId,
    int? type,
    String? filters,
    required Map<String, dynamic> changes,
  }) async {
    final qp = <String, dynamic>{};
    if (type != null) qp['type'] = type;
    if (filters != null) qp['filters'] = filters;
    qp.addAll(changes);
    await _http.request<void>(
      '/library/sections/$sectionId/all',
      method: 'PUT',
      queryParameters: qp,
    );
  }

  /// Browse the genres index of a section (`/library/sections/{id}/genre`).
  Future<List<PlexMetadata>> genres({
    required String sectionId,
    required PlexMetadataType type,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/genre',
      queryParameters: {'type': type.value},
    );
    final c = PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Directory',
      PlexMetadata.fromJson,
    );
    return c.items;
  }

  // -------------------------------------------------------------------------
  // Single item
  // -------------------------------------------------------------------------

  /// Full metadata for one item (`/library/metadata/{ratingKey}`).
  Future<PlexMetadata?> item(String ratingKey) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/metadata/$ratingKey',
    );
    final c = PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    );
    return c.items.isEmpty ? null : c.items.first;
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
    required Map<String, dynamic> args,
    PlexMetadataType? type,
  }) async {
    await _http.request<void>(
      '/library/metadata/$ids',
      method: 'PUT',
      queryParameters: {
        if (type != null) 'type': type.value,
        ...args,
      },
    );
  }

  /// `DELETE /library/metadata/{ids}` — delete a metadata item from
  /// the library, removing its underlying media as well. Distinct from
  /// [deleteMediaItem], which only removes one media version.
  ///
  /// Set [proxy] to also delete proxy items associated with the item.
  Future<void> deleteMetadataItem({
    required String ids,
    bool? proxy,
  }) async {
    final qp = <String, dynamic>{};
    if (proxy != null) qp['proxy'] = proxy ? 1 : 0;
    await _http.request<void>(
      '/library/metadata/$ids',
      method: 'DELETE',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// Children of an item — album tracks, artist albums, season episodes.
  Future<List<PlexMetadata>> children(String ratingKey) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/metadata/$ratingKey/children',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// All leaves under an item — every track under an artist, every
  /// episode under a show. Useful for "play artist" / "play show".
  Future<List<PlexMetadata>> allLeaves(String ratingKey) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/metadata/$ratingKey/allLeaves',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  // -------------------------------------------------------------------------
  // Similar / sonic radio
  // -------------------------------------------------------------------------

  /// `/library/metadata/{ratingKey}/similar` — items the server
  /// considers similar to this one (works for albums, artists, movies,
  /// shows).
  Future<List<PlexMetadata>> similar({
    required String ratingKey,
    int? count,
  }) async {
    final qp = <String, dynamic>{};
    if (count != null) qp['count'] = count;
    final res = await _http.request<Map<String, dynamic>>(
      '/library/metadata/$ratingKey/similar',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `/library/metadata/{ratingKey}/nearest` — sonically nearest
  /// tracks to a seed track (requires music sonic analysis on the
  /// server). Used to build "sonic radio".
  Future<List<PlexMetadata>> nearestToTrack({
    required String ratingKey,
    int? limit,
    double? maxDistance,
    int? excludeParentID,
    int? excludeGrandparentID,
  }) async {
    final qp = <String, dynamic>{};
    if (limit != null) qp['limit'] = limit;
    if (maxDistance != null) qp['maxDistance'] = maxDistance;
    if (excludeParentID != null) qp['excludeParentID'] = excludeParentID;
    if (excludeGrandparentID != null) {
      qp['excludeGrandparentID'] = excludeGrandparentID;
    }
    final res = await _http.request<Map<String, dynamic>>(
      '/library/metadata/$ratingKey/nearest',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  // -------------------------------------------------------------------------
  // Section facets and sub-buckets
  // -------------------------------------------------------------------------

  /// `/library/sections/{sectionId}/filters` — list of facets the
  /// server can filter on (genre, year, decade, etc.). Each entry
  /// carries a `Pivot` array with pre-built sub-views, e.g.
  /// "firstCharacter" for an A-Z index or "folder" for the file-tree
  /// view.
  Future<List<PlexMetadata>> filters({required String sectionId}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/filters',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Directory',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `/library/sections/{sectionId}/albums` — every album in a music
  /// section. Cheaper than `allByType(type: album)` when no sort or
  /// filter is needed.
  Future<PlexMediaContainer<PlexMetadata>> albums({
    required String sectionId,
    int start = 0,
    int size = 50,
  }) async {
    final qp = <String, dynamic>{
      'X-Plex-Container-Start': start,
      'X-Plex-Container-Size': size,
    };
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/albums',
      queryParameters: qp,
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    );
  }

  /// `/library/sections/{sectionId}/location` — folder roots
  /// configured for the section (one entry per scanned directory).
  Future<List<PlexMetadata>> folderLocations({
    required String sectionId,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/location',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Directory',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `/library/sections/{sectionId}/categories` — server-defined
  /// categories for the section (mostly used by photo libraries).
  Future<List<PlexMetadata>> categories({required String sectionId}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/categories',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `/library/sections/{sectionId}/allLeaves` — every leaf-level
  /// item in a section (e.g. every episode of every show).
  Future<List<PlexMetadata>> sectionAllLeaves({
    required String sectionId,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/allLeaves',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `/library/sections/{sectionId}/arts` — backdrop artwork
  /// (Directory entries with `art` paths).
  Future<List<PlexMetadata>> sectionArts({required String sectionId}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/arts',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Directory',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `/library/sections/{sectionId}/cluster` — clusters used to
  /// group photo libraries (proximity / similarity buckets).
  Future<List<PlexMetadata>> sectionClusters({
    required String sectionId,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/cluster',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Directory',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `/library/sections/{sectionId}/moment` — moments index for a
  /// photo library (notable moments grouped by date/place).
  Future<List<PlexMetadata>> sectionMoments({required String sectionId}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/moment',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Directory',
      PlexMetadata.fromJson,
    ).items;
  }

  // -------------------------------------------------------------------------
  // Library-wide reads / housekeeping
  // -------------------------------------------------------------------------

  /// `GET /library/all` — every item across every section. Heavy
  /// query; use sections / `allByType` for normal browsing.
  Future<List<PlexMetadata>> all() async {
    final res = await _http.request<Map<String, dynamic>>('/library/all');
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `GET /library/sections/all` — every section's metadata (Media
  /// Provider Only view). Lighter than [sections]; useful for the
  /// "primary library" entry point.
  Future<List<PlexLibrarySection>> sectionsAll() async {
    final res =
        await _http.request<Map<String, dynamic>>('/library/sections/all');
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Directory',
      PlexLibrarySection.fromJson,
    ).items;
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
    required String type,
    required String scanner,
    required String agent,
    required List<String> locations,
    String? metadataAgentProviderGroupId,
    String? language,
    Map<String, dynamic>? prefs,
    bool? relative,
    bool? importFromiTunes,
  }) async {
    final qp = <String, dynamic>{
      'name': name,
      'type': type,
      'scanner': scanner,
      'agent': agent,
      'location': locations,
    };
    if (metadataAgentProviderGroupId != null) {
      qp['metadataAgentProviderGroupId'] = metadataAgentProviderGroupId;
    }
    if (language != null) qp['language'] = language;
    if (relative != null) qp['relative'] = relative ? 1 : 0;
    if (importFromiTunes != null) {
      qp['importFromiTunes'] = importFromiTunes ? 1 : 0;
    }
    prefs?.forEach((k, v) => qp['prefs[$k]'] = v);
    await _http.request<void>(
      '/library/sections',
      method: 'POST',
      queryParameters: qp,
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

  /// `GET /library/tags` — every tag value across the library.
  Future<Map<String, dynamic>> tags() async {
    final res = await _http.request<Map<String, dynamic>>('/library/tags');
    return res.data ?? const {};
  }

  /// `GET /library/randomArtwork?sections={ids}` — random backdrop
  /// across the supplied sections. Useful as a screensaver source.
  Future<Map<String, dynamic>> randomArtwork({String? sections}) async {
    final qp = <String, dynamic>{};
    if (sections != null) qp['sections'] = sections;
    final res = await _http.request<Map<String, dynamic>>(
      '/library/randomArtwork',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `GET /library/matches` — query the metadata-agent match cache.
  Future<Map<String, dynamic>> matches(Map<String, dynamic> filters) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/matches',
      queryParameters: filters,
    );
    return res.data ?? const {};
  }

  /// `POST /library/file?url={path}&virtualFilePath={...}` — ingest
  /// a file from disk without first scanning it via a section.
  Future<Map<String, dynamic>> ingestTransientItem({
    required String url,
    String? virtualFilePath,
    bool? computeHashes,
    bool? ingestNonMatches,
  }) async {
    final qp = <String, dynamic>{'url': url};
    if (virtualFilePath != null) qp['virtualFilePath'] = virtualFilePath;
    if (computeHashes != null) qp['computeHashes'] = computeHashes ? 1 : 0;
    if (ingestNonMatches != null) {
      qp['ingestNonMatches'] = ingestNonMatches ? 1 : 0;
    }
    final res = await _http.request<Map<String, dynamic>>(
      '/library/file',
      method: 'POST',
      queryParameters: qp,
    );
    return res.data ?? const {};
  }

  /// `GET /library/sections/prefs?type={t}&agent={a}` — default
  /// section preferences for a media type + agent combination.
  Future<Map<String, dynamic>> defaultSectionPrefs({
    String? type,
    String? agent,
  }) async {
    final qp = <String, dynamic>{};
    if (type != null) qp['type'] = type;
    if (agent != null) qp['agent'] = agent;
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/prefs',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  // -------------------------------------------------------------------------
  // Section management
  // -------------------------------------------------------------------------

  /// `GET /library/sections/{sectionId}?includeDetails={bool}` —
  /// full section details.
  Future<Map<String, dynamic>> sectionDetails({
    required String sectionId,
    bool? includeDetails,
  }) async {
    final qp = <String, dynamic>{};
    if (includeDetails != null) qp['includeDetails'] = includeDetails ? 1 : 0;
    final res = await _http.request<Map<String, dynamic>>(
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
    Map<String, dynamic>? prefs,
  }) async {
    final qp = <String, dynamic>{};
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
    final qp = <String, dynamic>{'force': force ? 1 : 0};
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
  Future<Map<String, dynamic>> sectionPreferences({
    required String sectionId,
    String? agent,
  }) async {
    final qp = <String, dynamic>{};
    if (agent != null) qp['agent'] = agent;
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/prefs',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `PUT /library/sections/{sectionId}/prefs` — replace the
  /// section preferences.
  Future<void> setSectionPreferences({
    required String sectionId,
    required Map<String, dynamic> prefs,
  }) async {
    await _http.request<void>(
      '/library/sections/$sectionId/prefs',
      method: 'PUT',
      queryParameters: prefs,
    );
  }

  /// `GET /library/sections/{sectionId}/autocomplete?type=...&field.query=...`
  /// — autocomplete suggestions for a search field.
  Future<Map<String, dynamic>> autocomplete({
    required String sectionId,
    String? type,
    Map<String, dynamic>? fieldQuery,
  }) async {
    final qp = <String, dynamic>{};
    if (type != null) qp['type'] = type;
    if (fieldQuery != null) qp.addAll(fieldQuery);
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/autocomplete',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `GET /library/sections/{sectionId}/firstCharacters?type=...&sort=...`
  /// — A-Z scrubber index.
  Future<List<PlexMetadata>> firstCharacters({
    required String sectionId,
    String? type,
    String? sort,
  }) async {
    final qp = <String, dynamic>{};
    if (type != null) qp['type'] = type;
    if (sort != null) qp['sort'] = sort;
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/firstCharacters',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Directory',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `GET /library/sections/{sectionId}/sorts` — sorts available
  /// on the section.
  Future<List<PlexMetadata>> sectionSorts({required String sectionId}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/sorts',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Directory',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `GET /library/sections/{sectionId}/collections` — collections
  /// inside a section.
  Future<List<PlexMetadata>> sectionCollections({
    required String sectionId,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/collections',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `GET /library/sections/{sectionId}/common?type=...` — common
  /// fields across items (shared genres, ratings, etc.).
  Future<Map<String, dynamic>> sectionCommon({
    required String sectionId,
    String? type,
  }) async {
    final qp = <String, dynamic>{};
    if (type != null) qp['type'] = type;
    final res = await _http.request<Map<String, dynamic>>(
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
    final qp = <String, dynamic>{};
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
    final qp = <String, dynamic>{};
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
    final qp = <String, dynamic>{'force': force ? 1 : 0};
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
    final qp = <String, dynamic>{};
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
  Future<Map<String, dynamic>> listMatches({
    required String ids,
    String? title,
    String? parentTitle,
    String? agent,
    String? language,
    int? year,
    bool? manual,
  }) async {
    final qp = <String, dynamic>{};
    if (title != null) qp['title'] = title;
    if (parentTitle != null) qp['parentTitle'] = parentTitle;
    if (agent != null) qp['agent'] = agent;
    if (language != null) qp['language'] = language;
    if (year != null) qp['year'] = year;
    if (manual != null) qp['manual'] = manual ? 1 : 0;
    final res = await _http.request<Map<String, dynamic>>(
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
    required Map<String, dynamic> args,
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
    final res = await _http.request<Map<String, dynamic>>(
      '/library/metadata/$ids/related',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Hub',
      PlexHub.fromJson,
    ).items;
  }

  /// `GET /library/metadata/{ids}/extras` — bonus content
  /// (interviews, trailers) attached to an item.
  Future<List<PlexMetadata>> extras({required String ids}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/metadata/$ids/extras',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
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
  Future<Map<String, dynamic>> itemTree({required String ids}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/metadata/$ids/tree',
    );
    return res.data ?? const {};
  }

  /// `GET /library/metadata/{ids}/users/top` — top listeners /
  /// viewers for this item.
  Future<Map<String, dynamic>> topUsers({required String ids}) async {
    final res = await _http.request<Map<String, dynamic>>(
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
    final qp = <String, dynamic>{
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

  // -------------------------------------------------------------------------
  // Markers (chapter / intro / credits)
  // -------------------------------------------------------------------------

  /// `POST /library/metadata/{ids}/marker?type=...&startTimeOffset=...&endTimeOffset=...`
  /// — create a marker.
  Future<void> createMarker({
    required String ids,
    required String type,
    required int startTimeOffset,
    required int endTimeOffset,
    Map<String, dynamic>? attributes,
  }) async {
    final qp = <String, dynamic>{
      'type': type,
      'startTimeOffset': startTimeOffset,
      'endTimeOffset': endTimeOffset,
    };
    if (attributes != null) qp.addAll(attributes);
    await _http.request<void>(
      '/library/metadata/$ids/marker',
      method: 'POST',
      queryParameters: qp,
    );
  }

  /// `PUT /library/metadata/{ids}/marker/{marker}` — edit a marker.
  Future<void> editMarker({
    required String ids,
    required String marker,
    String? type,
    int? startTimeOffset,
    int? endTimeOffset,
    Map<String, dynamic>? attributes,
  }) async {
    final qp = <String, dynamic>{};
    if (type != null) qp['type'] = type;
    if (startTimeOffset != null) qp['startTimeOffset'] = startTimeOffset;
    if (endTimeOffset != null) qp['endTimeOffset'] = endTimeOffset;
    if (attributes != null) qp.addAll(attributes);
    await _http.request<void>(
      '/library/metadata/$ids/marker/$marker',
      method: 'PUT',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// `DELETE /library/metadata/{ids}/marker/{marker}` — delete a
  /// marker.
  Future<void> deleteMarker({
    required String ids,
    required String marker,
  }) async {
    await _http.request<void>(
      '/library/metadata/$ids/marker/$marker',
      method: 'DELETE',
    );
  }

  /// `DELETE /library/metadata/{ids}/media/{mediaItem}` — delete
  /// one media item (file) from an item, keeping the metadata.
  Future<void> deleteMediaItem({
    required String ids,
    required String mediaItem,
    bool? proxy,
  }) async {
    final qp = <String, dynamic>{};
    if (proxy != null) qp['proxy'] = proxy ? 1 : 0;
    await _http.request<void>(
      '/library/metadata/$ids/media/$mediaItem',
      method: 'DELETE',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// `GET /library/media/{mediaId}/chapterImages/{chapter}` — URL
  /// for a chapter thumbnail.
  String chapterImageUrl({required String mediaId, required int chapter}) {
    final base = _http.baseUrl;
    final token = _http.token ?? '';
    return '$base/library/media/$mediaId/chapterImages/$chapter?X-Plex-Token=$token';
  }

  // -------------------------------------------------------------------------
  // Streams (audio / subtitle / video)
  // -------------------------------------------------------------------------

  /// `GET /library/streams/{streamId}.{ext}` — URL for a media
  /// stream file (subtitle text, etc.).
  String streamUrl({
    required String streamId,
    required String ext,
    String? encoding,
    String? format,
    bool? autoAdjustSubtitle,
  }) {
    final base = _http.baseUrl;
    final token = _http.token ?? '';
    final qp = <String, String>{'X-Plex-Token': token};
    if (encoding != null) qp['encoding'] = encoding;
    if (format != null) qp['format'] = format;
    if (autoAdjustSubtitle != null) {
      qp['autoAdjustSubtitle'] = autoAdjustSubtitle ? '1' : '0';
    }
    final query = qp.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$base/library/streams/$streamId.$ext?$query';
  }

  /// `PUT /library/streams/{streamId}.{ext}?offset={ms}` — adjust
  /// a stream's offset (subtitle sync).
  Future<void> setStreamOffset({
    required String streamId,
    required String ext,
    required int offsetMs,
  }) async {
    await _http.request<void>(
      '/library/streams/$streamId.$ext',
      method: 'PUT',
      queryParameters: {'offset': offsetMs},
    );
  }

  /// `DELETE /library/streams/{streamId}.{ext}` — delete a stream.
  Future<void> deleteStream({
    required String streamId,
    required String ext,
  }) async {
    await _http.request<void>(
      '/library/streams/$streamId.$ext',
      method: 'DELETE',
    );
  }

  /// `GET /library/streams/{streamId}/loudness?subsample={n}` —
  /// loudness curve for an audio stream.
  Future<Map<String, dynamic>> streamLoudness({
    required String streamId,
    int? subsample,
  }) async {
    final qp = <String, dynamic>{};
    if (subsample != null) qp['subsample'] = subsample;
    final res = await _http.request<Map<String, dynamic>>(
      '/library/streams/$streamId/loudness',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `GET /library/streams/{streamId}/levels?subsample={n}` —
  /// level samples (used for the waveform display).
  Future<Map<String, dynamic>> streamLevels({
    required String streamId,
    int? subsample,
  }) async {
    final qp = <String, dynamic>{};
    if (subsample != null) qp['subsample'] = subsample;
    final res = await _http.request<Map<String, dynamic>>(
      '/library/streams/$streamId/levels',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  // -------------------------------------------------------------------------
  // Parts (file-level)
  // -------------------------------------------------------------------------

  /// `PUT /library/parts/{partId}?audioStreamID=...&subtitleStreamID=...&allParts={b}`
  /// — set the active audio/subtitle stream selection on a media part.
  Future<void> setPartStreamSelection({
    required String partId,
    String? audioStreamID,
    String? subtitleStreamID,
    bool? allParts,
  }) async {
    final qp = <String, dynamic>{};
    if (audioStreamID != null) qp['audioStreamID'] = audioStreamID;
    if (subtitleStreamID != null) qp['subtitleStreamID'] = subtitleStreamID;
    if (allParts != null) qp['allParts'] = allParts ? 1 : 0;
    await _http.request<void>(
      '/library/parts/$partId',
      method: 'PUT',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// `GET /library/parts/{partId}/{changestamp}/{filename}` — URL
  /// for a media part file (direct file download).
  String partFileUrl({
    required String partId,
    required int changestamp,
    required String filename,
    bool? download,
  }) {
    final base = _http.baseUrl;
    final token = _http.token ?? '';
    final qp = <String, String>{'X-Plex-Token': token};
    if (download != null) qp['download'] = download ? '1' : '0';
    final query = qp.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$base/library/parts/$partId/$changestamp/$filename?$query';
  }

  /// `GET /library/parts/{partId}/indexes/{index}` — BIF index
  /// metadata for a media part.
  Future<Map<String, dynamic>> partIndex({
    required String partId,
    required String index,
    int? interval,
  }) async {
    final qp = <String, dynamic>{};
    if (interval != null) qp['interval'] = interval;
    final res = await _http.request<Map<String, dynamic>>(
      '/library/parts/$partId/indexes/$index',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `GET /library/parts/{partId}/indexes/{index}/{offset}` — URL
  /// for a single BIF thumbnail at an offset.
  String partBifThumbUrl({
    required String partId,
    required String index,
    required int offset,
  }) {
    final base = _http.baseUrl;
    final token = _http.token ?? '';
    return '$base/library/parts/$partId/indexes/$index/$offset?X-Plex-Token=$token';
  }

  // -------------------------------------------------------------------------
  // People
  // -------------------------------------------------------------------------

  /// `GET /library/people/{personId}` — person details.
  Future<Map<String, dynamic>> person(String personId) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/people/$personId',
    );
    return res.data ?? const {};
  }

  /// `GET /library/people/{personId}/media` — items credited to
  /// a person.
  Future<List<PlexMetadata>> personMedia(String personId) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/library/people/$personId/media',
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `/library/sections/{sectionId}/computePath?startID=...&endID=...&maxDistance=...`
  /// — sonic transition path between two tracks. Used to bridge two
  /// songs with intermediate tracks for smooth crossfade compilations.
  Future<List<PlexMetadata>> sonicPath({
    required String sectionId,
    required String startId,
    required String endId,
    double? maxDistance,
  }) async {
    final qp = <String, dynamic>{
      'startID': startId,
      'endID': endId,
    };
    if (maxDistance != null) qp['maxDistance'] = maxDistance;
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/computePath',
      queryParameters: qp,
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }

  /// `/library/sections/{sectionId}/nearest` — sonically nearest
  /// tracks inside a section, seeded by a vector of music-analysis
  /// values (typically `musicAnalysis` from another track or an
  /// average across recently played).
  ///
  /// [values] is the 50-dimensional vector Plex uses for sonic
  /// proximity. [maxDistance] defaults to 0.25 on the server. [type]
  /// is the metadata type integer (10 for audio track).
  Future<List<PlexMetadata>> nearestInSection({
    required String sectionId,
    required List<num> values,
    int type = 10,
    int? limit,
    double? maxDistance,
  }) async {
    final qp = <String, dynamic>{
      'type': type,
      'values': values.join(','),
    };
    if (limit != null) qp['limit'] = limit;
    if (maxDistance != null) qp['maxDistance'] = maxDistance;
    final res = await _http.request<Map<String, dynamic>>(
      '/library/sections/$sectionId/nearest',
      queryParameters: qp,
    );
    return PlexMediaContainer.fromJson(
      res.data ?? const {},
      'Metadata',
      PlexMetadata.fromJson,
    ).items;
  }
}
