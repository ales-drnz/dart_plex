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
  /// Returns `(url, ext)`. The extension comes from [container] when
  /// supplied, otherwise from the part's `file` query (which the caller
  /// usually already knows from a previous metadata fetch).
  (String url, String extension) directFileUrl({
    required String partId,
    String? container,
    bool download = true,
  }) {
    _requireConnected();
    final base = _http.baseUrl!;
    final token = _http.token ?? '';
    final ext = container ?? '';
    final filename = ext.isEmpty ? 'file' : 'file.$ext';
    final query = <String, String>{
      'X-Plex-Token': token,
      if (download) 'download': '1',
    };
    final url = '$base/library/parts/$partId/$filename?${_encode(query)}';
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

  /// Call `/video/:/transcode/universal/decision`.
  ///
  /// Plex inspects the supplied media + client capabilities and decides
  /// whether to direct-play (no transcoding), direct-stream (re-mux
  /// only), or full transcode (re-encode). The same endpoint serves
  /// both audio and video — pass the relevant `audioCodec`/`videoCodec`
  /// hints in [params].
  ///
  /// Returns a [PlexTranscodeDecision]:
  ///   - `code` in [1000, 2000) means direct-play / direct-stream OK
  ///   - `code` in [2000, 3000) means transcode required
  ///   - everything else means the server refused or errored out
  ///
  /// [extraHeaders] is how you pass `X-Plex-Client-Profile-Extra`
  /// (a per-call override of the global profile declared in
  /// [PlexCredentials.clientProfileExtra]).
  Future<PlexTranscodeDecision> decisionUniversal({
    required Map<String, dynamic> params,
    Map<String, String>? extraHeaders,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/video/:/transcode/universal/decision',
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

  String _encode(Map<String, String> qp) =>
      qp.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
}

/// Outcome of [PlexStreamingApi.decisionUniversal].
///
/// Plex returns `generalDecisionCode` inside `MediaContainer` with the
/// following ranges (from the upstream
/// [transcoder docs](https://plexapi.dev/api-reference/transcoder/make-a-decision-on-media-playback.md)):
///
///   - `1000`–`1999` direct-play / direct-stream variants
///   - `2000`–`2999` transcode (with codec re-encode)
///   - other codes means the server refused (codec mismatch the
///     profile can't even transcode, item not found, etc.)
class PlexTranscodeDecision {
  /// The numeric `generalDecisionCode` from the response. Null when
  /// the response shape was unexpected.
  final int? code;

  /// The raw `MediaContainer` for fields not promoted here.
  final Map<String, dynamic> raw;

  const PlexTranscodeDecision({required this.code, required this.raw});

  /// `true` when Plex agreed to direct-play / direct-stream (1xxx).
  bool get isDirect => code != null && code! >= 1000 && code! < 2000;

  /// `true` when Plex requires a transcoded session (2xxx).
  bool get isTranscode => code != null && code! >= 2000 && code! < 3000;

  /// `true` when the decision call returned a usable code (direct or
  /// transcode). `false` means the server refused.
  bool get isPlayable => isDirect || isTranscode;
}
