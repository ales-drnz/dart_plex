// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The plex.tv account API on the wire. The live counterpart is
/// `test/integration/account_integration_test.dart`, which needs a real
/// plex.tv account.
library;

import 'dart:convert';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

void main() {
  late CapturingAdapter adapter;
  late PlexClient plex;

  setUp(() {
    adapter = CapturingAdapter({
      'user': {'id': 1, 'username': 'me', 'authToken': 'new-token'},
    });
    plex = PlexClient(credentials: testCredentials, httpClient: adapter);
  });

  test('signInWithPassword posts a form body, as 0.1 did', () async {
    final user = await plex.account.signInWithPassword(
      username: 'me@example.com',
      password: 'p&ss word',
    );
    final req = adapter.last!;
    expect(req.method, 'POST');
    expect(req.uri.toString(), 'https://plex.tv/users/sign_in.json');
    expect(
      req.headers['Content-Type'],
      'application/x-www-form-urlencoded',
    );
    expect(
      utf8.decode(req.body),
      'user%5Blogin%5D=me%40example.com&user%5Bpassword%5D=p%26ss+word',
    );
    expect(Uri.splitQueryString(utf8.decode(req.body)), {
      'user[login]': 'me@example.com',
      'user[password]': 'p&ss word',
    });
    expect(user.authToken, 'new-token');
  });

  test('signInWithPassword leaves the client token to the caller', () async {
    await plex.account.signInWithPassword(username: 'me', password: 'pw');
    expect(plex.isAuthenticated, isFalse);
    await plex.account.currentUser();
    expect(adapter.last!.headers.containsKey('X-Plex-Token'), isFalse);
  });

  test('a sign-in answer without a token is an auth error', () async {
    adapter.responseBody = {
      'user': {'id': 1},
    };
    await expectLater(
      plex.account.signInWithPassword(username: 'me', password: 'pw'),
      throwsA(
        isA<PlexException>().having((e) => e.type, 'type', PlexErrorType.auth),
      ),
    );
  });
}
