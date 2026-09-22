// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:dart_plex/dart_plex.dart';
import 'package:dart_plex/src/plex_connection.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode({
        'MediaContainer': {
          'size': 1,
          'Metadata': [
            {'ratingKey': '1', 'type': 'track', 'title': 'One'},
          ],
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _credentials = PlexCredentials(
  clientIdentifier: 'test-uuid',
  product: 'TestApp',
  version: '1.0.0',
  device: 'TestDevice',
  deviceName: 'Test Device',
  platform: 'Test',
);

(PlexClient, _CapturingAdapter) _client() {
  final adapter = _CapturingAdapter();
  final client = PlexClient(
    credentials: _credentials,
    dio: Dio()..httpClientAdapter = adapter,
  )
    ..setToken('t')
    ..connect('http://pms.test:32400');
  return (client, adapter);
}

void main() {
  group('playlists.items', () {
    test('without paging asks for the whole playlist', () async {
      final (client, adapter) = _client();
      final items = await client.playlists.items('42');

      expect(items, hasLength(1));
      final q = adapter.lastRequest!.uri.queryParameters;
      expect(adapter.lastRequest!.uri.path, '/playlists/42/items');
      expect(q.containsKey('X-Plex-Container-Start'), isFalse);
      expect(q.containsKey('X-Plex-Container-Size'), isFalse);
    });

    test('start and size travel as container paging', () async {
      final (client, adapter) = _client();
      await client.playlists.items('42', start: 0, size: 20);

      final q = adapter.lastRequest!.uri.queryParameters;
      expect(q['X-Plex-Container-Start'], '0');
      expect(q['X-Plex-Container-Size'], '20');
    });
  });

  group('response decoding', () {
    test('the default transport decodes large bodies off-isolate', () {
      final connection = PlexConnection(credentials: _credentials);
      final transformer = connection.transformer;

      expect(transformer, isA<FusedTransformer>());
      expect(
        (transformer as FusedTransformer).contentLengthIsolateThreshold,
        PlexConnection.jsonIsolateThreshold,
      );
      expect(PlexConnection.jsonIsolateThreshold, greaterThan(0));
    });

    test('an injected Dio keeps its own transformer', () {
      final dio = Dio();
      final mine = dio.transformer;
      final connection = PlexConnection(credentials: _credentials, dio: dio);

      expect(identical(connection.transformer, mine), isTrue);
    });
  });
}
