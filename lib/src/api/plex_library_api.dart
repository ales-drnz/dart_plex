// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';
import '../plex_filter.dart';
import '../plex_models.dart';
import '../plex_parsing.dart';
import '../plex_query.dart';

part 'plex_library_item_details.dart';
part 'plex_library_item_editing.dart';
part 'plex_library_sections_admin.dart';

/// Browse `/library/sections` and `/library/metadata/{id}`.
class PlexLibraryApi
    with _PlexSectionAdmin, _PlexItemEditing, _PlexItemDetails {
  @override
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
    final res = await _http.request<Map<String, Object?>>('/library/sections');
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
  /// [filters] narrows the result set. Each [PlexFilter] travels as its
  /// own query parameter — `[PlexFilter.genre(6), PlexFilter.yearAfter(2009)]`
  /// sends `?genre=6&year>>=2009` — and the server ANDs them. To match
  /// any of several values of one field, put them in a single filter
  /// (see [PlexFilter.tag]).
  ///
  /// Throws a [PlexException] of type [PlexErrorType.state] when two
  /// filters collide on the same query parameter, since only one of the
  /// two could survive into the request.
  Future<PlexMediaContainer<PlexMetadata>> allByType({
    required String sectionId,
    required PlexMetadataType type,
    int start = 0,
    int size = 50,
    String? sort,
    List<PlexFilter> filters = const [],
  }) async {
    final qp = <String, Object?>{
      'type': type.value,
      'X-Plex-Container-Start': start,
      'X-Plex-Container-Size': size,
    };
    if (sort != null) qp['sort'] = sort;
    applyFilters(qp, filters);
    return _http.requestJson(
      '/library/sections/$sectionId/all',
      queryParameters: qp,
      containerOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// Count-only variant of [allByType] — returns the section's
  /// `totalSize` without paying the cost of streaming the items down.
  ///
  /// Runs the very same request as [allByType] with
  /// `X-Plex-Container-Size=0`, which Plex honours, so a count can never
  /// disagree with the page it counts. [filters] means exactly what it
  /// means there.
  Future<int> countByType({
    required String sectionId,
    required PlexMetadataType type,
    List<PlexFilter> filters = const [],
  }) async {
    final page = await allByType(
      sectionId: sectionId,
      type: type,
      size: 0,
      filters: filters,
    );
    return page.totalSize;
  }

  /// `PUT /library/sections/{sectionId}/all` — bulk-edit the fields
  /// and tags of every item matching a filter, in a single call
  /// (cheaper than N per-item [editItem] calls for batch tagging or
  /// curation).
  ///
  /// All mutations travel as query parameters (the endpoint has no
  /// request body). [type] is the item type integer.
  ///
  /// [filterExpression] selects the items to mutate and is sent under
  /// the PUT route's own `filters` parameter, which takes one whole
  /// expression as a string (e.g. `'genre=6'`). It is a different
  /// mechanism from the per-parameter [PlexFilter] list that
  /// [allByType] takes — the read and write routes genuinely disagree
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
    final qp = <String, Object?>{};
    if (type != null) qp['type'] = type;
    if (filterExpression != null) qp['filters'] = filterExpression;
    qp.addAll(changes);
    await _http.request<void>(
      '/library/sections/$sectionId/all',
      method: 'PUT',
      queryParameters: qp,
    );
  }

  /// Browse the genres index of a section (`/library/sections/{id}/genre`).
  ///
  /// Each [PlexTag] carries the numeric [PlexTag.id] the server filters
  /// by, so a genre can go straight back into a query:
  ///
  /// ```dart
  /// final rock = genres.firstWhere((g) => g.title == 'Rock');
  /// final albums = await plex.library.allByType(
  ///   sectionId: sectionId,
  ///   type: PlexMetadataType.album,
  ///   filters: [PlexFilter.of(rock)],
  /// );
  /// ```
  Future<List<PlexTag>> genres({
    required String sectionId,
    required PlexMetadataType type,
  }) =>
      _tagIndex(
        path: '/library/sections/$sectionId/genre',
        field: 'genre',
        queryParameters: {'type': type.value},
      );

  /// Values a facet can take — the moods, styles, decades or labels
  /// behind a [PlexLibraryFilter] returned by [filters].
  ///
  /// Follows [PlexLibraryFilter.valuesKey], the endpoint the server
  /// itself nominates for the facet's values, so no path is spelled by
  /// hand. Narrow to one item kind with [type].
  ///
  /// Throws a [PlexException] of type [PlexErrorType.state] when the
  /// facet has no values endpoint (`unwatched` and friends have none —
  /// they are flags, not lists).
  Future<List<PlexTag>> filterValues({
    required PlexLibraryFilter filter,
    PlexMetadataType? type,
  }) async {
    final key = filter.valuesKey;
    if (key == null) {
      throw PlexException(
        'Filter "${filter.field}" lists no values endpoint; there is '
        'nothing to enumerate for it.',
        type: PlexErrorType.state,
      );
    }
    final uri = Uri.parse(key);
    final qp = <String, Object?>{...uri.queryParameters};
    if (type != null) qp['type'] = type.value;
    return _tagIndex(
      path: uri.path,
      field: filter.field,
      queryParameters: qp,
    );
  }

  /// Fetch a tag index (`/library/sections/{id}/genre`, `/mood`, …) and
  /// decode its `Directory` entries as [PlexTag]s belonging to [field].
  Future<List<PlexTag>> _tagIndex({
    required String path,
    required String field,
    required Map<String, Object?> queryParameters,
  }) async {
    return _http.requestJson(
      path,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
      itemsOf('Directory', (json) => PlexTag.fromJson(json, field: field)),
    );
  }

  // -------------------------------------------------------------------------
  // Single item
  // -------------------------------------------------------------------------

  /// Full metadata for one item (`/library/metadata/{ratingKey}`).
  Future<PlexMetadata?> item({required String ratingKey}) async {
    final res = await _http.request<Map<String, Object?>>(
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
    required Map<String, Object?> args,
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
    final qp = <String, Object?>{};
    if (proxy != null) qp['proxy'] = proxy ? 1 : 0;
    await _http.request<void>(
      '/library/metadata/$ids',
      method: 'DELETE',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// Children of an item — album tracks, artist albums, season episodes
  /// (`/library/metadata/{ratingKey}/children`).
  ///
  /// [size] (with [start], default 0) reads one page; a page shorter than
  /// [size] is the last. Without it the server answers every child.
  /// [sort] takes the section sort syntax, e.g. `'year:desc'` or
  /// `'titleSort'` (verified on PMS 1.43.2). For the number of children
  /// alone use [countChildren].
  Future<List<PlexMetadata>> children({
    required String ratingKey,
    int? start,
    int? size,
    String? sort,
  }) {
    final qp = containerPage(start: start, size: size);
    if (sort != null) qp['sort'] = sort;
    return _http.requestJson(
      '/library/metadata/$ratingKey/children',
      queryParameters: qp.isEmpty ? null : qp,
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// How many children an item has (an artist's albums, an album's
  /// tracks), read from `totalSize` of an empty page — no rows travel.
  Future<int> countChildren({required String ratingKey}) async {
    final page = await _http.requestJson(
      '/library/metadata/$ratingKey/children',
      queryParameters: containerPage(start: 0, size: 0),
      containerOf('Metadata', PlexMetadata.fromJson),
    );
    return page.totalSize;
  }

  /// All leaves under an item — every track under an artist, every
  /// episode under a show. Useful for "play artist" / "play show".
  ///
  /// [size] (with [start], default 0) reads one page. There is no `sort`:
  /// PMS 1.43.2 ignores it on this endpoint (verified) and answers in
  /// library order.
  Future<List<PlexMetadata>> allLeaves({
    required String ratingKey,
    int? start,
    int? size,
  }) {
    final qp = containerPage(start: start, size: size);
    return _http.requestJson(
      '/library/metadata/$ratingKey/allLeaves',
      queryParameters: qp.isEmpty ? null : qp,
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// Grandchildren of an item (`/library/metadata/{ratingKey}/grandchildren`)
  /// — every track of an artist, in album order, without a request per
  /// album. Pages with [size] (and [start], default 0); verified on PMS
  /// 1.43.2.
  Future<List<PlexMetadata>> grandchildren({
    required String ratingKey,
    int? start,
    int? size,
  }) {
    final qp = containerPage(start: start, size: size);
    return _http.requestJson(
      '/library/metadata/$ratingKey/grandchildren',
      queryParameters: qp.isEmpty ? null : qp,
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// Recently added items, newest first — of one section when [sectionId]
  /// is given (`/library/sections/{id}/recentlyAdded`), else of every
  /// section (`/library/recentlyAdded`).
  ///
  /// In a music section the server answers *albums* (verified on PMS
  /// 1.43.2, which ignores a `type` asking for tracks), so there is no
  /// type parameter. Pages with [size] (and [start], default 0).
  Future<List<PlexMetadata>> recentlyAdded({
    String? sectionId,
    int? start,
    int? size,
  }) {
    final qp = containerPage(start: start, size: size);
    return _http.requestJson(
      sectionId == null
          ? '/library/recentlyAdded'
          : '/library/sections/$sectionId/recentlyAdded',
      queryParameters: qp.isEmpty ? null : qp,
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
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
    final qp = <String, Object?>{};
    if (count != null) qp['count'] = count;
    return _http.requestJson(
      '/library/metadata/$ratingKey/similar',
      queryParameters: qp.isEmpty ? null : qp,
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `/library/metadata/{ratingKey}/nearest` — sonically nearest
  /// tracks to a seed track (requires music sonic analysis on the
  /// server). Used to build "sonic radio".
  ///
  /// [excludeParentRatingKey] / [excludeGrandparentRatingKey] leave out the
  /// tracks of one album / artist — pass the ratingKey as you have it
  /// (e.g. `track.parentRatingKey`). The `int` forms are deprecated.
  Future<List<PlexMetadata>> nearestToTrack({
    required String ratingKey,
    int? limit,
    double? maxDistance,
    String? excludeParentRatingKey,
    String? excludeGrandparentRatingKey,
    @Deprecated('Use excludeParentRatingKey') int? excludeParentID,
    @Deprecated('Use excludeGrandparentRatingKey') int? excludeGrandparentID,
  }) {
    if (excludeParentRatingKey != null && excludeParentID != null) {
      throw ArgumentError(
        'Pass excludeParentRatingKey or excludeParentID, not both.',
      );
    }
    if (excludeGrandparentRatingKey != null && excludeGrandparentID != null) {
      throw ArgumentError(
        'Pass excludeGrandparentRatingKey or excludeGrandparentID, not both.',
      );
    }
    final parent = excludeParentRatingKey ?? excludeParentID?.toString();
    final grandparent =
        excludeGrandparentRatingKey ?? excludeGrandparentID?.toString();
    final qp = <String, Object?>{};
    if (limit != null) qp['limit'] = limit;
    if (maxDistance != null) qp['maxDistance'] = maxDistance;
    if (parent != null) qp['excludeParentID'] = parent;
    if (grandparent != null) qp['excludeGrandparentID'] = grandparent;
    return _http.requestJson(
      '/library/metadata/$ratingKey/nearest',
      queryParameters: qp.isEmpty ? null : qp,
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  // -------------------------------------------------------------------------
  // Section facets and sub-buckets
  // -------------------------------------------------------------------------

  /// `/library/sections/{sectionId}/filters` — the facets this section
  /// can be filtered on (genre, year, decade, …).
  ///
  /// This is the authoritative list of filterable fields for a section:
  /// [PlexLibraryFilter.field] is the query parameter to use, and
  /// [filterValues] enumerates what it accepts. The raw entry also
  /// carries a `Pivot` array of pre-built sub-views, e.g.
  /// "firstCharacter" for an A-Z index or "folder" for the file-tree
  /// view.
  Future<List<PlexLibraryFilter>> filters({required String sectionId}) async {
    return _http.requestJson(
      '/library/sections/$sectionId/filters',
      itemsOf('Directory', PlexLibraryFilter.fromJson),
    );
  }

  /// `/library/sections/{sectionId}/albums` — every album in a music
  /// section. Cheaper than `allByType(type: album)` when no sort or
  /// filter is needed.
  Future<PlexMediaContainer<PlexMetadata>> albums({
    required String sectionId,
    int start = 0,
    int size = 50,
  }) async {
    final qp = <String, Object?>{
      'X-Plex-Container-Start': start,
      'X-Plex-Container-Size': size,
    };
    return _http.requestJson(
      '/library/sections/$sectionId/albums',
      queryParameters: qp,
      containerOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `/library/sections/{sectionId}/location` — folder roots
  /// configured for the section (one entry per scanned directory).
  Future<List<PlexMetadata>> folderLocations({
    required String sectionId,
  }) async {
    return _http.requestJson(
      '/library/sections/$sectionId/location',
      itemsOf('Directory', PlexMetadata.fromJson),
    );
  }

  /// `/library/sections/{sectionId}/categories` — server-defined
  /// categories for the section (mostly used by photo libraries).
  Future<List<PlexMetadata>> categories({required String sectionId}) async {
    return _http.requestJson(
      '/library/sections/$sectionId/categories',
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `/library/sections/{sectionId}/allLeaves` — every leaf-level
  /// item in a section (e.g. every episode of every show).
  Future<List<PlexMetadata>> sectionAllLeaves({
    required String sectionId,
  }) async {
    return _http.requestJson(
      '/library/sections/$sectionId/allLeaves',
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `/library/sections/{sectionId}/arts` — backdrop artwork
  /// (Directory entries with `art` paths).
  Future<List<PlexMetadata>> sectionArts({required String sectionId}) async {
    return _http.requestJson(
      '/library/sections/$sectionId/arts',
      itemsOf('Directory', PlexMetadata.fromJson),
    );
  }

  /// `/library/sections/{sectionId}/cluster` — clusters used to
  /// group photo libraries (proximity / similarity buckets).
  Future<List<PlexMetadata>> sectionClusters({
    required String sectionId,
  }) async {
    return _http.requestJson(
      '/library/sections/$sectionId/cluster',
      itemsOf('Directory', PlexMetadata.fromJson),
    );
  }

  /// `/library/sections/{sectionId}/moment` — moments index for a
  /// photo library (notable moments grouped by date/place).
  Future<List<PlexMetadata>> sectionMoments({required String sectionId}) async {
    return _http.requestJson(
      '/library/sections/$sectionId/moment',
      itemsOf('Directory', PlexMetadata.fromJson),
    );
  }

  // -------------------------------------------------------------------------
  // Library-wide reads / housekeeping
  // -------------------------------------------------------------------------

  /// `GET /library/all` — every item across every section. Heavy
  /// query; use sections / `allByType` for normal browsing.
  Future<List<PlexMetadata>> all() async {
    return _http.requestJson(
      '/library/all',
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `GET /library/sections/all` — every section's metadata (Media
  /// Provider Only view). Lighter than [sections]; useful for the
  /// "primary library" entry point.
  Future<List<PlexLibrarySection>> sectionsAll() async {
    final res =
        await _http.request<Map<String, Object?>>('/library/sections/all');
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
    Map<String, Object?>? prefs,
    bool? relative,
    bool? importFromiTunes,
  }) async {
    final qp = <String, Object?>{
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
  Future<Map<String, Object?>> tags() async {
    final res = await _http.request<Map<String, Object?>>('/library/tags');
    return res.data ?? const {};
  }

  /// `GET /library/randomArtwork?sections={ids}` — random backdrop
  /// across the supplied sections. Useful as a screensaver source.
  Future<Map<String, Object?>> randomArtwork({String? sections}) async {
    final qp = <String, Object?>{};
    if (sections != null) qp['sections'] = sections;
    final res = await _http.request<Map<String, Object?>>(
      '/library/randomArtwork',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `GET /library/matches` — query the metadata-agent match cache.
  Future<Map<String, Object?>> matches(Map<String, Object?> filters) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/matches',
      queryParameters: filters,
    );
    return res.data ?? const {};
  }

  /// `POST /library/file?url={path}&virtualFilePath={...}` — ingest
  /// a file from disk without first scanning it via a section.
  Future<Map<String, Object?>> ingestTransientItem({
    required String url,
    String? virtualFilePath,
    bool? computeHashes,
    bool? ingestNonMatches,
  }) async {
    final qp = <String, Object?>{'url': url};
    if (virtualFilePath != null) qp['virtualFilePath'] = virtualFilePath;
    if (computeHashes != null) qp['computeHashes'] = computeHashes ? 1 : 0;
    if (ingestNonMatches != null) {
      qp['ingestNonMatches'] = ingestNonMatches ? 1 : 0;
    }
    final res = await _http.request<Map<String, Object?>>(
      '/library/file',
      method: 'POST',
      queryParameters: qp,
    );
    return res.data ?? const {};
  }

  /// `GET /library/sections/prefs?type={t}&agent={a}` — default
  /// section preferences for a media type + agent combination.
  Future<Map<String, Object?>> defaultSectionPrefs({
    String? type,
    String? agent,
  }) async {
    final qp = <String, Object?>{};
    if (type != null) qp['type'] = type;
    if (agent != null) qp['agent'] = agent;
    final res = await _http.request<Map<String, Object?>>(
      '/library/sections/prefs',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }
}
