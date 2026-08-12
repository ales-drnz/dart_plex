// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:dart_plex/dart_plex.dart';
import 'package:dart_plex/src/plex_connection.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// A [HttpClientAdapter] that records the last request it saw and replies
/// with a canned JSON body.
///
/// These tests assert on the *outgoing query string*, not on the entities
/// that come back: Plex answers 200 to a filtered and an unfiltered query
/// alike, so a wrongly-named filter parameter is invisible from the
/// response side. The wire is the contract.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  Map<String, dynamic> responseBody;

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

/// An empty `Metadata` container — enough for [PlexLibraryApi.allByType]
/// to decode, with a `totalSize` for the count path.
Map<String, dynamic> _metadataBody({int totalSize = 42}) => {
      'MediaContainer': {
        'size': 0,
        'totalSize': totalSize,
        'Metadata': <Map<String, dynamic>>[],
      },
    };

({PlexLibraryApi api, _CapturingAdapter adapter}) _makeApi([
  Map<String, dynamic>? body,
]) {
  final adapter = _CapturingAdapter(body ?? _metadataBody());
  final dio = Dio()..httpClientAdapter = adapter;
  final conn = PlexConnection(credentials: _credentials, dio: dio)
    ..baseUrl = 'http://192.168.1.10:32400';
  return (api: PlexLibraryApi(conn), adapter: adapter);
}

/// Decoded query parameters of the last request — operators come back
/// unescaped here, so `year>>` reads as `year>>`.
Map<String, String> _query(_CapturingAdapter adapter) =>
    adapter.lastRequest!.uri.queryParameters;

