// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:dart_plex/dart_plex.dart';
import 'package:dart_plex/src/plex_connection.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// A [HttpClientAdapter] that records the last request it saw and replies
/// with a canned JSON body. Lets unit tests assert on the path / query
/// params a sub-API issues without touching the network.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  final Map<String, dynamic> responseBody;

  _CapturingAdapter(this.responseBody);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(responseBody),
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

/// Builds a [PlexHubsApi] wired to a [_CapturingAdapter] that returns a
/// `Hub` MediaContainer with a single hub holding one metadata item.
({PlexHubsApi api, _CapturingAdapter adapter}) _makeApi() {
  final adapter = _CapturingAdapter({
    'MediaContainer': {
      'size': 1,
      'Hub': [
        {
          'key': '/hubs/metadata/12345/children',
          'hubKey': '/library/metadata/12345/related',
          'hubIdentifier': 'music.similar.12345',
          'title': 'More by this Artist',
          'type': 'album',
          'size': 1,
          'more': true,
          'Metadata': [
            {
              'ratingKey': '67890',
              'title': 'Greatest Hits',
              'type': 'album',
            },
          ],
        },
      ],
    },
  });
  final dio = Dio()..httpClientAdapter = adapter;
  final conn = PlexConnection(credentials: _credentials, dio: dio)
    ..baseUrl = 'http://192.168.1.10:32400';
  return (api: PlexHubsApi(conn), adapter: adapter);
}

void main() {
  group('PlexHubsApi.forMetadata', () {
    test('issues GET /hubs/metadata/{metadataId}', () async {
      final ctx = _makeApi();
      await ctx.api.forMetadata(metadataId: '12345');

      final req = ctx.adapter.lastRequest!;
      expect(req.method, 'GET');
      expect(req.path, 'http://192.168.1.10:32400/hubs/metadata/12345');
    });

    test('decodes the Hub MediaContainer into List<PlexHub>', () async {
      final ctx = _makeApi();
      final hubs = await ctx.api.forMetadata(metadataId: '12345');

      expect(hubs, isA<List<PlexHub>>());
      expect(hubs, hasLength(1));
      final hub = hubs.single;
      expect(hub.hubIdentifier, 'music.similar.12345');
      expect(hub.title, 'More by this Artist');
      expect(hub.more, isTrue);
      expect(hub.items, hasLength(1));
      expect(hub.items.single.title, 'Greatest Hits');
    });

    test('omits onlyTransient and count when not provided', () async {
      final ctx = _makeApi();
      await ctx.api.forMetadata(metadataId: '12345');

      final qp = ctx.adapter.lastRequest!.queryParameters;
      expect(qp.containsKey('onlyTransient'), isFalse);
      expect(qp.containsKey('count'), isFalse);
    });

    test('adds onlyTransient as 1 when true', () async {
      final ctx = _makeApi();
      await ctx.api.forMetadata(metadataId: '12345', onlyTransient: true);

      final qp = ctx.adapter.lastRequest!.queryParameters;
      expect(qp['onlyTransient'], 1);
      expect(qp.containsKey('count'), isFalse);
    });

    test('adds onlyTransient as 0 when false', () async {
      final ctx = _makeApi();
      await ctx.api.forMetadata(metadataId: '12345', onlyTransient: false);

      final qp = ctx.adapter.lastRequest!.queryParameters;
      expect(qp['onlyTransient'], 0);
    });

    test('adds count when provided', () async {
      final ctx = _makeApi();
      await ctx.api.forMetadata(metadataId: '12345', count: 8);

      final qp = ctx.adapter.lastRequest!.queryParameters;
      expect(qp['count'], 8);
      expect(qp.containsKey('onlyTransient'), isFalse);
    });

    test('adds both onlyTransient and count when both provided', () async {
      final ctx = _makeApi();
      await ctx.api
          .forMetadata(metadataId: '12345', onlyTransient: true, count: 12);

      final qp = ctx.adapter.lastRequest!.queryParameters;
      expect(qp['onlyTransient'], 1);
      expect(qp['count'], 12);
    });
  });
}
