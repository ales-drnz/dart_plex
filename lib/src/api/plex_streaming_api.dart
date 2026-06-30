// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:dio/dio.dart' show ResponseType;

import '../plex_connection.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';

/// Audio (and video) streaming URL builders.
///
/// These methods don't make HTTP calls — they assemble fully signed URLs
/// you can hand to an audio engine (mpv, AVPlayer, ExoPlayer, …). The
/// X-Plex-Token is appended as a query parameter so transcode children
/// (segment requests) don't need custom headers.
class PlexStreamingApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.streaming].
  PlexStreamingApi(this._http);

  /// Build a `/music/:/transcode/universal/start.{ext}` URL.
  ///
  /// - [protocol] is `'hls'` (default — segments wrapped in MPEG-TS) or
  ///   `'dash'` or `'http'` (single-stream).
  /// - [container] is the *target* container; for `hls` use `mpegts`,
  ///   for direct mp3 use `mp3`.
  /// - [maxAudioBitrate] in kbps. Pass `null` to let the server pick.
  /// - [audioCodec] — usually `'aac'` (HLS) or `'mp3'`. Multiple values
  ///   can be passed as `'aac,mp3'`.
  /// - [session] is a stable UUID the caller picks — Plex uses it to
  ///   correlate ping / stop calls.
  String universalAudioUrl({
    required String ratingKey,
    String protocol = 'hls',
    String container = 'mpegts',
    String audioCodec = 'aac',
    int? maxAudioBitrate,
    int audioChannels = 2,
    int offsetSeconds = 0,
    String? session,
    bool directPlay = false,
    bool directStream = true,
  }) {
    _requireConnected();
    final base = _http.baseUrl!;
    final token = _http.token ?? '';
    final qp = <String, String>{
      'path': '/library/metadata/$ratingKey',
      'mediaIndex': '0',
      'partIndex': '0',
      'protocol': protocol,
      'audioCodec': audioCodec,
      'audioChannels': '$audioChannels',
      'directPlay': directPlay ? '1' : '0',
      'directStream': directStream ? '1' : '0',
      'fastSeek': '1',
      'offset': '$offsetSeconds',
      'X-Plex-Token': token,
    };
    if (container.isNotEmpty) qp['container'] = container;
    if (maxAudioBitrate != null) {
      qp['maxAudioBitrate'] = '$maxAudioBitrate';
    }
    if (session != null) qp['session'] = session;
    final ext = switch (protocol) {
      'hls' => 'm3u8',
      'dash' => 'mpd',
      _ => container.isNotEmpty ? container : 'mp3',
    };
    return '$base/music/:/transcode/universal/start.$ext?${_encode(qp)}';
  }

  /// Build the direct-file download URL — best quality, no transcode.
  ///
  /// [partKey] is the metadata-supplied `Part.key`, which already carries
  /// the partId, the required `{changestamp}` cache-busting segment, and
  /// the real filename — e.g. `/library/parts/872/1348327790/file.mkv`.
  /// The spec download endpoint (`getMediaPart`) is
  /// `/library/parts/{partId}/{changestamp}/{filename}`, so the key is
  /// used verbatim rather than reconstructing those segments.
  ///
  /// Returns `(url, ext)` where `ext` is derived from the filename in
  /// [partKey] (the substring after the last `.`, empty if none).
  (String url, String extension) directFileUrl({
    required String partKey,
    bool download = true,
  }) {
    _requireConnected();
    final base = _http.baseUrl!;
    final token = _http.token ?? '';
    final dot = partKey.lastIndexOf('.');
    final slash = partKey.lastIndexOf('/');
    final ext = dot > slash ? partKey.substring(dot + 1) : '';
    final query = <String, String>{
      'X-Plex-Token': token,
      if (download) 'download': '1',
    };
    final url = '$base$partKey?${_encode(query)}';
    return (url, ext);
  }

  /// Build a `/video/:/transcode/universal/start.{ext}` URL.
  ///
  /// Pre-flight with [decisionUniversal] for proper direct-play /
  /// direct-stream / transcode negotiation; the URL itself does not
  /// drive that decision, it follows whatever the server already
  /// decided (or its defaults).
  ///
  /// - [protocol]: `'hls'` (MPEG-TS segments), `'dash'` (fMP4
  ///   segments), or `'http'` (single MP4 / MKV).
  /// - [container]: the *target* container the server should produce
  ///   (`'mpegts'` for HLS, `'mp4'` for DASH/HTTP).
  /// - [videoBitrate] / [audioBitrate] in kbps. Pass `null` to let
  ///   the server pick.
  /// - [videoResolution]: e.g. `'1920x1080'`, `'1280x720'`.
  String universalVideoUrl({
    required String ratingKey,
    String protocol = 'hls',
    String container = 'mpegts',
    String? videoResolution,
    int? videoBitrate,
    int? audioBitrate,
    String? videoCodec,
    String? audioCodec,
    int? subtitleSize,
    int offsetSeconds = 0,
    String? session,
    bool directPlay = false,
    bool directStream = true,
    int audioBoost = 100,
    bool fastSeek = true,
  }) {
    _requireConnected();
    final base = _http.baseUrl!;
    final token = _http.token ?? '';
    final qp = <String, String>{
      'path': '/library/metadata/$ratingKey',
      'mediaIndex': '0',
      'partIndex': '0',
      'protocol': protocol,
      'directPlay': directPlay ? '1' : '0',
      'directStream': directStream ? '1' : '0',
      'fastSeek': fastSeek ? '1' : '0',
      'offset': '$offsetSeconds',
      'audioBoost': '$audioBoost',
      'X-Plex-Token': token,
    };
    if (container.isNotEmpty) qp['container'] = container;
    if (videoResolution != null) qp['videoResolution'] = videoResolution;
    if (videoBitrate != null) qp['maxVideoBitrate'] = '$videoBitrate';
    if (audioBitrate != null) qp['maxAudioBitrate'] = '$audioBitrate';
    if (videoCodec != null) qp['videoCodec'] = videoCodec;
    if (audioCodec != null) qp['audioCodec'] = audioCodec;
    if (subtitleSize != null) qp['subtitleSize'] = '$subtitleSize';
    if (session != null) qp['session'] = session;
    final ext = switch (protocol) {
      'hls' => 'm3u8',
      'dash' => 'mpd',
      _ => container.isNotEmpty ? container : 'mp4',
    };
    return '$base/video/:/transcode/universal/start.$ext?${_encode(qp)}';
  }

  /// Call `/{transcodeType}/:/transcode/universal/decision`.
  ///
  /// Plex inspects the supplied media + client capabilities and decides
  /// whether to direct-play (no transcoding), direct-stream (re-mux
  /// only), or full transcode (re-encode). The same endpoint serves
  /// audio, video, and photo — set [transcodeType] (`'video'` by
  /// default, or `'audio'` / `'photo'`) and pass the relevant
  /// `audioCodec`/`videoCodec` hints in [params].
  ///
  /// Returns a [PlexTranscodeDecision]:
  ///   - `generalDecisionCode` in [1000, 2000) means playback can
  ///     succeed (direct-play, direct-stream, or transcode)
  ///   - 2xxx is a general error (e.g. insufficient bandwidth), 3xxx a
  ///     direct-play error, 4xxx a transcode error — all unplayable
  /// Whether the playable decision is direct or a transcode is read from
  /// the sibling `directPlayDecisionCode` / `transcodeDecisionCode`
  /// fields, not from `generalDecisionCode`.
  ///
  /// [extraHeaders] is how you pass `X-Plex-Client-Profile-Extra`
  /// (a per-call override of the global profile declared in
  /// [PlexCredentials.clientProfileExtra]).
  Future<PlexTranscodeDecision> decisionUniversal({
    required Map<String, dynamic> params,
    String transcodeType = 'video',
    Map<String, String>? extraHeaders,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/$transcodeType/:/transcode/universal/decision',
      queryParameters: params,
      extraHeaders: extraHeaders,
    );
    final container = res.data?['MediaContainer'];
    if (container is! Map<String, dynamic>) {
      return const PlexTranscodeDecision(code: null, raw: {});
    }
    final codeRaw = container['generalDecisionCode'];
    final codeInt = codeRaw is int
        ? codeRaw
        : (codeRaw is String ? int.tryParse(codeRaw) : null);
    return PlexTranscodeDecision(code: codeInt, raw: container);
  }

  /// Tell the server a transcode session can be stopped.
  Future<void> stopUniversal(String session) async {
    await _http.request<void>(
      '/video/:/transcode/universal/stop',
      queryParameters: {'session': session},
    );
  }

  /// Keep a transcode session alive while the player buffers.
  Future<void> pingUniversal(String session) async {
    await _http.request<void>(
      '/video/:/transcode/universal/ping',
      queryParameters: {'session': session},
    );
  }

  /// Fetch synced lyrics or plain text. Plex stores the lyrics as a
  /// stream of type 4 under the track's metadata; `streamKey` is the
  /// stream's `key` field (e.g. `/library/streams/12345`).
  ///
  /// Returns null if the stream key is empty or the server has no
  /// lyrics for the item. Throws [PlexException] for transport errors.
  Future<String?> lyrics({required String streamKey}) async {
    if (streamKey.isEmpty) return null;
    final res = await _http.request<List<int>>(
      streamKey,
      responseType: ResponseType.bytes,
      extraHeaders: const {'Accept': '*/*'},
    );
    final data = res.data;
    if (data == null || data.isEmpty) return null;
    return String.fromCharCodes(data);
  }

  void _requireConnected() {
    if (_http.baseUrl == null) {
      throw const PlexException(
        'No PMS connection — call PlexClient.connect() first.',
        type: PlexErrorType.state,
      );
    }
  }

  String _encode(Map<String, String> qp) => qp.entries
      .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
}

