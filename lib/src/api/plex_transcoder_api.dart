// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';

/// `/photo/:/transcode` and `/{audio|video|photo}/:/transcode/...` —
/// universal transcode URL builders.
///
/// Wraps the `Transcoder` OpenAPI tag (4 operations not already
/// covered by [PlexStreamingApi] / [PlexImagesApi]). The audio /
/// video universal start URLs already live on [PlexStreamingApi];
/// this sub-API adds the subtitle transcode, the manual fallback
/// trigger, and the image transcoder URL builder.
class PlexTranscoderApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.transcoder].
  PlexTranscoderApi(this._http);

  /// Build a `/photo/:/transcode` URL. [sourceUrl] is the relative
  /// image path (`/library/metadata/{id}/thumb/{ts}`) or an
  /// absolute URL.
  ///
  /// [chromaSubsampling] selects the chroma subsampling mode and must
  /// be one of the server's fixed integer values: `0`=4:1:1, `1`=4:2:0,
  /// `2`=4:2:2, `3`=4:4:4 (the server default is `3`=4:4:4).
  String imageUrl({
    required String sourceUrl,
    int? width,
    int? height,
    int? quality,
    String? format,
    int? minSize,
    int? rotate,
    int? blur,
    int? saturation,
    int? opacity,
    int? chromaSubsampling,
    String? blendColor,
    String? background,
    bool? upscale,
  }) {
    assert(
      chromaSubsampling == null ||
          (chromaSubsampling >= 0 && chromaSubsampling <= 3),
      'chromaSubsampling must be 0, 1, 2 or 3',
    );
    _requireConnected();
    final base = _http.baseUrl!;
    final token = _http.token ?? '';
    final qp = <String, String>{'url': sourceUrl, 'X-Plex-Token': token};
    if (width != null) qp['width'] = '$width';
    if (height != null) qp['height'] = '$height';
    if (quality != null) qp['quality'] = '$quality';
    if (format != null) qp['format'] = format;
    if (minSize != null) qp['minSize'] = '$minSize';
    if (rotate != null) qp['rotate'] = '$rotate';
    if (blur != null) qp['blur'] = '$blur';
    if (saturation != null) qp['saturation'] = '$saturation';
    if (opacity != null) qp['opacity'] = '$opacity';
    if (chromaSubsampling != null) {
      qp['chromaSubsampling'] = '$chromaSubsampling';
    }
    if (blendColor != null) qp['blendColor'] = blendColor;
    if (background != null) qp['background'] = background;
    if (upscale != null) qp['upscale'] = upscale ? '1' : '0';
    final query = qp.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$base/photo/:/transcode?$query';
  }

  /// `POST /{transcodeType}/:/transcode/universal/fallback` —
  /// manually trigger a transcoder fallback (used when the player
  /// reports direct-play / direct-stream failed and wants the
  /// server to fall back to a full transcode).
  ///
  /// [transcodeType] is `'audio' | 'video' | 'photo'`.
  Future<void> triggerFallback({required String transcodeType}) async {
    await _http.request<void>(
      '/$transcodeType/:/transcode/universal/fallback',
      method: 'POST',
    );
  }

  /// `GET /{transcodeType}/:/transcode/universal/subtitles` — URL
  /// for transcoded subtitle stream.
  String subtitlesUrl({
    required String transcodeType,
    Map<String, String> params = const {},
  }) {
    _requireConnected();
    final base = _http.baseUrl!;
    final token = _http.token ?? '';
    final qp = <String, String>{'X-Plex-Token': token, ...params};
    final query = qp.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$base/$transcodeType/:/transcode/universal/subtitles?$query';
  }

  /// `GET /{transcodeType}/:/transcode/universal/start.{extension}` —
  /// URL to start a transcode session. The audio/video variants
  /// also exist on [PlexStreamingApi.universalAudioUrl] /
  /// [PlexStreamingApi.universalVideoUrl] (which wrap this with the
  /// consumer-friendly defaults); this method is the raw path-builder.
  String startUrl({
    required String transcodeType,
    required String extension,
    Map<String, String> params = const {},
  }) {
    _requireConnected();
    final base = _http.baseUrl!;
    final token = _http.token ?? '';
    final qp = <String, String>{'X-Plex-Token': token, ...params};
    final query = qp.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$base/$transcodeType/:/transcode/universal/start.$extension?$query';
  }

  void _requireConnected() {
    if (_http.baseUrl == null) {
      throw const PlexException(
        'No PMS connection. Call PlexClient.connect() first.',
        type: PlexErrorType.state,
      );
    }
  }
}
