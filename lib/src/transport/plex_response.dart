// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';

/// How [PlexClient.request] decodes a response body.
enum PlexResponseType {
  /// JSON when the server says so (`Content-Type: application/json`),
  /// otherwise the body as UTF-8 text. An empty body is `null`.
  json,

  /// The raw bytes, as a `Uint8List`.
  bytes,

  /// The body as UTF-8 text, whatever its content type.
  plain,
}

/// A completed response with a decoded body.
final class PlexResponse<T> {
  /// The decoded body, or `null` when the server sent none.
  final T? data;

  /// HTTP status code (always 2xx: anything else throws).
  final int statusCode;

  /// Response headers, with lower-case names.
  final Map<String, String> headers;

  /// The URI that was requested, query string included.
  final Uri uri;

  /// Creates a response. Built by the transport; public for tests and fakes.
  const PlexResponse({
    required this.data,
    required this.statusCode,
    required this.headers,
    required this.uri,
  });

  /// The `Content-Type` header, if any.
  String? get contentType => headers['content-type'];
}

/// A response whose body is still arriving, for downloads too large to
/// hold in memory.
///
/// Listen to [stream] once. Cancelling the subscription closes the
/// connection.
final class PlexStreamedResponse {
  /// The body, chunk by chunk.
  final Stream<List<int>> stream;

  /// HTTP status code (always 2xx: anything else throws).
  final int statusCode;

  /// Response headers, with lower-case names.
  final Map<String, String> headers;

  /// `Content-Length`, when the server sent one.
  final int? contentLength;

  /// The URI that was requested, query string included.
  final Uri uri;

  /// Creates a streamed response. Built by the transport.
  const PlexStreamedResponse({
    required this.stream,
    required this.statusCode,
    required this.headers,
    required this.contentLength,
    required this.uri,
  });

  /// The `Content-Type` header, if any.
  String? get contentType => headers['content-type'];
}
