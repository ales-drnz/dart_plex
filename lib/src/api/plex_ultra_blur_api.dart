// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:typed_data';

import '../plex_connection.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';
import '../plex_models.dart';

/// `/services/ultrablur/*` — server-side palette extraction and
/// gradient backdrop rendering.
///
/// Two operations: pick a source image and ask the server for the
/// four corner colours, then either render those into a smooth
/// gradient (`image` endpoint) or use them directly in the client
/// (CSS gradient, native shader). Saves the consumer the cost of
/// running k-means locally.
class PlexUltraBlurApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.ultraBlur].
  PlexUltraBlurApi(this._http);

  /// `GET /services/ultrablur/colors` — extract four corner colours
  /// from [sourceUrl] (relative library path like
  /// `/library/metadata/{id}/thumb/{ts}` or an absolute URL).
  ///
  /// The container's `UltraBlurColors` array is normally a single
  /// element; the returned [List] keeps the upstream shape verbatim.
  Future<List<PlexUltraBlurColors>> colors({required String sourceUrl}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/services/ultrablur/colors',
      queryParameters: {'url': sourceUrl},
    );
    final container = res.data?['MediaContainer'];
    if (container is! Map<String, dynamic>) return const [];
    final raw = container['UltraBlurColors'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>) PlexUltraBlurColors.fromJson(e),
    ];
  }

  /// Build a `/services/ultrablur/image` URL — a server-rendered
  /// gradient backdrop using the four supplied hex colours.
  ///
  /// All colour parameters and dimensions are optional; the server
  /// fills in defaults. Pass `noise: 1` when the result will be used
  /// behind text to reduce banding on shallow gradients.
  String imageUrl({
    String? topLeft,
    String? topRight,
    String? bottomLeft,
    String? bottomRight,
    int? width,
    int? height,
    int? noise,
  }) {
    _requireConnected();
    final base = _http.baseUrl!;
    final token = _http.token ?? '';
    final qp = <String, String>{};
    if (topLeft != null) qp['topLeft'] = topLeft;
    if (topRight != null) qp['topRight'] = topRight;
    if (bottomLeft != null) qp['bottomLeft'] = bottomLeft;
    if (bottomRight != null) qp['bottomRight'] = bottomRight;
    if (width != null) qp['width'] = '$width';
    if (height != null) qp['height'] = '$height';
    if (noise != null) qp['noise'] = '$noise';
    if (token.isNotEmpty) qp['X-Plex-Token'] = token;
    final query = qp.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$base/services/ultrablur/image${query.isEmpty ? '' : '?$query'}';
  }

  /// Fetch a rendered gradient as bytes. Useful for caching the PNG
  /// out-of-band (e.g. into a Flutter ImageCache).
  Future<Uint8List?> fetchImage({
    String? topLeft,
    String? topRight,
    String? bottomLeft,
    String? bottomRight,
    int? width,
    int? height,
    int? noise,
  }) async {
    final url = imageUrl(
      topLeft: topLeft,
      topRight: topRight,
      bottomLeft: bottomLeft,
      bottomRight: bottomRight,
      width: width,
      height: height,
      noise: noise,
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
        'No PMS connection. Call PlexClient.connect() first.',
        type: PlexErrorType.state,
      );
    }
  }
}
