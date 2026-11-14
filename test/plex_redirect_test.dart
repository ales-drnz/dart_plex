// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

// Redirects on the default `dart:io` client, against real local servers:
// `dart:io` copies every header but `Authorization` and `Cookie` to the
// host a redirect names, so the connection follows redirects itself.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_plex/dart_plex.dart';
import 'package:dart_plex/io.dart';
import 'package:dart_plex/src/plex_connection.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

const _token = 'server-token';

/// What one request looked like to the server that got it.
typedef _Seen = ({String method, String path, HttpHeaders headers, int body});

void main() {
  late HttpServer pms;
  late HttpServer third;
  late List<_Seen> atPms;
  late List<_Seen> atThird;
  late PlexClient client;

  String thirdUrl(String path) => 'http://localhost:${third.port}$path';
  String pmsUrl(String path) => 'http://127.0.0.1:${pms.port}$path';

  Future<void> answer(HttpRequest req, List<_Seen> log) async {
    final body = await req.fold<int>(0, (n, chunk) => n + chunk.length);
    log.add((
      method: req.method,
      path: req.uri.path,
      headers: req.headers,
      body: body,
    ));
    final res = req.response;
    final path = req.uri.path;
    final to = req.uri.queryParameters['to'];
    if (path.startsWith('/redirect/')) {
      res.statusCode = int.parse(path.split('/')[2]);
      if (to != null) res.headers.set('location', to);
      res.write('moved');
    } else if (path.startsWith('/chain/')) {
      final left = int.parse(path.split('/')[2]);
      if (left > 0) {
        res.statusCode = 302;
        res.headers.set('location', '/chain/${left - 1}');
      } else {
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode({'landed': 'chain'}));
      }
    } else if (path == '/loop') {
      res.statusCode = 302;
      res.headers.set('location', '/loop');
    } else {
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode({'landed': path, 'method': req.method}));
    }
    await res.close();
  }

  setUp(() async {
    atPms = [];
    atThird = [];
    pms = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    pms.listen((req) => answer(req, atPms));
    // Another origin twice over: another port, reached under another name.
    third = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    third.listen((req) => answer(req, atThird));
    client = PlexClient(credentials: testCredentials)
      ..connect(pmsUrl(''), accessToken: _token);
  });

  tearDown(() async {
    client.close();
    await pms.close(force: true);
    await third.close(force: true);
  });

  String redirect(int status, String to) =>
      '/redirect/$status?to=${Uri.encodeQueryComponent(to)}';

  group('a redirect to another host', () {
    for (final status in [301, 302, 303, 307, 308]) {
      test('$status: followed, without the token', () async {
        final res = await client.request<Map<String, Object?>>(
          redirect(status, thirdUrl('/landed')),
        );

        expect(res.data, {'landed': '/landed', 'method': 'GET'});
        expect(atPms.single.headers.value('x-plex-token'), _token);
        final hop = atThird.single;
        expect(hop.headers.value('x-plex-token'), isNull);
        // The identity still goes, as it does on a direct request there.
        expect(
          hop.headers.value('x-plex-client-identifier'),
          testCredentials.clientIdentifier,
        );
        expect(hop.headers.value('accept'), 'application/json');
      });
    }

    test('another port of the same host is another host', () async {
      await client.request<Object>(
        redirect(302, 'http://127.0.0.1:${third.port}/landed'),
      );

      expect(atThird.single.headers.value('x-plex-token'), isNull);
    });

    test('a POST answered 303 becomes a GET there, without the token '
        'or the body', () async {
      final res = await client.request<Map<String, Object?>>(
        redirect(303, thirdUrl('/landed')),
        method: 'POST',
        data: {'a': 1},
      );

      expect(res.data, {'landed': '/landed', 'method': 'GET'});
      expect(atPms.single.body, greaterThan(0));
      final hop = atThird.single;
      expect(hop.method, 'GET');
      expect(hop.body, 0);
      expect(hop.headers.value('x-plex-token'), isNull);
    });

    test('requestBytes', () async {
      final res = await client.requestBytes(
        redirect(302, thirdUrl('/landed')),
        absoluteUrl: false,
      );

      expect(utf8.decode(res.data!), contains('landed'));
      expect(atThird.single.headers.value('x-plex-token'), isNull);
    });

    test('requestStream', () async {
      final res = await client.requestStream(
        redirect(302, thirdUrl('/landed')),
        absoluteUrl: false,
      );

      expect(await utf8.decodeStream(res.stream), contains('landed'));
      expect(atThird.single.headers.value('x-plex-token'), isNull);
    });

    test('downloadToFile', () async {
      final dir = await Directory.systemTemp.createTemp('redirect_test');
      addTearDown(() => dir.delete(recursive: true));

      await client.downloadToFile(
        pmsUrl(redirect(302, thirdUrl('/landed'))),
        '${dir.path}/file',
      );

      expect(File('${dir.path}/file').readAsStringSync(), contains('landed'));
      expect(atThird.single.headers.value('x-plex-token'), isNull);
    });

    test('a token, an Authorization and a Cookie named in the extra '
        'headers stay behind; other extra headers go on', () async {
      await client.request<Object>(
        redirect(302, thirdUrl('/landed')),
        extraHeaders: const {
          'X-Plex-Token': 'account-token',
          'Authorization': 'Bearer secret',
          'Cookie': 'session=secret',
          'X-Plex-Language': 'it',
        },
      );

      expect(atPms.single.headers.value('x-plex-token'), 'account-token');
      final hop = atThird.single.headers;
      expect(hop.value('x-plex-token'), isNull);
      expect(hop.value('authorization'), isNull);
      expect(hop.value('cookie'), isNull);
      expect(hop.value('x-plex-language'), 'it');
    });

    test('a request sent without the token stays without it', () async {
      await client.request<Object>(
        redirect(302, thirdUrl('/landed')),
        extraHeaders: const {'X-Plex-Token': ''},
      );

      expect(atPms.single.headers.value('x-plex-token'), isNull);
      expect(atThird.single.headers.value('x-plex-token'), isNull);
    });

    test('and back: the token is not picked up again at the server', () async {
      // server → third → server: the last hop was chosen by the third
      // host, which must not be able to aim the token at a path.
      await client.request<Object>(
        redirect(302, thirdUrl(redirect(302, pmsUrl('/library/sections')))),
      );

      expect(atPms, hasLength(2));
      expect(atPms.first.headers.value('x-plex-token'), _token);
      expect(atPms.last.path, '/library/sections');
      expect(atPms.last.headers.value('x-plex-token'), isNull);
    });

    test('a full URL to another host that redirects to the server does '
        'not get the token there', () async {
      await client.request<Object>(
        thirdUrl(redirect(302, pmsUrl('/library/sections'))),
        absoluteUrl: true,
      );

      expect(atThird.single.headers.value('x-plex-token'), isNull);
      expect(atPms.single.headers.value('x-plex-token'), isNull);
    });
  });

  group('a redirect within the server', () {
    test('keeps the token and the extra headers', () async {
      final res = await client.request<Map<String, Object?>>(
        redirect(302, '/landed'),
        extraHeaders: const {'Authorization': 'Bearer own'},
      );

      expect(res.data, {'landed': '/landed', 'method': 'GET'});
      expect(atPms, hasLength(2));
      expect(atPms.last.headers.value('x-plex-token'), _token);
      expect(atPms.last.headers.value('authorization'), 'Bearer own');
      expect(atThird, isEmpty);
    });

    test('a relative location resolves against the redirecting URL; the '
        'response names the URL that was asked for', () async {
      final res = await client.request<Object>(
        '/redirect/302?to=..%2Flanded%3Fx%3D1',
      );

      expect(atPms.last.path, '/landed');
      expect(res.uri.path, '/redirect/302');
    });

    test('five redirects are followed, a sixth is not', () async {
      final res = await client.request<Object>('/chain/5');
      expect(res.data, {'landed': 'chain'});

      await expectLater(
        client.request<Object>('/chain/6'),
        throwsA(
          isA<PlexException>()
              .having((e) => e.message, 'message', contains('limit'))
              .having((e) => e.statusCode, 'statusCode', 302)
              .having((e) => e.type, 'type', PlexErrorType.unknown),
        ),
      );
    });

    test('a loop is an error, not retried as a lost connection', () async {
      await expectLater(
        client.request<Object>('/loop'),
        throwsA(
          isA<PlexException>()
              .having((e) => e.message, 'message', contains('loop'))
              .having((e) => e.type, 'type', PlexErrorType.unknown),
        ),
      );
    });

    test('a redirect without a location is the status it is', () async {
      await expectLater(
        client.request<Object>('/redirect/302'),
        throwsA(
          isA<PlexException>().having((e) => e.statusCode, 'statusCode', 302),
        ),
      );
    });

    test('a location that is not a URL, or not http, is an error', () async {
      for (final to in ['http://[::bad', 'file:///etc/passwd']) {
        await expectLater(
          client.request<Object>(redirect(302, to)),
          throwsA(
            isA<PlexException>()
                .having((e) => e.statusCode, 'statusCode', 302)
                .having((e) => e.type, 'type', PlexErrorType.unknown),
          ),
          reason: to,
        );
      }
    });

    for (final method in ['POST', 'PUT', 'DELETE']) {
      test('$method is not replayed on a 302 or a 307', () async {
        for (final status in [302, 307]) {
          atPms.clear();
          await expectLater(
            client.request<Object>(
              redirect(status, thirdUrl('/landed')),
              method: method,
            ),
            throwsA(
              isA<PlexException>().having(
                (e) => e.statusCode,
                'statusCode',
                status,
              ),
            ),
          );
          expect(atPms, hasLength(1));
          expect(atThird, isEmpty);
        }
      });
    }
  });

  group('which redirects keep the credentials', () {
    late PlexConnection http_;
    setUp(() {
      http_ = PlexConnection(credentials: testCredentials)
        ..baseUrl = 'https://192-168-1-5.abc.plex.direct:32400'
        ..token = _token;
    });
    tearDown(() => http_.close());

    bool keeps(String from, String to) =>
        http_.keepsCredentialsOnRedirect(Uri.parse(from), Uri.parse(to));

    test('the same origin', () {
      expect(keeps('https://cdn.example/a', 'https://cdn.example/b'), isTrue);
    });

    test('the server to itself, also from http up to https', () {
      const host = '192-168-1-5.abc.plex.direct:32400';
      expect(keeps('http://$host/a', 'https://$host/a'), isTrue);
      expect(keeps('https://$host/a', 'http://$host/a'), isFalse);
      expect(keeps('https://$host/a', 'https://192.168.1.5:32400/a'), isFalse);
      expect(
        keeps('https://$host/a', 'https://192-168-1-5.abc.plex.direct/a'),
        isFalse,
        reason: 'another port',
      );
    });

    test('plex.tv to plex.tv and its subdomains, never down to http', () {
      expect(keeps('http://plex.tv/a', 'https://plex.tv/a'), isTrue);
      expect(keeps('https://plex.tv/a', 'https://clients.plex.tv/a'), isTrue);
      expect(keeps('https://plex.tv/a', 'http://plex.tv/a'), isFalse);
      expect(
        keeps(
          'https://plex.tv/users/x/avatar',
          'https://secure.gravatar.com/a',
        ),
        isFalse,
      );
      expect(
        keeps('https://plex.tv/a', 'https://plex.tv.evil.example/a'),
        isFalse,
      );
      expect(keeps('https://plex.tv/a', 'https://notplex.tv/a'), isFalse);
    });

    test('never from the server to plex.tv or back', () {
      const server = 'https://192-168-1-5.abc.plex.direct:32400/a';
      expect(keeps(server, 'https://plex.tv/a'), isFalse);
      expect(keeps('https://plex.tv/a', server), isFalse);
    });
  });

  test('a client handed to PlexClient is told not to follow redirects, '
      'so that the connection does', () async {
    final seen = <http.BaseRequest>[];
    final custom = _Recording(seen);
    final c = PlexClient(credentials: testCredentials, httpClient: custom)
      ..connect('http://pms.test:32400', accessToken: _token);
    addTearDown(c.close);

    await c.request<Object>('/redirect');

    expect(seen, hasLength(2));
    expect(seen.every((r) => !r.followRedirects), isTrue);
    expect(seen.first.headers['X-Plex-Token'], _token);
    expect(seen.last.url.host, 'cdn.example');
    expect(
      seen.last.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('x-plex-token')),
    );
  });
}

/// An `http.Client` that answers a redirect to another host, then `{}`.
final class _Recording extends http.BaseClient {
  final List<http.BaseRequest> seen;
  _Recording(this.seen);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    seen.add(request);
    await request.finalize().drain<void>();
    return request.url.host == 'pms.test'
        ? http.StreamedResponse(
            const Stream.empty(),
            302,
            headers: {'location': 'https://cdn.example/poster.jpg'},
          )
        : http.StreamedResponse(
            Stream.value(utf8.encode('{}')),
            200,
            headers: {'content-type': 'application/json'},
          );
  }
}
