// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// The client used when none is injected: `dart:io`'s, with [connectTimeout]
/// applied to the TCP/TLS handshake.
http.Client createDefaultClient(Duration connectTimeout) =>
    IOClient(HttpClient()..connectionTimeout = connectTimeout);

/// Whether [runOffIsolate] really leaves the calling isolate.
const bool canUseIsolates = true;

/// Runs [computation] on a short-lived isolate. Its result comes back
/// through `Isolate.exit`, so even a large object graph is not copied.
Future<R> runOffIsolate<R>(R Function() computation) =>
    Isolate.run(computation);
