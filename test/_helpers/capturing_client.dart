// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// In-process `http.Client`s that record what went on the wire and answer
/// with a canned body, so unit tests can assert on the outgoing request.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_plex/dart_plex.dart';
import 'package:dart_plex/src/plex_connection.dart';
import 'package:http/http.dart' as http;

/// One request as it left the client.
final class CapturedRequest {
  /// HTTP method.
  final String method;

  /// Full URI, query string included.
  final Uri uri;

  /// Request headers.
  final Map<String, String> headers;

  /// Request body bytes.
  final Uint8List body;

  CapturedRequest(this.method, this.uri, this.headers, this.body);

  /// Scheme, host and path — the URL without its query string.
  String get path => '${uri.scheme}://${uri.authority}${uri.path}';

  /// Decoded query parameters (last value wins; see [queryParametersAll]).
  Map<String, String> get queryParameters => uri.queryParameters;

  /// Decoded query parameters, every value of a repeated key kept.
  Map<String, List<String>> get queryParametersAll => uri.queryParametersAll;

  /// The body decoded as JSON.
  Object? get json => jsonDecode(utf8.decode(body));
}

/// A canned answer.
final class CannedResponse {
  final int status;
  final List<int> body;
  final String contentType;

  CannedResponse(
    this.status,
    this.body, {
    this.contentType = 'application/json',
  });

  CannedResponse.json(Object? value, {this.status = 200})
      : body = utf8.encode(jsonEncode(value)),
        contentType = 'application/json';
}

/// Shared recording logic.
abstract class _Recording extends http.BaseClient {
  /// Every request, oldest first.
  final List<CapturedRequest> requests = [];

  /// The most recent request, or `null` if none has been made yet.
  CapturedRequest? get lastRequest => requests.isEmpty ? null : requests.last;

  /// Same as [lastRequest].
  CapturedRequest? get last => lastRequest;

  Future<CapturedRequest> record(http.BaseRequest request) async {
    final body = await request.finalize().toBytes();
    final captured =
        CapturedRequest(request.method, request.url, request.headers, body);
    requests.add(captured);
    return captured;
  }
}

/// Answers every request with [responseBody] as JSON, unless [respond]
/// picks a status and body for it.
class CapturingAdapter extends _Recording {
  /// The JSON body sent back by default.
  Object? responseBody;

  /// Per-request override; `null` falls back to [responseBody].
  CannedResponse? Function(CapturedRequest request)? respond;

  CapturingAdapter([this.responseBody = const <String, dynamic>{}]);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final captured = await record(request);
    final canned = respond?.call(captured) ?? CannedResponse.json(responseBody);
    return http.StreamedResponse(
      Stream.value(canned.body),
      canned.status,
      contentLength: canned.body.length,
      request: request,
      headers: {'content-type': canned.contentType},
    );
  }
}

/// Answers every request with raw [responseBytes].
class BytesAdapter extends _Recording {
  List<int> responseBytes;
  String? contentType;

  BytesAdapter(this.responseBytes, {this.contentType});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await record(request);
    return http.StreamedResponse(
      Stream.value(responseBytes),
      200,
      contentLength: responseBytes.length,
      request: request,
      headers: {if (contentType != null) 'content-type': contentType!},
    );
  }
}

/// Hands back a body whose byte stream the test drives by hand, so the
/// chunk boundaries are chosen rather than left to wherever the network
/// happened to split the response.
class StreamingAdapter extends _Recording {
  final _controller = StreamController<List<int>>();
  final fetched = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await record(request);
    if (!fetched.isCompleted) fetched.complete();
    return http.StreamedResponse(
      _controller.stream,
      200,
      request: request,
      headers: {'content-type': 'text/event-stream'},
    );
  }

  void emit(List<int> bytes) => _controller.add(Uint8List.fromList(bytes));

  Future<void> finish() => _controller.close();
}

const testCredentials = PlexCredentials(
  clientIdentifier: 'test-uuid',
  product: 'TestApp',
  version: '1.0.0',
  device: 'TestDevice',
  deviceName: 'Test Device',
  platform: 'Test',
);

/// A connection to a fake PMS at `http://192.168.1.10:32400`.
///
/// The isolate threshold is 0, so every typed parse runs through an
/// isolate: a parse closure that captures something unsendable fails here
/// rather than in production.
PlexConnection testConnection(
  http.Client client, {
  PlexCredentials credentials = testCredentials,
  int jsonIsolateThreshold = 0,
}) =>
    PlexConnection(
      credentials: credentials,
      httpClient: client,
      jsonIsolateThreshold: jsonIsolateThreshold,
    )..baseUrl = 'http://192.168.1.10:32400';

/// A client connected to the same fake PMS, with token `tok`.
PlexClient testClient(http.Client client, {int jsonIsolateThreshold = 0}) =>
    PlexClient(
      credentials: testCredentials,
      httpClient: client,
      jsonIsolateThreshold: jsonIsolateThreshold,
    )..connect('http://192.168.1.10:32400', accessToken: 'tok');
