// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../parsing/plex_parsing.dart';
import '../parsing/plex_query.dart';
import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';
import '../plex_filter.dart';
import '../plex_models.dart';
import '../plex_urls.dart';
import '../plex_vocabulary.dart';

part 'plex_library_item_details.dart';
part 'plex_library_item_editing.dart';
part 'plex_library_sections_admin.dart';

/// Browse `/library/sections` and `/library/metadata/{id}`.
///
/// {@category Library}
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
  Future<List<PlexLibrarySection>> sections() => _http.requestJson(
    '/library/sections',
    itemsOf('Directory', PlexLibrarySection.fromJson),
  );

  // -------------------------------------------------------------------------
  // Items inside a section
  // -------------------------------------------------------------------------

  /// Paged list of items inside a section, filtered by [type].
  ///
  /// Pass a [PlexMetadataType]; see its members for the wire integers
  /// the server expects (the single source of truth for those values).
  ///
  /// [sort] orders the page: `PlexSort.titleSort`, `PlexSort.addedAt.desc`,
  /// `PlexSort.lastViewedAt.desc`, … (a field the section offers, see
  /// [PlexSort]).
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
    PlexSort? sort,
    List<PlexFilter> filters = const [],
  }) async {
    final qp = <String, Object?>{
      'type': type.value,
      'X-Plex-Container-Start': start,
      'X-Plex-Container-Size': size,
      'sort': ?sort,
    };
    applyFilters(qp, filters);
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/all',
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
  }) async => _tagIndex(
    path: '/library/sections/${seg(sectionId)}/genre',
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
    return _tagIndex(
      path: uri.path,
      field: filter.field,
      queryParameters: {...uri.queryParameters, 'type': ?type?.value},
    );
  }

  /// Fetch a tag index (`/library/sections/{id}/genre`, `/mood`, …) and
  /// decode its `Directory` entries as [PlexTag]s belonging to [field].
  Future<List<PlexTag>> _tagIndex({
    required String path,
    required String field,
    required Map<String, Object?> queryParameters,
  }) => _http.requestJson(
    path,
    queryParameters: queryParameters,
    itemsOf('Directory', (json) => PlexTag.fromJson(json, field: field)),
  );

  // -------------------------------------------------------------------------
  // Single item
  // -------------------------------------------------------------------------

  /// Full metadata for one item (`/library/metadata/{ratingKey}`).
  ///
  /// [includeMarkers] adds the intro, credits and commercial markers
  /// ([PlexMetadata.markers]) and [includeChapters] the chapters
  /// ([PlexMetadata.chapters]); the server leaves both out otherwise.
  Future<PlexMetadata?> item({
    required String ratingKey,
    bool includeMarkers = false,
    bool includeChapters = false,
  }) async => _http.requestJson(
    '/library/metadata/${seg(ratingKey)}',
    queryParameters: {
      if (includeMarkers) 'includeMarkers': 1,
      if (includeChapters) 'includeChapters': 1,
    },
    (json) => itemsOf('Metadata', PlexMetadata.fromJson)(json).firstOrNull,
  );

  /// Children of an item — album tracks, artist albums, season episodes
  /// (`/library/metadata/{ratingKey}/children`).
  ///
  /// [size] (with [start], default 0) reads one page; a page shorter than
  /// [size] is the last. Without it the server answers every child.
  /// [sort] takes the section sort syntax, e.g. `PlexSort.year.desc` or
  /// `PlexSort.titleSort` (verified on PMS 1.43.2). For the number of
  /// children alone use [countChildren].
  Future<List<PlexMetadata>> children({
    required String ratingKey,
    int? start,
    int? size,
    PlexSort? sort,
  }) async {
    return _http.requestJson(
      '/library/metadata/${seg(ratingKey)}/children',
      queryParameters: {
        ...containerPage(start: start, size: size),
        'sort': ?sort,
      },
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// How many children an item has (an artist's albums, an album's
  /// tracks), read from `totalSize` of an empty page — no rows travel.
  Future<int> countChildren({required String ratingKey}) async {
    final page = await _http.requestJson(
      '/library/metadata/${seg(ratingKey)}/children',
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
  }) async {
    return _http.requestJson(
      '/library/metadata/${seg(ratingKey)}/allLeaves',
      queryParameters: containerPage(start: start, size: size),
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
  }) async {
    return _http.requestJson(
      '/library/metadata/${seg(ratingKey)}/grandchildren',
      queryParameters: containerPage(start: start, size: size),
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
  }) async {
    return _http.requestJson(
      sectionId == null
          ? '/library/recentlyAdded'
          : '/library/sections/${seg(sectionId)}/recentlyAdded',
      queryParameters: containerPage(start: start, size: size),
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
    return _http.requestJson(
      '/library/metadata/${seg(ratingKey)}/similar',
      queryParameters: {'count': ?count},
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `/library/metadata/{ratingKey}/nearest` — sonically nearest
  /// tracks to a seed track (requires music sonic analysis on the
  /// server). Used to build "sonic radio".
  ///
  /// [excludeParentRatingKey] / [excludeGrandparentRatingKey] leave out the
  /// tracks of one album / artist — pass the ratingKey as you have it
  /// (e.g. `track.parentRatingKey`).
  Future<List<PlexMetadata>> nearestToTrack({
    required String ratingKey,
    int? limit,
    double? maxDistance,
    String? excludeParentRatingKey,
    String? excludeGrandparentRatingKey,
  }) async {
    return _http.requestJson(
      '/library/metadata/${seg(ratingKey)}/nearest',
      queryParameters: {
        'limit': ?limit,
        'maxDistance': ?maxDistance,
        'excludeParentID': ?excludeParentRatingKey,
        'excludeGrandparentID': ?excludeGrandparentRatingKey,
      },
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
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
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/computePath',
      queryParameters: {
        'startID': startId,
        'endID': endId,
        'maxDistance': ?maxDistance,
      },
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
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
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/nearest',
      queryParameters: {
        'type': type,
        'values': values.join(','),
        'limit': ?limit,
        'maxDistance': ?maxDistance,
      },
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
      '/library/sections/${seg(sectionId)}/filters',
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
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/albums',
      queryParameters: {
        'X-Plex-Container-Start': start,
        'X-Plex-Container-Size': size,
      },
      containerOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `/library/sections/{sectionId}/location` — folder roots
  /// configured for the section (one entry per scanned directory).
  Future<List<PlexMetadata>> folderLocations({
    required String sectionId,
  }) async {
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/location',
      itemsOf('Directory', PlexMetadata.fromJson),
    );
  }

  /// `/library/sections/{sectionId}/categories` — server-defined
  /// categories for the section (mostly used by photo libraries).
  Future<List<PlexMetadata>> categories({required String sectionId}) async {
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/categories',
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `/library/sections/{sectionId}/allLeaves` — every leaf-level
  /// item in a section (e.g. every episode of every show).
  Future<List<PlexMetadata>> sectionAllLeaves({
    required String sectionId,
  }) async {
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/allLeaves',
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `/library/sections/{sectionId}/arts` — backdrop artwork
  /// (Directory entries with `art` paths).
  Future<List<PlexMetadata>> sectionArts({required String sectionId}) async {
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/arts',
      itemsOf('Directory', PlexMetadata.fromJson),
    );
  }

  /// `/library/sections/{sectionId}/cluster` — clusters used to
  /// group photo libraries (proximity / similarity buckets).
  Future<List<PlexMetadata>> sectionClusters({
    required String sectionId,
  }) async {
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/cluster',
      itemsOf('Directory', PlexMetadata.fromJson),
    );
  }

  /// `/library/sections/{sectionId}/moment` — moments index for a
  /// photo library (notable moments grouped by date/place).
  Future<List<PlexMetadata>> sectionMoments({required String sectionId}) async {
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/moment',
      itemsOf('Directory', PlexMetadata.fromJson),
    );
  }

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

  // -------------------------------------------------------------------------
  // Library-wide reads / housekeeping
  // -------------------------------------------------------------------------

  /// `GET /library/all` — every item across every section. Heavy
  /// query; use sections / `allByType` for normal browsing.
  Future<List<PlexMetadata>> all() => _http.requestJson(
    '/library/all',
    itemsOf('Metadata', PlexMetadata.fromJson),
  );

  /// `GET /library/sections/all` — every section's metadata (Media
  /// Provider Only view). Lighter than [sections]; useful for the
  /// "primary library" entry point.
  Future<List<PlexLibrarySection>> sectionsAll() => _http.requestJson(
    '/library/sections/all',
    itemsOf('Directory', PlexLibrarySection.fromJson),
  );

  /// `GET /library/sections/{sectionId}/folder` — the section's folders
  /// and the items directly in them, as on disk (the API document's
  /// `getSectionFolder`).
  ///
  /// Without [parent] it lists the root. A folder entry's
  /// [PlexMetadata.key] is `/library/sections/{id}/folder?parent=…`:
  /// pass that `parent` value (not a rating key) to open it. Pages with
  /// [size] (and [start], default 0).
  Future<PlexMediaContainer<PlexMetadata>> folder({
    required String sectionId,
    String? parent,
    int? start,
    int? size,
  }) async {
    return _http.requestJson(
      '/library/sections/${seg(sectionId)}/folder',
      queryParameters: {
        ...containerPage(start: start, size: size),
        'parent': ?parent,
      },
      containerOf('Metadata', PlexMetadata.fromJson),
    );
  }

  /// `GET /library/tags` — every tag of the items of [type] across the
  /// library (genres, moods, …), each ready for [PlexFilter.of] (verified
  /// on PMS 1.43.2: entries carry `filter: genre=5`; without a type the
  /// server answers 400).
  Future<List<PlexTag>> tags({required PlexMetadataType type}) =>
      _http.requestJson(
        '/library/tags',
        queryParameters: {'type': type.value},
        itemsOf('Directory', PlexTag.fromJson),
      );

  /// `GET /library/randomArtwork?sections={ids}` — random backdrop
  /// across the supplied sections. Useful as a screensaver source.
  Future<Map<String, Object?>> randomArtwork({String? sections}) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/randomArtwork',
      queryParameters: {'sections': ?sections},
    );
    return res.data ?? const {};
  }

  /// `GET /library/matches` — the metadata the agents match for a
  /// description: [filters] holds the route's parameters (`type`,
  /// `title`, `year`, `guid`, `path`, …).
  Future<List<PlexMetadata>> matches(Map<String, Object?> filters) =>
      _http.requestJson(
        '/library/matches',
        queryParameters: filters,
        itemsOf('Metadata', PlexMetadata.fromJson),
      );

  /// `POST /library/file?url={path}&virtualFilePath={...}` — ingest
  /// a file from disk without first scanning it via a section.
  Future<Map<String, Object?>> ingestTransientItem({
    required String url,
    String? virtualFilePath,
    bool? computeHashes,
    bool? ingestNonMatches,
  }) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/file',
      method: 'POST',
      queryParameters: {
        'url': url,
        'virtualFilePath': ?virtualFilePath,
        'computeHashes': ?_flag(computeHashes),
        'ingestNonMatches': ?_flag(ingestNonMatches),
      },
    );
    return res.data ?? const {};
  }

  /// `GET /library/sections/prefs?type={t}&agent={a}` — default
  /// section preferences for a media type + agent combination.
  Future<Map<String, Object?>> defaultSectionPrefs({
    String? type,
    String? agent,
  }) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/sections/prefs',
      queryParameters: {'type': ?type, 'agent': ?agent},
    );
    return res.data ?? const {};
  }
}

/// A flag as Plex reads it in a query: `1` or `0`, `null` when unset.
int? _flag(bool? value) => value == null ? null : (value ? 1 : 0);
