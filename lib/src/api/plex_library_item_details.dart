// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of 'plex_library_api.dart';

/// Markers, streams, parts and people of single items. Mixed into [PlexLibraryApi].
mixin _PlexItemDetails {
  PlexConnection get _http;

  // -------------------------------------------------------------------------
  // Markers (chapter / intro / credits)
  // -------------------------------------------------------------------------

  /// `POST /library/metadata/{ids}/marker?type=...&startTimeOffset=...&endTimeOffset=...`
  /// — create a marker.
  Future<void> createMarker({
    required String ids,
    required PlexMarkerType type,
    required int startTimeOffset,
    required int endTimeOffset,
    Map<String, Object?>? attributes,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/marker',
      method: 'POST',
      queryParameters: {
        'type': type,
        'startTimeOffset': startTimeOffset,
        'endTimeOffset': endTimeOffset,
        ...?attributes,
      },
    );
  }

  /// `PUT /library/metadata/{ids}/marker/{marker}` — edit a marker.
  Future<void> editMarker({
    required String ids,
    required String marker,
    PlexMarkerType? type,
    int? startTimeOffset,
    int? endTimeOffset,
    Map<String, Object?>? attributes,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/marker/${seg(marker)}',
      method: 'PUT',
      queryParameters: {
        'type': ?type,
        'startTimeOffset': ?startTimeOffset,
        'endTimeOffset': ?endTimeOffset,
        ...?attributes,
      },
    );
  }

  /// `DELETE /library/metadata/{ids}/marker/{marker}` — delete a
  /// marker.
  Future<void> deleteMarker({
    required String ids,
    required String marker,
  }) async {
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/marker/${seg(marker)}',
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
    await _http.request<void>(
      '/library/metadata/${seg(ids)}/media/${seg(mediaItem)}',
      method: 'DELETE',
      queryParameters: {'proxy': ?_flag(proxy)},
    );
  }

  /// `GET /library/media/{mediaId}/chapterImages/{chapter}` — URL
  /// for a chapter thumbnail.
  ///
  /// Throws a `state` [PlexException] before [PlexClient.connect]. The URL
  /// carries the token: keep it out of logs.
  String chapterImageUrl({required String mediaId, required int chapter}) =>
      _http.signedUrl('/library/media/${seg(mediaId)}/chapterImages/$chapter');

  // -------------------------------------------------------------------------
  // Streams (audio / subtitle / video)
  // -------------------------------------------------------------------------

  /// `GET /library/streams/{streamId}.{ext}` — URL for a media
  /// stream file (subtitle text, etc.).
  ///
  /// Throws a `state` [PlexException] before [PlexClient.connect]. The URL
  /// carries the token: keep it out of logs.
  String streamUrl({
    required String streamId,
    required String ext,
    String? encoding,
    String? format,
    bool? autoAdjustSubtitle,
  }) => _http.signedUrl('/library/streams/${seg(streamId)}.${seg(ext)}', {
    'encoding': ?encoding,
    'format': ?format,
    'autoAdjustSubtitle': ?_flag(autoAdjustSubtitle),
  });

  /// `PUT /library/streams/{streamId}.{ext}?offset={ms}` — adjust
  /// a stream's offset (subtitle sync).
  Future<void> setStreamOffset({
    required String streamId,
    required String ext,
    required int offsetMs,
  }) async {
    await _http.request<void>(
      '/library/streams/${seg(streamId)}.${seg(ext)}',
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
      '/library/streams/${seg(streamId)}.${seg(ext)}',
      method: 'DELETE',
    );
  }

  /// `GET /library/streams/{streamId}/loudness?subsample={n}` —
  /// loudness curve for an audio stream.
  Future<Map<String, Object?>> streamLoudness({
    required String streamId,
    int? subsample,
  }) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/streams/${seg(streamId)}/loudness',
      queryParameters: {'subsample': ?subsample},
    );
    return res.data ?? const {};
  }

  /// `GET /library/streams/{streamId}/levels?subsample={n}` —
  /// level samples (used for the waveform display).
  Future<Map<String, Object?>> streamLevels({
    required String streamId,
    int? subsample,
  }) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/streams/${seg(streamId)}/levels',
      queryParameters: {'subsample': ?subsample},
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
    await _http.request<void>(
      '/library/parts/${seg(partId)}',
      method: 'PUT',
      queryParameters: {
        'audioStreamID': ?audioStreamID,
        'subtitleStreamID': ?subtitleStreamID,
        'allParts': ?_flag(allParts),
      },
    );
  }

  /// `GET /library/parts/{partId}/{changestamp}/{filename}` — URL
  /// for a media part file (direct file download).
  ///
  /// [filename] may hold subfolders: each piece between `/` is encoded on
  /// its own, and an empty piece, `.` or `..` is an [ArgumentError].
  ///
  /// Throws a `state` [PlexException] before [PlexClient.connect]. The URL
  /// carries the token: keep it out of logs.
  String partFileUrl({
    required String partId,
    required int changestamp,
    required String filename,
    bool? download,
  }) => _http.signedUrl(
    '/library/parts/${seg(partId)}/$changestamp/'
    '${filename.split('/').map(seg).join('/')}',
    {'download': ?_flag(download)},
  );

  /// `GET /library/parts/{partId}/indexes/{index}` — BIF index
  /// metadata for a media part.
  Future<Map<String, Object?>> partIndex({
    required String partId,
    required String index,
    int? interval,
  }) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/parts/${seg(partId)}/indexes/${seg(index)}',
      queryParameters: {'interval': ?interval},
    );
    return res.data ?? const {};
  }

  /// `GET /library/parts/{partId}/indexes/{index}/{offset}` — URL
  /// for a single BIF thumbnail at an offset.
  ///
  /// Throws a `state` [PlexException] before [PlexClient.connect]. The URL
  /// carries the token: keep it out of logs.
  String partBifThumbUrl({
    required String partId,
    required String index,
    required int offset,
  }) => _http.signedUrl(
    '/library/parts/${seg(partId)}/indexes/${seg(index)}/$offset',
  );

  // -------------------------------------------------------------------------
  // People
  // -------------------------------------------------------------------------

  /// `GET /library/people/{personId}` — a person, or `null` when the
  /// answer holds none.
  Future<PlexPerson?> person({required String personId}) => _http.requestJson(
    '/library/people/${seg(personId)}',
    (json) => PlexMediaContainer.fromJson(
      json is Map<String, Object?> ? json : const {},
      'Directory',
      PlexPerson.fromJson,
    ).items.firstOrNull,
  );

  /// `GET /library/people/{personId}/media` — items credited to
  /// a person.
  Future<List<PlexMetadata>> personMedia({required String personId}) async {
    return _http.requestJson(
      '/library/people/${seg(personId)}/media',
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
}
