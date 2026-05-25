// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:typed_data';

import '../plex_connection.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';

/// Build & fetch artwork URLs through the server's image transcoder
/// (`/photo/:/transcode`).
///
/// Plex requires you to ask the server to resize the image — it WILL
/// serve the raw URL too, but the resulting bytes can be 4MB PNGs.
class PlexImagesApi {
  final PlexConnection _http;

  PlexImagesApi(this._http);

  /// Build a transcoded image URL.
  ///
  /// [sourcePath] is the relative artwork path you saw in metadata —
  /// typically `/library/metadata/{ratingKey}/thumb/{timestamp}` (just
  /// pass `PlexMetadata.thumb` verbatim).
  ///
  /// `width` / `height` cap the output dimensions. Default 500×500 gives
  /// ~50-150KB JPEGs, which is what most music apps cache.
  String transcodeUrl({
    required String sourcePath,
    int width = 500,
    int height = 500,
    int minSize = 1,
    bool upscale = false,
  }) {
    _requireConnected();
    final base = _http.baseUrl!;
    final token = _http.token ?? '';
    final qp = <String, String>{
      'width': '$width',
      'height': '$height',
      'minSize': '$minSize',
      'upscale': upscale ? '1' : '0',
      'url': sourcePath,
      'X-Plex-Token': token,
    };
    return '$base/photo/:/transcode?${qp.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
  }

  /// Fetch artwork bytes directly. Returns null on `404`.
  Future<Uint8List?> fetch({
    required String sourcePath,
    int width = 500,
    int height = 500,
  }) async {
    final url = transcodeUrl(
      sourcePath: sourcePath,
      width: width,
      height: height,
    );
    try {
      final res = await _http.requestBytes(url);
      final body = res.data;
      if (body == null || body.isEmpty) return null;
      return Uint8List.fromList(body);
    } on PlexException catch (e) {
      if (e.type == PlexErrorType.notFound) return null;
      rethrow;
    }
  }

  void _requireConnected() {
    if (_http.baseUrl == null) {
      throw const PlexException(
        'No PMS connection — call PlexClient.connect() first.',
        type: PlexErrorType.state,
      );
    }
  }
}
