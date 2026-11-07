Create and close a client, choose its HTTP stack, sign in at plex.tv and connect to a server.

## Initialization and lifecycle

<img src="https://raw.githubusercontent.com/ales-drnz/dart_plex/main/imgs/diagrams/client_lifecycle.png" width="100%" alt="Client lifecycle: PlexClient, sign in and connect, sub-APIs, withCancelToken, close">

### Creating a client

```dart
final plex = PlexClient(
  credentials: const PlexCredentials(
    clientIdentifier: '2f5b-…-uuid',
    product: 'MyApp',
    version: '1.0.0',
    device: 'iPhone',
    deviceName: 'My iPhone',
    platform: 'iOS',
  ),
);
```

The other constructor arguments are optional:

| Argument | Default | Description |
| :--- | :--- | :--- |
| `httpClient` | a `dart:io` client owned by `PlexClient` | Any `http.Client`, see Choosing the HTTP stack below |
| `connectTimeout` | 15 s | The handshake (default client) and, with `receiveTimeout`, the wait for response headers |
| `receiveTimeout` | 30 s | Also bounds every pause inside a response body |
| `jsonIsolateThreshold` | 50 KB | Responses this large or larger are decoded and parsed on a background isolate |
| `retryPolicy` | `PlexRetryPolicy.none` | See [Errors and paging](https://pub.dev/documentation/dart_plex/latest/topics/Errors%20and%20paging-topic.html) |
| `tokenRenewer` | none | Renews a token refused with `401` or `498`, see When a token is refused below |

Above `jsonIsolateThreshold` the JSON decode and the walk that builds the
typed models both run on a background isolate, and so does the gzip
inflate of the default client. Pass `0` to send every response there, or
a very large value to keep everything on the calling isolate.

### Credentials

`PlexCredentials` describes the client. Every request carries the
matching `X-Plex-*` headers. `clientIdentifier` must be a stable UUID per
installation: generate it once, store it (SharedPreferences, Keychain,
Android Keystore) and reuse it. A new identifier invalidates the tokens
issued to the old one.

The optional fields:

| Field | Header |
| :--- | :--- |
| `platformVersion` | `X-Plex-Platform-Version` |
| `model` | `X-Plex-Model`, such as `'iPhone14,2'` |
| `deviceVendor` | `X-Plex-Device-Vendor`, such as `'Apple'` |
| `marketplace` | `X-Plex-Marketplace`, such as `'googlePlay'` |
| `clientProfileExtra` | `X-Plex-Client-Profile-Extra`: extra transcode targets for this client. `startAudioTranscode()` sends its own (see [Streaming](https://pub.dev/documentation/dart_plex/latest/topics/Streaming-topic.html)) |

`copyWith` returns a copy with some fields replaced.

### Choosing the HTTP stack

`PlexClient` speaks through `package:http`. Without an `httpClient` it
creates a `dart:io` client of its own. Inject another one to change the
stack, for example a `CupertinoClient` (`package:cupertino_http`) on
Apple platforms or a `CronetClient` (`package:cronet_http`) on Android,
for HTTP/2 and the system proxy:

```dart
final plex = PlexClient(
  credentials: credentials,
  httpClient: myHttpClient, // e.g. CupertinoClient.defaultSessionConfiguration()
);
```

Native clients inflate gzip on their own threads; the background isolate
still decodes and parses the JSON.

### Closing

```dart
plex.clearSession(); // drops the tokens and the JWT session, keeps the server
plex.disconnect();   // drops them and the server; the client stays usable
plex.close();        // releases the HTTP client
```

`close()` closes the HTTP client that `PlexClient` created. Requests made
afterwards fail with `PlexErrorType.state`. An injected `httpClient` stays
open: close it yourself.

### Faking the client in tests

The models are `final` classes, built only by the library. `PlexClient`
and the sub-API classes are open, so an app's tests can implement them
(`implements PlexClient`, `implements PlexLibraryApi`) or use a mocking
library. To test against canned HTTP answers, inject a `MockClient`:

```dart
import 'package:dart_plex/dart_plex.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final plex = PlexClient(
  credentials: credentials,
  httpClient: MockClient(
    (request) async => http.Response(
      '{"MediaContainer":{"size":0,"Directory":[]}}',
      200,
      headers: {'content-type': 'application/json'},
    ),
  ),
  jsonIsolateThreshold: 0, // parse every response off the calling isolate too
);
```

## Sign-in and server discovery

<img src="https://raw.githubusercontent.com/ales-drnz/dart_plex/main/imgs/diagrams/sign_in_flow.png" width="100%" alt="Sign-in: createJwtPin with the device key, the user signs in at the Auth App, pollJwtPin until a JWT, useJwt; then fetchResources and connectToResource">

Sign-in talks to plex.tv and returns a token. Two tokens matter
afterwards: the account token (`plex.accountToken`), sent to plex.tv, and
the server's (`plex.token`), sent to the server you connect to. Neither
is assumed to last.

### JWT sign-in (new apps)

plex.tv signs a device in with an Ed25519 key pair instead of a password
or a long-lived token: the device registers the public key once, then
asks for a JWT that lasts 7 days and can be refreshed at any time, also
after it has expired, by signing a short-lived request with the private
key. Generate the key once per install:

```dart
final key = await PlexDeviceKey.generate();
var pin = await plex.account.createJwtPin(key: key);
launchUrl(Uri.parse(plex.account.authAppUrl(pin))); // the user signs in there

while (!pin.isAuthenticated) {
  await Future<void>.delayed(const Duration(seconds: 1));
  pin = await plex.account.pollJwtPin(id: pin.id, key: key);
  if (pin.isExpired) throw StateError('PIN expired');
}

final session = PlexJwtSession(
  key: key,
  token: PlexJwt.parse(pin.authToken!),
  onChanged: (s) => secureStorage.write('plex', jsonEncode(s.toJson())),
);
session.onChanged!(session);
await plex.useJwt(session);
```

`createJwtPin` sends the public key with a strong PIN, whose code is for
the Auth App URL (`authAppUrl`); pass `strong: false` for a 4-character
code to type at `plex.tv/link`. `pollJwtPin` signs a device JWT (with a
nonce, reused across polls while it is valid) and answers the plex.tv JWT
once the user has signed in.

`useJwt` makes the session's token the account token (and the server
token, while there is none) and keeps it fresh: before a plex.tv call when
it expires within a day (`PlexJwtSession.refreshBefore`), and after
plex.tv or a server refuses it with `401` or `498` ("token expired"). A
token received in this run is timed from its arrival, by its
`exp - iat`, so a device clock that disagrees with plex.tv's does not
refresh it on every call; a token issued for less than two days is
refreshed at half its lifetime. Each new token goes to `onChanged`:
persist the session there. If `onChanged` throws, the refresh fails with
a `PlexException` and the new token is kept. A refreshed token bound to
another key (its `thumbprint` is not the key's `keyId`) is refused.
When the first refresh in `useJwt` fails, the client is left as it was.
On the next start, read the session back and hand it to the client:

```dart
final session = await PlexJwtSession.fromJson(
  jsonDecode(await secureStorage.read('plex')) as Map<String, Object?>,
  onChanged: (s) => secureStorage.write('plex', jsonEncode(s.toJson())),
);
await plex.useJwt(session); // refreshes now if the token is old
```

`toJson()` holds the private key: store it where the platform keeps
secrets. The signing is pure Dart (`package:cryptography`), the same on
every platform including the web. `PlexJwt` reads a token's claims
(`expiresAt`, `issuedAt`, `thumbprint`) without verifying them: the token
came from plex.tv over HTTPS, and plex.tv and the servers check it.

The steps are also available one by one: `authNonce()`,
`PlexDeviceKey.deviceJwt()`, `exchangeDeviceJwt()`, and `refreshJwt()`
for all three.

### Moving a legacy token to JWT

An app that already holds a legacy token registers the key with it, then
refreshes for the first JWT. Plex's documentation says the legacy token
stops working once the device has a JWT.

```dart
final key = await PlexDeviceKey.generate();
await plex.account.registerJwtKey(key: key, token: legacyToken);
final session = PlexJwtSession(key: key, onChanged: save);
await plex.useJwt(session); // no token yet: refreshJwt runs now
```

### When a token is refused

`plex.tokenRenewer` is called with the refused token when a request gets
`401` or `498`; the request is retried once with the token it returns, or
fails with it when it returns `null`. Concurrent refusals share one call.
`useJwt` installs one that refreshes the JWT; set your own to renew
tokens another way, for example by asking the user to sign in again.

Only the client's own token is renewed. A request that sets
`X-Plex-Token` in `extraHeaders` (another token, or `''` for none, as the
sign-in calls and the connection probes do) is not, and neither is a
request the renewer makes. A plex.tv call that sends the account token
apart from the server's retries once itself after a fresh JWT.

### Legacy PIN flow

`createPin()` and `pollPin()` end with a legacy token, which does not
expire:

```dart
final pin = await plex.account.createPin(strong: false);
print('Open https://plex.tv/link and enter ${pin.code}');

while (true) {
  await Future<void>.delayed(const Duration(seconds: 2));
  final fresh = await plex.account.pollPin(id: pin.id);
  if (fresh.isAuthenticated) {
    plex.setToken(fresh.authToken);
    break;
  }
  if (fresh.isExpired) throw StateError('PIN expired');
}
```

### Username and password

```dart
final user = await plex.account.signInWithPassword(
  username: 'me@example.com',
  password: 'hunter2',
);
plex.setToken(user.authToken);
```

Accounts with two-factor authentication cannot use this flow; prefer a
PIN. Bad credentials throw a `PlexException` of type `auth`.

### Account and sign-out

```dart
final me = await plex.account.currentUser();
print('${me.username} (${me.email}), Plex Pass: ${me.hasPlexPass}');

await plex.account.signOut(); // invalidates the token at plex.tv
plex.clearSession();
```

`PlexUser` carries `id`, `uuid`, `username`, `email`, `thumb`,
`authToken`, `hasPlexPass`, `restricted`, `home`, `homeAdmin`,
`protected`, `subscriptionFeatures` and `raw`. `tokenDetails()` is the
user the server token belongs to.

### Plex Home, friends, watchlist

```dart
final home = await plex.account.homeUsers();     // PlexHomeUser
final kids = await plex.account.managedUsers();  // the restricted ones
final kid = await plex.account.switchHomeUser(userId: kids.first.id, pin: '1234');
plex.setAccountToken(kid.authToken);              // plex.tv calls as that user

final users = await plex.account.connectedUsers(); // shares, per server
final friends = await plex.account.friends();
final where = await plex.account.geoip();
```

`homeUsers`, `switchHomeUser` and `connectedUsers` read the routes
python-plexapi reads (`plex.tv/api/home/users`, `…/switch`,
`plex.tv/api/users/`), which plex.tv answers in XML; the package reads the
XML into the same models. After a switch, fetch the servers again: they
come with that user's tokens.

The watchlist lives on Plex's discover provider, with plex.tv's own
metadata:

```dart
final page = await plex.account.watchlist(
  filter: PlexWatchlistFilter.released,
  sort: PlexSort.watchlistedAt.desc,
  type: PlexMetadataType.movie,
);
final key = PlexAccountApi.discoverKeyOf(page.items.first.guid!);
await plex.account.removeFromWatchlist(ratingKey: key);
```

### Finding servers

```dart
final servers = await plex.account.fetchResources();
final server = servers.firstWhere((s) => s.owned);
```

`includeHttps`, `includeRelay` and `includeIPv6` are on by default.
`serverOnly` (on by default) keeps the resources that provide `server`,
leaving out players and clients.

Each `PlexResource` carries `name`, `clientIdentifier`, `platform`,
`productVersion`, `owned`, `home`, `relay`, `presence`, `httpsRequired`,
`accessToken` (the token for that server), `connections` and `raw`.

`rankedConnections()` orders the connections as python-plexapi does:
local before remote before relay, HTTPS before HTTP, IPv4 before IPv6,
leaving out the local addresses of a server you neither own nor share a
Home with. `bestConnection()` is the first of them, unchecked.

Each `PlexServerConnection` has `protocol`, `address`, `port`, `uri`,
`local`, `relay`, `ipv6`, `kind` (`PlexConnectionKind.local`, `remote` or
`relay`) and `httpUri`. An IPv6 `uri` is bracketed
(`http://[2001:db8::2]:32400`) even when plex.tv sent it without.

### Connecting to a server

```dart
final connection = await plex.connectToResource(server);
print('${connection.uri} (${plex.connectionKind})');
```

`connectToResource` tries every ranked connection at once
(`GET /identity`, which needs no token, checking the machine identifier),
takes the best-ranked one that answers within `timeout` (10 s) without
waiting for worse ones once it has, connects with the resource's
`accessToken`, and checks the token on the server. `findConnection` does
the first part alone.

A connection counts only when its server reports the resource's machine
identifier, so the token never goes to another host that answers. When
the server refuses the resource's token with `401`, the token
`account.devices()` lists for that server is tried instead. When no
token works, the call throws and the client keeps its previous server,
connection and tokens.

For an owned server the resource's token can be the account's JWT;
`useJwt` then renews it on the server too. Whether plex.tv lists a device
token for every account is not documented: the fallback is a best
effort.

`connect()` and `connectTo()` remain for a URL or a connection you chose:

```dart
plex.connectTo(server.rankedConnections().first, accessToken: server.accessToken);
plex.connect('http://[fd00::12]:32400', accessToken: server.accessToken);
```

With an `accessToken`, the token it replaces stays the account token for
plex.tv calls. `connectionKind` is `null` after a plain `connect()`. A
client talks to one server at a time; connect again to switch, or create
a second `PlexClient` with the same credentials to keep two servers.
