// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// The client used when none is injected. The browser owns the handshake,
/// so the connect timeout cannot be applied here.
http.Client createDefaultClient(Duration connectTimeout) => BrowserClient();

/// Whether [runOffIsolate] really leaves the calling isolate.
const bool canUseIsolates = false;

/// Isolates are not available on the web; runs [computation] in place.
Future<R> runOffIsolate<R>(R Function() computation) async => computation();
