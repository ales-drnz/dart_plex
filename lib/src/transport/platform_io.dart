// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
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
///
/// Throws a [FormatException] when the body is not gzip or is cut short:
/// `dart:io`'s decoder does not read the trailer, so its length field
/// (ISIZE, the inflated size mod 2³²) is checked here.
Uint8List gunzip(Uint8List bytes) {
  if (bytes.isEmpty) return bytes;
  final inflated = gzip.decode(bytes);
  final out = inflated is Uint8List ? inflated : Uint8List.fromList(inflated);
  if (bytes.length < 4 ||
      _isize(bytes, bytes.length - 4) != _mod32(out.length)) {
    throw const FormatException('Truncated gzip body');
  }
  return out;
}

/// Decompresses a gzip body as it arrives, failing with a
/// [FormatException] at the end when the trailer's length does not match
/// what was inflated (a body cut short).
Stream<List<int>> gunzipStream(Stream<List<int>> body) {
  final tail = <int>[];
  var inflated = 0;
  return body
      .map((chunk) {
        // Keep the last four bytes seen: the trailer's ISIZE.
        if (chunk.length >= 4) {
          tail
            ..clear()
            ..addAll(chunk.skip(chunk.length - 4));
        } else {
          tail.addAll(chunk);
          if (tail.length > 4) tail.removeRange(0, tail.length - 4);
        }
        return chunk;
      })
      .transform(gzip.decoder)
      .transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (chunk, sink) {
            inflated += chunk.length;
            sink.add(chunk);
          },
          handleDone: (sink) {
            if (tail.length < 4 || _isize(tail, 0) != _mod32(inflated)) {
              sink.addError(const FormatException('Truncated gzip body'));
            }
            sink.close();
          },
        ),
      );
}

int _isize(List<int> b, int at) =>
    b[at] | b[at + 1] << 8 | b[at + 2] << 16 | b[at + 3] << 24;

int _mod32(int n) => n & 0xFFFFFFFF;

/// Whether [runOffIsolate] really leaves the calling isolate.
const bool canUseIsolates = true;

/// Runs [computation] on a short-lived isolate. Its result comes back
/// through `Isolate.exit`, so even a large object graph is not copied.
Future<R> runOffIsolate<R>(R Function() computation) =>
    Isolate.run(computation);
