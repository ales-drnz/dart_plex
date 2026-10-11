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
    required String type,
    required int startTimeOffset,
    required int endTimeOffset,
    Map<String, Object?>? attributes,
  }) async {
    final qp = <String, Object?>{
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
    Map<String, Object?>? attributes,
  }) async {
    final qp = <String, Object?>{};
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
    final qp = <String, Object?>{};
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
  Future<Map<String, Object?>> streamLoudness({
    required String streamId,
    int? subsample,
  }) async {
    final qp = <String, Object?>{};
    if (subsample != null) qp['subsample'] = subsample;
    final res = await _http.request<Map<String, Object?>>(
      '/library/streams/$streamId/loudness',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return res.data ?? const {};
  }

  /// `GET /library/streams/{streamId}/levels?subsample={n}` —
  /// level samples (used for the waveform display).
  Future<Map<String, Object?>> streamLevels({
    required String streamId,
    int? subsample,
  }) async {
    final qp = <String, Object?>{};
    if (subsample != null) qp['subsample'] = subsample;
    final res = await _http.request<Map<String, Object?>>(
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
    final qp = <String, Object?>{};
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
  Future<Map<String, Object?>> partIndex({
    required String partId,
    required String index,
    int? interval,
  }) async {
    final qp = <String, Object?>{};
    if (interval != null) qp['interval'] = interval;
    final res = await _http.request<Map<String, Object?>>(
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
  Future<Map<String, Object?>> person({required String personId}) async {
    final res = await _http.request<Map<String, Object?>>(
      '/library/people/$personId',
    );
    return res.data ?? const {};
  }

  /// `GET /library/people/{personId}/media` — items credited to
  /// a person.
  Future<List<PlexMetadata>> personMedia({required String personId}) async {
    return _http.requestJson(
      '/library/people/$personId/media',
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
    final qp = <String, Object?>{
      'startID': startId,
      'endID': endId,
    };
    if (maxDistance != null) qp['maxDistance'] = maxDistance;
    return _http.requestJson(
      '/library/sections/$sectionId/computePath',
      queryParameters: qp,
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
    final qp = <String, Object?>{
      'type': type,
      'values': values.join(','),
    };
    if (limit != null) qp['limit'] = limit;
    if (maxDistance != null) qp['maxDistance'] = maxDistance;
    return _http.requestJson(
      '/library/sections/$sectionId/nearest',
      queryParameters: qp,
      itemsOf('Metadata', PlexMetadata.fromJson),
    );
  }
}