void main() {
  group('PlexFilter wire form', () {
    test('a tag filter is a query parameter named after the field', () {
      final filter = PlexFilter.genre(6);
      expect(filter.parameterName, 'genre');
      expect(filter.parameterValue, '6');
      expect(filter.toString(), 'genre=6');
    });

    test('the operator is part of the parameter name, not the value', () {
      expect(PlexFilter.yearAfter(2009).toString(), 'year>>=2009');
      expect(PlexFilter.yearBefore(2000).toString(), 'year<<=2000');
      expect(PlexFilter.genre(6, exclude: true).toString(), 'genre!=6');
      expect(PlexFilter.titleIs('Abbey Road').toString(), 'title==Abbey Road');
    });

    test('several values in one condition are comma-joined', () {
      final filter = PlexFilter.tag('mood', [3, 7, 11]);
      expect(filter.parameterName, 'mood');
      expect(filter.parameterValue, '3,7,11');
    });

    test('rated() is userRating greater than zero', () {
      expect(PlexFilter.rated().toString(), 'userRating>>=0');
      expect(PlexFilter.ratingAbove(9).toString(), 'userRating>>=9');
    });

    test('play state is the unwatched flag, sent as 1 or 0', () {
      expect(PlexFilter.unplayed().toString(), 'unwatched=1');
      expect(PlexFilter.played().toString(), 'unwatched=0');
      expect(
        PlexFilter.flag('unwatched', value: false).toString(),
        'unwatched=0',
      );
    });

    test('titleContains uses the substring form, titleIs the exact one', () {
      expect(PlexFilter.titleContains('abbey').parameterName, 'title');
      expect(PlexFilter.titleIs('abbey').parameterName, 'title=');
    });

    test('equal conditions compare equal', () {
      expect(PlexFilter.genre(6), PlexFilter.genre(6));
      expect(PlexFilter.genre(6), isNot(PlexFilter.genre(7)));
      expect(PlexFilter.genre(6), isNot(PlexFilter.genre(6, exclude: true)));
    });
  });

  group('PlexLibraryApi.allByType', () {
    test('never sends a parameter named "filter"', () async {
      final ctx = _makeApi();
      await ctx.api.allByType(
        sectionId: '3',
        type: PlexMetadataType.album,
        filters: [PlexFilter.genre(6)],
      );

      // The 0.1.0 bug: `?filter=genre%3D6`, which Plex ignores wholesale.
      expect(_query(ctx.adapter).containsKey('filter'), isFalse);
      expect(ctx.adapter.lastRequest!.uri.query, isNot(contains('filter=')));
    });

    test('sends a genre filter as ?genre=<tagId>', () async {
      final ctx = _makeApi();
      await ctx.api.allByType(
        sectionId: '3',
        type: PlexMetadataType.album,
        filters: [PlexFilter.genre(6)],
      );

      final req = ctx.adapter.lastRequest!;
      expect(req.method, 'GET');
      expect(req.path, 'http://192.168.1.10:32400/library/sections/3/all');
      expect(_query(ctx.adapter)['genre'], '6');
      expect(_query(ctx.adapter)['type'], '9');
    });

    test('matches the fastKey the server hands back for a genre', () async {
      final ctx = _makeApi();
      await ctx.api.allByType(
        sectionId: '3',
        type: PlexMetadataType.album,
        filters: [PlexFilter.genre(42)],
      );

      // Plex's own `fastKey` for genre 42 in an album view is
      // `/library/sections/3/all?genre=42&type=9`.
      final uri = ctx.adapter.lastRequest!.uri;
      expect(uri.path, '/library/sections/3/all');
      expect(uri.queryParameters['genre'], '42');
      expect(uri.queryParameters['type'], '9');
    });

    test('keeps the operator in the parameter name on the wire', () async {
      final ctx = _makeApi();
      await ctx.api.allByType(
        sectionId: '3',
        type: PlexMetadataType.album,
        filters: [PlexFilter.rated()],
      );

      expect(_query(ctx.adapter).containsKey('userRating>>'), isTrue);
      expect(_query(ctx.adapter)['userRating>>'], '0');
      // Percent-encoded on the wire, as any query component must be.
      expect(
        ctx.adapter.lastRequest!.uri.query,
        contains('userRating%3E%3E=0'),
      );
    });

    test('sends one query parameter per condition', () async {
      final ctx = _makeApi();
      await ctx.api.allByType(
        sectionId: '3',
        type: PlexMetadataType.album,
        filters: [
          PlexFilter.genre(6),
          PlexFilter.yearAfter(2009),
          PlexFilter.unplayed(),
        ],
      );

      final qp = _query(ctx.adapter);
      expect(qp['genre'], '6');
      expect(qp['year>>'], '2009');
      expect(qp['unwatched'], '1');
    });

    test('sends an excluding tag filter under the negated name', () async {
      final ctx = _makeApi();
      await ctx.api.allByType(
        sectionId: '3',
        type: PlexMetadataType.album,
        filters: [PlexFilter.genre(6, exclude: true)],
      );

      final qp = _query(ctx.adapter);
      expect(qp.containsKey('genre'), isFalse);
      expect(qp['genre!'], '6');
    });

    test('ORs several tag ids inside one parameter', () async {
      final ctx = _makeApi();
      await ctx.api.allByType(
        sectionId: '3',
        type: PlexMetadataType.album,
        filters: [
          PlexFilter.tag('genre', [6, 7]),
        ],
      );

      expect(_query(ctx.adapter)['genre'], '6,7');
    });

    test('sends no filter parameters when none are given', () async {
      final ctx = _makeApi();
      await ctx.api.allByType(sectionId: '3', type: PlexMetadataType.album);

      expect(
        _query(ctx.adapter).keys,
        containsAll(<String>[
          'type',
          'X-Plex-Container-Start',
          'X-Plex-Container-Size',
        ]),
      );
      expect(_query(ctx.adapter).containsKey('genre'), isFalse);
      expect(_query(ctx.adapter).containsKey('sort'), isFalse);
    });

    test('still sends paging and sort alongside filters', () async {
      final ctx = _makeApi();
      await ctx.api.allByType(
        sectionId: '3',
        type: PlexMetadataType.album,
        start: 100,
        size: 25,
        sort: 'titleSort:asc',
        filters: [PlexFilter.genre(6)],
      );

      final qp = _query(ctx.adapter);
      expect(qp['X-Plex-Container-Start'], '100');
      expect(qp['X-Plex-Container-Size'], '25');
      expect(qp['sort'], 'titleSort:asc');
      expect(qp['genre'], '6');
    });

    test('refuses two conditions that would collide on one parameter',
        () async {
      final ctx = _makeApi();

      await expectLater(
        ctx.api.allByType(
          sectionId: '3',
          type: PlexMetadataType.album,
          filters: [PlexFilter.genre(6), PlexFilter.genre(7)],
        ),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.state),
        ),
      );
    });

    test('allows the same field twice under different operators', () async {
      final ctx = _makeApi();
      await ctx.api.allByType(
        sectionId: '3',
        type: PlexMetadataType.album,
        filters: [PlexFilter.yearAfter(1999), PlexFilter.yearBefore(2010)],
      );

      final qp = _query(ctx.adapter);
      expect(qp['year>>'], '1999');
      expect(qp['year<<'], '2010');
    });
  });

  group('PlexLibraryApi.countByType', () {
    test('asks for zero items and returns totalSize', () async {
      final ctx = _makeApi(_metadataBody(totalSize: 137));
      final count = await ctx.api.countByType(
        sectionId: '3',
        type: PlexMetadataType.album,
      );

      expect(count, 137);
      final qp = _query(ctx.adapter);
      expect(qp['X-Plex-Container-Size'], '0');
      expect(qp['type'], '9');
    });

    test('filters the count the same way allByType filters the page', () async {
      final filters = [PlexFilter.genre(6), PlexFilter.yearAfter(2009)];

      final counting = _makeApi();
      await counting.api.countByType(
        sectionId: '3',
        type: PlexMetadataType.album,
        filters: filters,
      );

      final listing = _makeApi();
      await listing.api.allByType(
        sectionId: '3',
        type: PlexMetadataType.album,
        size: 0,
        filters: filters,
      );

      // The two must not drift: same path, same filter parameters.
      expect(
        counting.adapter.lastRequest!.uri,
        listing.adapter.lastRequest!.uri,
      );
    });

    test('never sends a parameter named "filter"', () async {
      final ctx = _makeApi();
      await ctx.api.countByType(
        sectionId: '3',
        type: PlexMetadataType.album,
        filters: [PlexFilter.genre(6)],
      );

      expect(_query(ctx.adapter).containsKey('filter'), isFalse);
      expect(_query(ctx.adapter)['genre'], '6');
    });
  });

  group('PlexLibraryApi.genres', () {
    Map<String, dynamic> genreBody(List<Map<String, dynamic>> entries) => {
          'MediaContainer': {'size': entries.length, 'Directory': entries},
        };

    test('reads the tag id out of fastKey', () async {
      final ctx = _makeApi(
        genreBody([
          {
            'fastKey': '/library/sections/3/all?genre=42&type=9',
            'key': '42',
            'title': 'Rock',
            'type': 'genre',
          },
        ]),
      );

      final genres = await ctx.api.genres(
        sectionId: '3',
        type: PlexMetadataType.album,
      );

      expect(genres, hasLength(1));
      expect(genres.single.id, 42);
      expect(genres.single.field, 'genre');
      expect(genres.single.title, 'Rock');
      expect(genres.single.fastKey, '/library/sections/3/all?genre=42&type=9');
    });

    test('reads a bare-id key, as current servers send it', () async {
      final ctx = _makeApi(
        genreBody([
          {'key': '7', 'title': 'Jazz', 'type': 'genre'},
        ]),
      );

      final genres = await ctx.api.genres(
        sectionId: '3',
        type: PlexMetadataType.album,
      );

      expect(genres.single.id, 7);
      expect(genres.single.field, 'genre');
    });

    test('reads a path-shaped key, as older servers send it', () async {
      final ctx = _makeApi(
        genreBody([
          {
            'key': '/library/sections/3/all?genre=11',
            'title': 'Folk',
          },
        ]),
      );

      final genres = await ctx.api.genres(
        sectionId: '3',
        type: PlexMetadataType.album,
      );

      expect(genres.single.id, 11);
      expect(genres.single.field, 'genre');
    });

    test('leaves id null when the server sends nothing usable', () async {
      final ctx = _makeApi(
        genreBody([
          {'title': 'Mystery'},
        ]),
      );

      final genres = await ctx.api.genres(
        sectionId: '3',
        type: PlexMetadataType.album,
      );

      expect(genres.single.id, isNull);
      expect(genres.single.field, 'genre');
    });

    test('requests the genre index for the given type', () async {
      final ctx = _makeApi(genreBody([]));
      await ctx.api.genres(sectionId: '3', type: PlexMetadataType.album);

      expect(
        ctx.adapter.lastRequest!.path,
        'http://192.168.1.10:32400/library/sections/3/genre',
      );
      expect(_query(ctx.adapter)['type'], '9');
    });

    test('a genre goes back out as the filter the server asked for', () async {
      final ctx = _makeApi(
        genreBody([
          {
            'fastKey': '/library/sections/3/all?genre=42&type=9',
            'title': 'Rock',
          },
        ]),
      );
      final genres = await ctx.api.genres(
        sectionId: '3',
        type: PlexMetadataType.album,
      );

      ctx.adapter.responseBody = _metadataBody();
      await ctx.api.allByType(
        sectionId: '3',
        type: PlexMetadataType.album,
        filters: [PlexFilter.of(genres.single)],
      );

      final uri = ctx.adapter.lastRequest!.uri;
      expect(uri.queryParameters['genre'], '42');
      expect(uri.queryParameters['type'], '9');
    });

    test('an unfilterable tag throws instead of querying unfiltered', () {
      const tag = PlexTag(title: 'Mystery', field: 'genre', raw: {});

      expect(
        () => PlexFilter.of(tag),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.parse),
        ),
      );
    });
  });

  group('PlexLibraryApi.filters', () {
    Map<String, dynamic> filtersBody() => {
          'MediaContainer': {
            'size': 2,
            'Directory': [
              {
                'filter': 'genre',
                'filterType': 'string',
                'key': '/library/sections/3/genre',
                'title': 'Genre',
                'type': 'filter',
              },
              {
                'filter': 'unwatched',
                'filterType': 'boolean',
                'title': 'Unplayed',
                'type': 'filter',
              },
            ],
          },
        };

    test('decodes each facet into its field, value type and values key',
        () async {
      final ctx = _makeApi(filtersBody());
      final facets = await ctx.api.filters(sectionId: '3');

      expect(facets, hasLength(2));
      final genre = facets.first;
      expect(genre.field, 'genre');
      expect(genre.title, 'Genre');
      expect(genre.valueType, PlexFilterValueType.string);
      expect(genre.valuesKey, '/library/sections/3/genre');

      final unwatched = facets.last;
      expect(unwatched.field, 'unwatched');
      expect(unwatched.valueType, PlexFilterValueType.boolean);
      expect(unwatched.valuesKey, isNull);
    });

    test('an unknown filterType degrades rather than throwing', () async {
      final ctx = _makeApi({
        'MediaContainer': {
          'size': 1,
          'Directory': [
            {'filter': 'addedAt', 'filterType': 'date', 'title': 'Added'},
          ],
        },
      });
      final facets = await ctx.api.filters(sectionId: '3');

      expect(facets.single.valueType, PlexFilterValueType.unknown);
      expect(facets.single.raw['filterType'], 'date');
    });
  });

  group('PlexLibraryApi.filterValues', () {
    test('follows the values endpoint the facet nominates', () async {
      final ctx = _makeApi({
        'MediaContainer': {
          'size': 1,
          'Directory': [
            {'key': '5', 'title': 'Melancholy'},
          ],
        },
      });

      const facet = PlexLibraryFilter(
        field: 'mood',
        title: 'Mood',
        valueType: PlexFilterValueType.string,
        valuesKey: '/library/sections/3/mood',
        raw: {},
      );
      final values = await ctx.api.filterValues(
        filter: facet,
        type: PlexMetadataType.track,
      );

      expect(
        ctx.adapter.lastRequest!.path,
        'http://192.168.1.10:32400/library/sections/3/mood',
      );
      expect(_query(ctx.adapter)['type'], '10');
      expect(values.single.id, 5);
      expect(values.single.field, 'mood');
    });

    test('keeps query parameters already baked into the values key', () async {
      final ctx = _makeApi({
        'MediaContainer': {'size': 0, 'Directory': <Map<String, dynamic>>[]},
      });

      const facet = PlexLibraryFilter(
        field: 'decade',
        title: 'Decade',
        valueType: PlexFilterValueType.integer,
        valuesKey: '/library/sections/3/decade?type=9',
        raw: {},
      );
      await ctx.api.filterValues(filter: facet);

      expect(
        ctx.adapter.lastRequest!.path,
        'http://192.168.1.10:32400/library/sections/3/decade',
      );
      expect(_query(ctx.adapter)['type'], '9');
    });

    test('throws when the facet lists no values endpoint', () async {
      final ctx = _makeApi();
      const facet = PlexLibraryFilter(
        field: 'unwatched',
        title: 'Unplayed',
        valueType: PlexFilterValueType.boolean,
        raw: {},
      );

      await expectLater(
        ctx.api.filterValues(filter: facet),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.state),
        ),
      );
    });
  });

  group('PlexLibraryApi.updateSectionItems', () {
    test('sends the write route\'s own plural "filters" expression', () async {
      final ctx = _makeApi();
      await ctx.api.updateSectionItems(
        sectionId: '3',
        type: 9,
        filterExpression: 'genre=6',
        changes: {'title.value': 'New title'},
      );

      final req = ctx.adapter.lastRequest!;
      expect(req.method, 'PUT');
      expect(req.uri.queryParameters['filters'], 'genre=6');
      expect(req.uri.queryParameters['title.value'], 'New title');
      expect(req.uri.queryParameters['type'], '9');
    });

    test('omits filters when no expression is given', () async {
      final ctx = _makeApi();
      await ctx.api.updateSectionItems(
        sectionId: '3',
        changes: {'title.value': 'New title'},
      );

      expect(
        ctx.adapter.lastRequest!.uri.queryParameters.containsKey('filters'),
        isFalse,
      );
    });
  });
}
