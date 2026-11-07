// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Reaching a server from its plex.tv resource: the connections' kinds
/// and ranking, the parallel `/identity` probes, and `connectToResource`
/// with its token checks.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dart_plex/dart_plex.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

Map<String, Object?> _conn(
  String uri, {
  bool local = false,
  bool relay = false,
  bool ipv6 = false,
  String protocol = 'https',
  String address = '1.2.3.4',
}) => {
  'protocol': protocol,
  'address': address,
  'port': 32400,
  'uri': uri,
  'local': local,
  'relay': relay,
  'IPv6': ipv6,
};

PlexResource _resource(
  List<Map<String, Object?>> connections, {
  bool owned = true,
}) => PlexResource.fromJson({
  'name': 'Home',
  'clientIdentifier': 'machine-1',
  'provides': 'server',
  'accessToken': 'server-token',
  'owned': owned,
  'connections': connections,
});

/// Answers `/identity` per host, after a delay, or fails.
class _Hosts extends http.BaseClient {
  final Map<String, (Duration, String?)> hosts;
  final List<Uri> asked = [];
  _Hosts(this.hosts);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    asked.add(request.url);
    final entry = hosts[request.url.host];
    if (entry == null) throw http.ClientException('unreachable', request.url);
    await Future<void>.delayed(entry.$1);
    final id = entry.$2;
    if (id == null) throw http.ClientException('refused', request.url);
    final body = utf8.encode(
      jsonEncode({
        'MediaContainer': {'machineIdentifier': id},
      }),
    );
    return http.StreamedResponse(
      Stream.value(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('PlexServerConnection', () {
    test('kind: local, remote, relay', () {
      expect(
        PlexServerConnection.fromJson(_conn('https://a', local: true)).kind,
        PlexConnectionKind.local,
      );
      expect(
        PlexServerConnection.fromJson(_conn('https://a')).kind,
        PlexConnectionKind.remote,
      );
      expect(
        PlexServerConnection.fromJson(_conn('https://a', relay: true)).kind,
        PlexConnectionKind.relay,
      );
    });

    test('an unbracketed IPv6 uri is bracketed; httpUri too', () {
      final c = PlexServerConnection.fromJson(
        _conn(
          'http://2001:db8::2:32400',
          protocol: 'http',
          address: '2001:db8::2',
          ipv6: true,
        ),
      );
      expect(c.uri, 'http://[2001:db8::2]:32400');
      expect(c.httpUri, 'http://[2001:db8::2]:32400');
      expect(c.ipv6, isTrue);
      expect(Uri.parse(c.uri).host, '2001:db8::2');
    });

    test('bracketIpv6 leaves good URLs alone', () {
      for (final url in [
        'http://[2001:db8::2]:32400',
        'https://1-2-3-4.abc.plex.direct:32400',
        'http://192.168.1.2:32400/x',
      ]) {
        expect(PlexServerConnection.bracketIpv6(url), url);
      }
      expect(
        PlexServerConnection.bracketIpv6('http://fe80:0:0:0:0:0:0:1:32400/a'),
        'http://[fe80:0:0:0:0:0:0:1]:32400/a',
      );
    });

    test(
      'connect() takes an IPv6 base URL and builds requests on it',
      () async {
        final adapter = CapturingAdapter({
          'MediaContainer': {'size': 0},
        });
        final plex = testClient(adapter)..connect('http://2001:db8::5:32400');
        expect(plex.baseUrl, 'http://[2001:db8::5]:32400');
        await plex.library.sections();
        expect(adapter.last!.uri.host, '2001:db8::5');
        expect(adapter.last!.uri.port, 32400);
      },
    );
  });

  group('PlexResource.rankedConnections', () {
    test('local, then remote, then relay; https before http; IPv4 first', () {
      final r = _resource([
        _conn('https://relay', relay: true),
        _conn('http://remote-http', protocol: 'http'),
        _conn('https://remote-v6', ipv6: true, address: '2001:db8::1'),
        _conn('https://remote-v4'),
        _conn('http://local-http', local: true, protocol: 'http'),
        _conn('https://local', local: true),
      ]);
      expect(r.rankedConnections().map((c) => c.uri), [
        'https://local',
        'http://local-http',
        'https://remote-v4',
        'https://remote-v6',
        'http://remote-http',
        'https://relay',
      ]);
      expect(r.bestConnection()!.uri, 'https://local');
    });

    test("a friend's server: its local addresses are left out", () {
      final r = _resource([
        _conn('https://local', local: true),
        _conn('https://remote'),
      ], owned: false);
      expect(r.rankedConnections().map((c) => c.uri), ['https://remote']);
    });
  });

  group('findConnection / connectToResource', () {
    final resource = _resource([
      _conn('https://local.example:32400', local: true),
      _conn('https://remote.example:32400'),
      _conn('https://relay.example:443', relay: true),
    ]);

    PlexClient client(http.Client http) =>
        PlexClient(credentials: testCredentials, httpClient: http);

    test('waits for the best one when it answers', () async {
      final hosts = _Hosts({
        'local.example': (const Duration(milliseconds: 60), 'machine-1'),
        'remote.example': (Duration.zero, 'machine-1'),
        'relay.example': (Duration.zero, 'machine-1'),
      });
      final picked = await client(hosts).account.findConnection(resource);
      expect(picked!.uri, 'https://local.example:32400');
      expect(hosts.asked, hasLength(3), reason: 'probed in parallel');
      expect(hosts.asked.every((u) => u.path == '/identity'), isTrue);
    });

    test('falls back past an unreachable or foreign server', () async {
      final hosts = _Hosts({
        'local.example': (Duration.zero, null),
        'remote.example': (Duration.zero, 'another-machine'),
        'relay.example': (Duration.zero, 'machine-1'),
      });
      final picked = await client(hosts).account.findConnection(resource);
      expect(picked!.kind, PlexConnectionKind.relay);
    });

    test('at the timeout, the best that answered so far', () async {
      final hosts = _Hosts({
        'local.example': (const Duration(seconds: 5), 'machine-1'),
        'remote.example': (Duration.zero, 'machine-1'),
      });
      final picked = await client(hosts).account.findConnection(
        resource,
        timeout: const Duration(milliseconds: 100),
      );
      expect(picked!.uri, 'https://remote.example:32400');
    });

    test('a host that answers without a machine identifier does not '
        'count', () async {
      final adapter = CapturingAdapter({'MediaContainer': <String, Object?>{}});
      final picked = await client(adapter).account.findConnection(resource);
      expect(picked, isNull);
    });

    test('a 401 from a probe never asks the account renewer', () async {
      final adapter = CapturingAdapter()
        ..respond = (_) => CannedResponse(401, const []);
      var renewed = 0;
      final plex = client(adapter)
        ..setToken('account-token')
        ..tokenRenewer = (_) async {
          renewed++;
          return 'other';
        };
      expect(await plex.account.findConnection(resource), isNull);
      expect(renewed, 0);
    });

    test('a failed check leaves the client as it was', () async {
      final adapter = CapturingAdapter();
      adapter.respond = (r) {
        if (r.uri.path == '/identity') {
          return CannedResponse.json({
            'MediaContainer': {'machineIdentifier': 'machine-1'},
          });
        }
        if (r.uri.path == '/api/v2/devices') {
          return CannedResponse.json([
            {'clientIdentifier': 'machine-1', 'token': 'device-token'},
          ]);
        }
        return CannedResponse(401, const []);
      };
      final plex = client(adapter)
        ..connect('http://10.0.0.9:32400', accessToken: 'old-token');
      await expectLater(
        plex.connectToResource(resource),
        throwsA(isA<PlexException>().having((e) => e.statusCode, 'st', 401)),
      );
      expect(plex.baseUrl, 'http://10.0.0.9:32400');
      expect(plex.token, 'old-token');
      expect(plex.accountToken, 'old-token');
      expect(plex.connection, isNull);
      // The fallback token was tried.
      expect(adapter.requests.last.headers['X-Plex-Token'], 'device-token');
    });

    test('null when nothing answers', () async {
      final picked = await client(_Hosts({})).account.findConnection(resource);
      expect(picked, isNull);
    });

    test('connectToResource connects with the resource token and records the '
        'kind', () async {
      final adapter = CapturingAdapter();
      adapter.respond = (r) => CannedResponse.json({
        'MediaContainer': {'machineIdentifier': 'machine-1'},
      });
      final plex = client(adapter)..setToken('account-token');
      final picked = await plex.connectToResource(resource);
      expect(picked.kind, PlexConnectionKind.local);
      expect(plex.connectionKind, PlexConnectionKind.local);
      expect(plex.baseUrl, 'https://local.example:32400');
      expect(plex.token, 'server-token');
      expect(plex.accountToken, 'account-token');
      final verify = adapter.requests.last;
      expect(verify.uri.path, '/');
      expect(verify.headers['X-Plex-Token'], 'server-token');
      // The identity probes carry no token.
      expect(
        adapter.requests
            .where((r) => r.uri.path == '/identity')
            .every((r) => !r.headers.containsKey('X-Plex-Token')),
        isTrue,
      );
    });

    test(
      'a 401 on the resource token falls back to the devices token',
      () async {
        final adapter = CapturingAdapter();
        adapter.respond = (r) {
          if (r.uri.path == '/identity') {
            return CannedResponse.json({
              'MediaContainer': {'machineIdentifier': 'machine-1'},
            });
          }
          if (r.uri.host == 'plex.tv' && r.uri.path == '/api/v2/devices') {
            expect(r.headers['X-Plex-Token'], 'account-token');
            return CannedResponse.json([
              {'clientIdentifier': 'other', 'token': 'nope'},
              {
                'name': 'Home',
                'clientIdentifier': 'machine-1',
                'provides': 'server',
                'token': 'legacy-server-token',
              },
            ]);
          }
          return r.headers['X-Plex-Token'] == 'legacy-server-token'
              ? CannedResponse.json({'MediaContainer': <String, Object?>{}})
              : CannedResponse(401, const []);
        };
        final plex = client(adapter)..setToken('account-token');
        await plex.connectToResource(resource);
        expect(plex.token, 'legacy-server-token');
        expect(plex.accountToken, 'account-token');
      },
    );

    test('no connection answering is a connection error', () async {
      await expectLater(
        client(_Hosts({})).connectToResource(
          resource,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(
          isA<PlexException>().having(
            (e) => e.type,
            'type',
            PlexErrorType.connection,
          ),
        ),
      );
    });
  });

  group('connect and the account token', () {
    test(
      'connect(accessToken:) keeps the previous token for plex.tv',
      () async {
        final adapter = CapturingAdapter({'id': 1});
        final plex =
            PlexClient(credentials: testCredentials, httpClient: adapter)
              ..setToken('account')
              ..connect('http://10.0.0.1:32400', accessToken: 'server');
        expect(plex.token, 'server');
        expect(plex.accountToken, 'account');
        await plex.account.currentUser();
        expect(adapter.last!.headers['X-Plex-Token'], 'account');
        await plex.account.tokenDetails();
        expect(adapter.last!.headers['X-Plex-Token'], 'server');
        plex.clearSession();
        expect(plex.token, isNull);
        expect(plex.accountToken, isNull);
      },
    );
  });
}
