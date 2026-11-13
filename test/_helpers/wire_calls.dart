// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Table-driven tests for calls whose whole behaviour is the request they
/// send: the verb, the path and the decoded query, values included.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import 'capturing_client.dart';

/// A call on a connected client, and the request it must put on the wire:
/// what it is, the call, the verb, the path, and the whole decoded query.
typedef WireCall = (
  String name,
  Future<Object?> Function(PlexClient plex) call,
  String method,
  String path,
  Map<String, String> query,
);

/// One test per entry of [calls]: the call is made against a server that
/// answers an empty JSON object, and the single request it sends is
/// compared with the entry.
void testWireCalls(List<WireCall> calls) {
  for (final (name, call, method, path, query) in calls) {
    test('$name sends $method $path', () async {
      final adapter = CapturingAdapter();
      await call(testClient(adapter));
      expect(adapter.requests, hasLength(1));
      final request = adapter.last!;
      expect(request.method, method);
      expect(request.uri.path, path);
      expect(request.queryParameters, query);
    });
  }
}

/// Matches the [PlexException] of a body that could not be read.
final Matcher throwsParseError = throwsA(
  isA<PlexException>().having((e) => e.type, 'type', PlexErrorType.parse),
);

/// The path and the token of a URL built for a player, as the server
/// would read them.
(String path, String? token) pathAndToken(String url) {
  final uri = Uri.parse(url);
  return (uri.path, uri.queryParameters['X-Plex-Token']);
}
