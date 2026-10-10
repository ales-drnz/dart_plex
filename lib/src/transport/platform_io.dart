// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// The client used when none is injected: `dart:io`'s, with [connectTimeout]
/// applied to the TCP/TLS handshake.
///
/// `autoUncompress` is off: `dart:io` would gunzip every body on the
/// isolate that reads it, which for a list page is the biggest piece of
/// work left on the caller (a 90 KB gzip body is 1.5 MB of JSON). The
/// connection gunzips instead, on the same background isolate that decodes
/// and parses the body (see [gunzip]).
http.Client createDefaultClient(Duration connectTimeout) => IOClient(
      HttpClient()
        ..connectionTimeout = connectTimeout
        ..autoUncompress = false,
    );

/// Whether the default client leaves gzip bodies compressed for [gunzip].
const bool defaultClientLeavesGzip = true;

/// Decompresses a gzip body.
Uint8List gunzip(Uint8List bytes) {
  final out = gzip.decode(bytes);
  return out is Uint8List ? out : Uint8List.fromList(out);
}

/// Decompresses a gzip body as it arrives.
Stream<List<int>> gunzipStream(Stream<List<int>> body) =>
    body.transform(gzip.decoder);

/// Whether [runOffIsolate] really leaves the calling isolate.
const bool canUseIsolates = true;

/// Runs [computation] on a short-lived isolate. Its result comes back
/// through `Isolate.exit`, so even a large object graph is not copied.
Future<R> runOffIsolate<R>(R Function() computation) =>
    Isolate.run(computation);
