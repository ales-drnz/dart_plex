// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'plex_client.dart';
import 'plex_error_type.dart';
import 'plex_exception.dart';
import 'transport/plex_cancel_token.dart';

/// Downloads straight to disk.
extension PlexDownload on PlexClient {
  /// Streams [url] into the file at [path] and returns the bytes written.
  ///
  /// The body is written as it arrives, at the pace the disk takes it — a
  /// whole track never sits in memory — to a temporary file next to
  /// [path], renamed to [path] only once complete. A failure, a stall past
  /// the receive timeout or a cancellation through [cancelToken] removes
  /// the temporary file and throws a [PlexException] (of type
  /// [PlexErrorType.cancelled] for a cancellation); whatever was at [path]
  /// before is left as it was. Two downloads to the same [path] never
  /// share a temporary file.
  ///
  /// [onProgress] is called after each chunk with the bytes received so
  /// far and the total when the server sent a `Content-Length` (never for
  /// a gzip body, whose length on the wire is not the file's).
  Future<int> downloadToFile(
    String url,
    String path, {
    Map<String, Object?>? queryParameters,
    bool absoluteUrl = true,
    PlexCancelToken? cancelToken,
    void Function(int received, int? total)? onProgress,
  }) async {
    final File part;
    final IOSink sink;
    try {
      part = await _createPart(path);
      sink = part.openWrite();
    } on FileSystemException catch (e, st) {
      throw PlexException(
        'Cannot write $path: ${e.message}',
        type: PlexErrorType.state,
        path: url,
        cause: e,
        stackTrace: st,
      );
    }
    var received = 0;
    try {
      final res = await requestStream(
        url,
        queryParameters: queryParameters,
        absoluteUrl: absoluteUrl,
        cancelToken: cancelToken,
      );
      // addStream pauses the body while the disk catches up.
      await sink.addStream(
        res.stream.map((chunk) {
          received += chunk.length;
          onProgress?.call(received, res.contentLength);
          return chunk;
        }),
      );
      await sink.flush();
      await sink.close();
      await part.rename(path);
      return received;
    } catch (e, st) {
      await sink.close().catchError((Object _) {});
      await part.delete().catchError((Object _) => part);
      if (e is PlexException) rethrow;
      throw PlexException(
        'Download to $path failed: $e',
        path: url,
        cause: e,
        stackTrace: st,
      );
    }
  }
}

/// Creates a temporary file next to [path], unique to this download.
Future<File> _createPart(String path) async {
  final target = File(path);
  await target.parent.create(recursive: true);
  for (var i = 0;; i++) {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final part = File('$path.$stamp${i == 0 ? '' : '-$i'}.part');
    try {
      await part.create(exclusive: true);
      return part;
    } on PathExistsException {
      if (i >= 100) rethrow;
    }
  }
}
