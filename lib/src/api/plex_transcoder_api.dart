// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// @docImport '../plex_client.dart';
/// @docImport '../plex_exception.dart';
/// @docImport 'plex_images_api.dart';
library;

import '../plex_connection.dart';
import '../plex_urls.dart';
import 'plex_streaming_api.dart';

/// `/photo/:/transcode` and `/{audio|video|photo}/:/transcode/...` —
/// universal transcode URL builders.
///
/// Wraps the `Transcoder` OpenAPI tag (4 operations not already
/// covered by [PlexStreamingApi] / [PlexImagesApi]). The audio /
/// video universal start URLs already live on [PlexStreamingApi];
/// this sub-API adds the subtitle transcode, the manual fallback
/// trigger, and the image transcoder URL builder.
///
/// {@category Streaming}
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
  /// `2`=4:2:2, `3`=4:4:4 (the server default is `3`=4:4:4); anything
  /// else throws an [ArgumentError].
  ///
  /// The URL carries the token: do not log it. Throws a `state`
  /// [PlexException] before [PlexClient.connect].
  ///
  /// [PlexImagesApi.transcodeUrl] is the short form, for a plain resize.
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
    if (chromaSubsampling != null &&
        (chromaSubsampling < 0 || chromaSubsampling > 3)) {
      throw ArgumentError.value(
        chromaSubsampling,
        'chromaSubsampling',
        'chromaSubsampling must be 0, 1, 2 or 3',
      );
    }
    return _http.signedUrl('/photo/:/transcode', {
      'url': sourceUrl,
      'width': ?width,
      'height': ?height,
      'quality': ?quality,
      'format': ?format,
      'minSize': ?minSize,
      'rotate': ?rotate,
      'blur': ?blur,
      'saturation': ?saturation,
      'opacity': ?opacity,
      'chromaSubsampling': ?chromaSubsampling,
      'blendColor': ?blendColor,
      'background': ?background,
      if (upscale != null) 'upscale': upscale ? '1' : '0',
    });
  }

  /// `POST /{transcodeType}/:/transcode/universal/fallback` —
  /// manually trigger a transcoder fallback (used when the player
  /// reports direct-play / direct-stream failed and wants the
  /// server to fall back to a full transcode).
  ///
  /// [transcodeType] is `'audio' | 'video' | 'photo'`.
  Future<void> triggerFallback({required String transcodeType}) async {
    await _http.request<void>(
      '/${seg(transcodeType)}/:/transcode/universal/fallback',
      method: 'POST',
    );
  }

  /// `GET /{transcodeType}/:/transcode/universal/subtitles` — URL
  /// for transcoded subtitle stream.
  ///
  /// The URL carries the token: do not log it. Throws a `state`
  /// [PlexException] before [PlexClient.connect].
  String subtitlesUrl({
    required String transcodeType,
    Map<String, String> params = const {},
  }) => _http.signedUrl(
    '/${seg(transcodeType)}/:/transcode/universal/subtitles',
    params,
  );

  /// `GET /{transcodeType}/:/transcode/universal/start.{extension}` —
  /// URL to start a transcode session, from your own parameters. PMS
  /// 1.43.2 refuses a start without a decision and a client profile:
  /// [PlexStreamingApi.startAudioTranscode] and
  /// [PlexStreamingApi.startVideoTranscode] ask for the decision and
  /// build this URL with the same parameters.
  ///
  /// The URL carries the token: do not log it. Throws a `state`
  /// [PlexException] before [PlexClient.connect].
  @Deprecated(
    'Use PlexStreamingApi.startVideoTranscode or startAudioTranscode '
    'instead. Will be removed in 0.4.0.',
  )
  String startUrl({
    required String transcodeType,
    required String extension,
    Map<String, String> params = const {},
  }) => _http.signedUrl(
    '/${seg(transcodeType)}/:/transcode/universal/start.${seg(extension)}',
    params,
  );
}