/// Outcome of [PlexStreamingApi.decisionUniversal].
///
/// Plex returns `generalDecisionCode` inside `MediaContainer`. Per the
/// spec it is the *overall* decision and follows the convention
/// "1xxx = playback can succeed, 2xxx = a general error (such as
/// insufficient bandwidth), 3xxx = errors in direct play, 4xxx = errors
/// in transcodes" — so a successful transcode lives in the 1xxx range,
/// not 2xxx. The 1xxx code alone does not say *how* playback succeeds;
/// that is read from the sibling `directPlayDecisionCode` /
/// `transcodeDecisionCode` fields (same 1xxx-means-success convention),
/// which [PlexStreamingApi.decisionUniversal] preserves in [raw].
class PlexTranscodeDecision {
  /// The numeric `generalDecisionCode` from the response. Null when
  /// the response shape was unexpected.
  final int? code;

  /// The raw `MediaContainer` for fields not promoted here.
  final Map<String, dynamic> raw;

  /// Wraps a transcode decision response with its numeric [code] and [raw] container.
  const PlexTranscodeDecision({required this.code, required this.raw});

  /// `true` when the decision call returned a success code (1xxx).
  /// `false` (and so unplayable) for 2xxx/3xxx/4xxx error bands.
  bool get isPlayable => code != null && code! >= 1000 && code! < 2000;

  /// `true` when Plex agreed to direct-play / direct-stream, i.e.
  /// playback succeeds and `directPlayDecisionCode` is in the 1xxx band.
  bool get isDirect {
    if (!isPlayable) return false;
    final dp = _subCode('directPlayDecisionCode');
    return dp != null && dp >= 1000 && dp < 2000;
  }

  /// `true` when Plex requires a transcoded session, i.e. playback
  /// succeeds, `transcodeDecisionCode` is in the 1xxx band, and it is
  /// not a direct-play decision.
  bool get isTranscode {
    if (!isPlayable || isDirect) return false;
    final tc = _subCode('transcodeDecisionCode');
    return tc != null && tc >= 1000 && tc < 2000;
  }

  int? _subCode(String key) {
    final raw = this.raw[key];
    return raw is int ? raw : (raw is String ? int.tryParse(raw) : null);
  }
}
