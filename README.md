# dart_plex

#### Plex Media Server client for Flutter and Dart.

[![](https://img.shields.io/pub/v/dart_plex.svg?style=for-the-badge&logo=dart&logoColor=white)](https://pub.dev/packages/dart_plex)
[![](https://img.shields.io/badge/PMS-1.43.x-orange.svg?style=for-the-badge)](https://plexapi.dev)
[![](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg?style=for-the-badge)](LICENSE)
[![](https://img.shields.io/github/stars/ales-drnz/dart_plex?style=for-the-badge&logo=github&logoColor=white)](https://github.com/ales-drnz/dart_plex)
[![](https://img.shields.io/discord/1485588004029333516?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/g2Qf4Mq9MP)
[![](https://img.shields.io/badge/Patreon-F96854?style=for-the-badge&logo=patreon&logoColor=white)](https://www.patreon.com/cw/ales_drnz)
[![](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/ales.drnz)

<table>
<tr>
<td valign="middle" width="90"><img src="https://raw.githubusercontent.com/ales-drnz/dart_plex/main/imgs/dart_plex.png" width="70" alt="logo"></td>
<td valign="middle"><code>dart_plex</code> is a Dart client for Plex Media Server <code>v1.43.x</code>. It covers libraries, hubs, playlists, audio streaming and transcoding, playback reporting, search, play queues and server notifications through typed Dart objects, and handles plex.tv sign-in and server discovery. It runs on <code>package:http</code>, so you choose the HTTP stack, and every call can be cancelled.</td>
</tr>
</table>

---

## Installation

Add `dart_plex` to your `pubspec.yaml`:

```yaml
dependencies:
  dart_plex: ^0.2.0
```

`package:dart_plex/dart_plex.dart` is the library. File downloads live in a
separate entrypoint, `package:dart_plex/io.dart`, because they need
`dart:io` ([22](#22-downloads)).

Coming from 0.1.x? [MIGRATION.md](MIGRATION.md) lists every breaking change
with what to write instead.

---

## Contents

*   [Features](#features)
*   [Quick start](#quick-start)
*   [Guide](#guide)
    <details>
    <summary><a href="#1-initialization-and-lifecycle"><b>1. Initialization and lifecycle</b></a></summary>

    * [1.1 Creating a client](#11-creating-a-client)
    * [1.2 Credentials](#12-credentials)
    * [1.3 Choosing the HTTP stack](#13-choosing-the-http-stack)
    * [1.4 Closing](#14-closing)
    * [1.5 Faking the client in tests](#15-faking-the-client-in-tests)

    </details>

    <details>
    <summary><a href="#2-authentication"><b>2. Authentication</b></a></summary>

    * [2.1 Legacy username and password](#21-legacy-username-and-password)
    * [2.2 PIN flow](#22-pin-flow)
    * [2.3 Account info](#23-account-info)
    * [2.4 Sign out](#24-sign-out)

    </details>

    <details>
    <summary><a href="#3-server-discovery-and-connection"><b>3. Server discovery and connection</b></a></summary>

    * [3.1 Fetch resources](#31-fetch-resources)
    * [3.2 Picking the best connection](#32-picking-the-best-connection)
    * [3.3 Connecting to a PMS](#33-connecting-to-a-pms)
    * [3.4 Switching servers](#34-switching-servers)

    </details>

    <details>
    <summary><a href="#4-server-info"><b>4. Server info</b></a></summary>

    * [4.1 Identity (no auth)](#41-identity-no-auth)
    * [4.2 Full info](#42-full-info)
    * [4.3 Ping](#43-ping)
    * [4.4 Activities, butler tasks and settings](#44-activities-butler-tasks-and-settings)

    </details>

    <details>
    <summary><a href="#5-library-browsing"><b>5. Library browsing</b></a></summary>

    * [5.1 Sections](#51-sections)
    * [5.2 Items by type](#52-items-by-type)
    * [5.3 Counting items](#53-counting-items)
    * [5.4 Single item metadata](#54-single-item-metadata)
    * [5.5 Children and leaves](#55-children-and-leaves)
    * [5.6 Genres](#56-genres)
    * [5.7 Filters, albums, folders, categories](#57-filters-albums-folders-categories)
    * [5.8 Recently added and the A-Z index](#58-recently-added-and-the-a-z-index)

    </details>

    <details>
    <summary><a href="#6-playlists"><b>6. Playlists</b></a></summary>

    * [6.1 Listing and counting](#61-listing-and-counting)
    * [6.2 Creating a playlist](#62-creating-a-playlist)
    * [6.3 Adding, removing and moving items](#63-adding-removing-and-moving-items)
    * [6.4 Renaming and deleting](#64-renaming-and-deleting)

    </details>

    <details>
    <summary><a href="#7-search"><b>7. Search</b></a></summary>

    * [7.1 Hub search](#71-hub-search)
    * [7.2 Legacy flat search](#72-legacy-flat-search)
    * [7.3 Section search](#73-section-search)

    </details>

    <details>
    <summary><a href="#8-playback-reporting"><b>8. Playback reporting</b></a></summary>

    * [8.1 Timeline heartbeat](#81-timeline-heartbeat)
    * [8.2 What PMS counts as a play](#82-what-pms-counts-as-a-play)
    * [8.3 Scrobble and unscrobble](#83-scrobble-and-unscrobble)
    * [8.4 Rate and favourites](#84-rate-and-favourites)

    </details>

    <details>
    <summary><a href="#9-audio-streaming"><b>9. Audio streaming</b></a></summary>

    * [9.1 Audio transcoding](#91-audio-transcoding)
    * [9.2 Direct file URL](#92-direct-file-url)
    * [9.3 Transcode session lifecycle](#93-transcode-session-lifecycle)
    * [9.4 Lyrics](#94-lyrics)
    * [9.5 Loudness](#95-loudness)

    </details>

    <details>
    <summary><a href="#10-video-streaming-and-decision"><b>10. Video streaming and decision</b></a></summary>

    * [10.1 Decision call](#101-decision-call)
    * [10.2 Universal video URL](#102-universal-video-url)
    * [10.3 Session lifecycle](#103-session-lifecycle)

    </details>

    <details>
    <summary><a href="#11-sessions"><b>11. Sessions</b></a></summary>

    * [11.1 Active sessions](#111-active-sessions)
    * [11.2 Playback history](#112-playback-history)
    * [11.3 Terminating a session](#113-terminating-a-session)

    </details>

    <details>
    <summary><a href="#12-images"><b>12. Images</b></a></summary>

    * [12.1 Building a transcoded URL](#121-building-a-transcoded-url)
    * [12.2 Fetching bytes](#122-fetching-bytes)
    * [12.3 Artwork versions and cache keys](#123-artwork-versions-and-cache-keys)

    </details>

    <details>
    <summary><a href="#13-hubs"><b>13. Hubs</b></a></summary>

    * [13.1 Global and per-section hubs](#131-global-and-per-section-hubs)
    * [13.2 Promoted and on-deck](#132-promoted-and-on-deck)
    * [13.3 Drilling into a hub](#133-drilling-into-a-hub)

    </details>

    <details>
    <summary><a href="#14-play-queues"><b>14. Play queues</b></a></summary>

    * [14.1 Creating a queue](#141-creating-a-queue)
    * [14.2 Reading and editing](#142-reading-and-editing)
    * [14.3 Shuffle, unshuffle, reset, clear](#143-shuffle-unshuffle-reset-clear)
    * [14.4 Adding a Plex playlist](#144-adding-a-plex-playlist)

    </details>

    <details>
    <summary><a href="#15-live-tv-and-dvr"><b>15. Live TV and DVR</b></a></summary>

    * [15.1 Active sessions](#151-active-sessions)
    * [15.2 DVR backends](#152-dvr-backends)
    * [15.3 Subscriptions](#153-subscriptions)

    </details>

    <details>
    <summary><a href="#16-similar-items-and-sonic-radio"><b>16. Similar items and sonic radio</b></a></summary>

    * [16.1 Similar items](#161-similar-items)
    * [16.2 Sonically nearest tracks](#162-sonically-nearest-tracks)
    * [16.3 Nearest tracks in a section](#163-nearest-tracks-in-a-section)

    </details>

    <details>
    <summary><a href="#17-ultrablur"><b>17. UltraBlur</b></a></summary>

    * [17.1 Extracting colours](#171-extracting-colours)
    * [17.2 Server-rendered backdrop](#172-server-rendered-backdrop)
    * [17.3 Fetching the rendered image](#173-fetching-the-rendered-image)

    </details>

    <details>
    <summary><a href="#18-error-handling"><b>18. Error handling</b></a></summary>

    * [18.1 PlexException and PlexErrorType](#181-plexexception-and-plexerrortype)
    * [18.2 Classifying a failure](#182-classifying-a-failure)
    * [18.3 Auth invalidation](#183-auth-invalidation)

    </details>

    <details>
    <summary><a href="#19-cancellation-and-retries"><b>19. Cancellation and retries</b></a></summary>

    * [19.1 Cancelling requests](#191-cancelling-requests)
    * [19.2 Retry policy](#192-retry-policy)

    </details>

    <details>
    <summary><a href="#20-paging"><b>20. Paging</b></a></summary>

    * [20.1 How Plex pages](#201-how-plex-pages)
    * [20.2 Walking every page](#202-walking-every-page)

    </details>

    <details>
    <summary><a href="#21-notifications-and-events"><b>21. Notifications and events</b></a></summary>

    * [21.1 Connecting](#211-connecting)
    * [21.2 Typed events](#212-typed-events)

    </details>

    <details>
    <summary><a href="#22-downloads"><b>22. Downloads</b></a></summary>

    * [22.1 Downloading to a file](#221-downloading-to-a-file)

    </details>

    <details>
    <summary><a href="#23-escape-hatch"><b>23. Escape hatch</b></a></summary>

    * [23.1 Raw request](#231-raw-request)
    * [23.2 Raw bytes and streams](#232-raw-bytes-and-streams)

    </details>
*   [Project background](#project-background)

---

## Features

<table>
<tr>
<td valign="middle" width="48"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/package.png" width="32"></td>
<td valign="middle" width="45%"><b>Pure Dart</b><br>no native plugin, no Flutter dependency. The main library also runs on the web; only the file helpers in <code>io.dart</code> need <code>dart:io</code>.</td>
<td valign="middle" width="48"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/shield-check.png" width="32"></td>
<td valign="middle" width="45%"><b>Typed models</b><br>every response is a typed Dart object (libraries, items, media, streams, hubs, server info, history, events), each with a <code>.raw</code> map so new server fields are never lost.</td>
</tr>
<tr>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/key-round.png" width="32"></td>
<td valign="middle"><b>Both auth flows</b><br><code>signInWithPassword()</code> for legacy credentials, <code>createPin()</code> + <code>pollPin()</code> for the official 4-character link flow at <code>plex.tv/link</code>.</td>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/globe.png" width="32"></td>
<td valign="middle"><b>Server discovery</b><br><code>account.fetchResources()</code> returns owned and shared servers with connection candidates; <code>bestConnection()</code> picks local first, then https, then relay.</td>
</tr>
<tr>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/layers.png" width="32"></td>
<td valign="middle"><b>Stateful façade</b><br>one <code>PlexClient</code> holds your identity, server and token. Every sub-API works through it, so you set things up once.</td>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/audio-lines.png" width="32"></td>
<td valign="middle"><b>Audio streaming</b><br><code>streaming.startAudioTranscode()</code> starts an HLS or DASH transcode the way PMS accepts it, bitrate cap included; <code>directFileUrl()</code> gives the zero-transcode original.</td>
</tr>
<tr>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/sliders-horizontal.png" width="32"></td>
<td valign="middle"><b>Your HTTP stack</b><br>any <code>http.Client</code>: the default <code>dart:io</code> one, <code>cupertino_http</code> or <code>cronet_http</code> for HTTP/2 and the system proxy, a <code>MockClient</code> in tests.</td>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/cpu.png" width="32"></td>
<td valign="middle"><b>Off the UI isolate</b><br>large responses are inflated, JSON-decoded and parsed into models on a background isolate, so big pages barely stall the calling isolate.</td>
</tr>
<tr>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/zap.png" width="32"></td>
<td valign="middle"><b>Cancellation and retries</b><br><code>withCancelToken()</code> makes every call of a page cancellable; an opt-in <code>PlexRetryPolicy</code> resends idempotent requests after transient failures.</td>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/activity.png" width="32"></td>
<td valign="middle"><b>Live events</b><br>the server's notification stream decoded into a sealed <code>PlexEvent</code> hierarchy: play states, library changes, scans.</td>
</tr>
<tr>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/triangle-alert.png" width="32"></td>
<td valign="middle"><b>Semantic errors</b><br>every failure is a <code>PlexException</code> you can branch on (auth, not found, network, transient, cancelled), never a raw network error in your code.</td>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/terminal.png" width="32"></td>
<td valign="middle"><b>Escape hatch</b><br><code>client.request&lt;T&gt;()</code>, <code>requestBytes()</code> and <code>requestStream()</code> for endpoints not yet covered by the typed sub-APIs.</td>
</tr>
</table>

---

## Quick start

```dart
import 'package:dart_plex/dart_plex.dart';

Future<void> main() async {
  final plex = PlexClient(
    credentials: const PlexCredentials(
      clientIdentifier: 'PUT-YOUR-UUID-HERE', // stable per install
      product: 'MyApp',
      version: '1.0.0',
      device: 'iPhone',
      deviceName: 'My iPhone',
      platform: 'iOS',
    ),
  );

  // 1. Authenticate against plex.tv.
  final user = await plex.account.signInWithPassword(
    username: 'me@example.com',
    password: 'hunter2',
  );
  plex.setToken(user.authToken);

  // 2. Find the user's servers and connect to one.
  final servers = await plex.account.fetchResources();
  final server = servers.firstWhere((s) => s.owned);
  final connection = server.bestConnection()!;
  plex.connect(connection.uri, accessToken: server.accessToken);

  // 3. Browse the music library.
  final sections = await plex.library.sections();
  final musicLib = sections.firstWhere((s) => s.type == PlexLibraryType.music);
  final albums = await plex.library.allByType(
    sectionId: musicLib.id,
    type: PlexMetadataType.album,
    sort: 'titleSort:asc',
  );

  // 4. Play the first track of the first album.
  final tracks = await plex.library.children(albums.items.first.ratingKey);
  final transcode = await plex.streaming.startAudioTranscode(
    ratingKey: tracks.first.ratingKey,
    session: 'a-uuid-per-playback',
    maxBitrateKbps: 192,
  );
  print(transcode.url); // hand this to your audio engine

  // 5. Release the HTTP client when you are done.
  plex.close();
}
```

---

## Guide

### 1. Initialization and lifecycle

#### 1.1 Creating a client

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

| Argument | Default | |
| :--- | :--- | :--- |
| `httpClient` | a `dart:io` client owned by `PlexClient` | any `http.Client`, see [1.3](#13-choosing-the-http-stack) |
| `connectTimeout` | 15 s | the handshake (default client) and, with `receiveTimeout`, the wait for response headers |
| `receiveTimeout` | 30 s | also bounds every pause inside a response body |
| `jsonIsolateThreshold` | 50 KB | responses this large or larger are decoded and parsed on a background isolate |
| `retryPolicy` | `PlexRetryPolicy.none` | see [19.2](#192-retry-policy) |

Above `jsonIsolateThreshold` the JSON decode and the walk that builds the
typed models both leave the caller's isolate; gzip bodies received by the
default client are inflated on that same background isolate. Pass `0` to
send every response there, or a very large value to keep everything on
the caller.

#### 1.2 Credentials

`PlexCredentials` describes who the client is. Every request carries
the corresponding `X-Plex-*` headers; the most important is
`clientIdentifier`, a **stable per-installation UUID**. Generate it
once, persist it (SharedPreferences, Keychain, Android Keystore…),
and reuse it forever. Changing it invalidates every previously-issued
token.

Optional fields:

* `platformVersion` is sent as `X-Plex-Platform-Version`.
* `clientProfileExtra` is sent as `X-Plex-Client-Profile-Extra`. Used
  to declare extra transcode targets the server should support for
  this client, e.g.
  `'add-transcode-target(type=musicProfile&context=streaming&protocol=hls&container=mpegts&audioCodec=aac,mp3)'`.
  For audio, `startAudioTranscode()` sends its own ([9.1](#91-audio-transcoding)).

#### 1.3 Choosing the HTTP stack

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

Native clients inflate gzip on their own threads; the background
isolate still decodes and parses the JSON.

#### 1.4 Closing

```dart
plex.disconnect(); // clears baseUrl + token, the client stays usable
plex.close();      // releases the HTTP client
```

`close()` closes the HTTP client that `PlexClient` created; requests made
afterwards fail with `PlexErrorType.state`. An `httpClient` you injected
is yours: `close()` leaves it open, close it yourself.

#### 1.5 Faking the client in tests

The models are `final` classes, built only by the library. `PlexClient`
and the sub-API classes are deliberately left open, so an app's tests can
`implements PlexClient` (or `PlexLibraryApi`, …) or use a mocking
library. To test against canned HTTP answers instead, inject a
`MockClient`:

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
  jsonIsolateThreshold: 0, // parse every response off-isolate too
);
```

---

### 2. Authentication

#### 2.1 Legacy username and password

```dart
final user = await plex.account.signInWithPassword(
  username: 'me@example.com',
  password: 'hunter2',
);
plex.setToken(user.authToken);
```

Returns a `PlexUser` with `authToken`, profile fields and Plex Pass
status. The token is **not** automatically applied to the client; call
`plex.setToken(user.authToken)` after a successful sign-in. Throws
`PlexException(type: PlexErrorType.auth)` on bad credentials.

> Plex officially recommends the PIN flow for new integrations because
> accounts with 2FA enabled cannot use this path. Keep this flow only
> for migrations from older clients.

#### 2.2 PIN flow

```dart
// 1. Generate a PIN.
final pin = await plex.account.createPin();
print('Open https://plex.tv/link and enter ${pin.code}');

// 2. Poll until the user authorises the device.
while (true) {
  await Future<void>.delayed(const Duration(seconds: 2));
  final fresh = await plex.account.pollPin(pin.id);
  if (fresh.isAuthenticated) {
    plex.setToken(fresh.authToken);
    break;
  }
  if (fresh.isExpired) throw StateError('PIN expired');
}
```

`createPin()` asks for a strong (JWT-grade) PIN by default; pass
`strong: false` for the legacy kind. The pin expires after ~15 minutes.

#### 2.3 Account info

```dart
final me = await plex.account.currentUser();
print('${me.username} (${me.email})');
```

Returns the same `PlexUser` shape as `signInWithPassword` but built from
`/api/v2/user`. Requires a valid token.

#### 2.4 Sign out

```dart
await plex.account.signOut();
plex.setToken(null);
```

Invalidates the token on plex.tv's side. After this, subsequent PMS
calls would throw `PlexException(type: PlexErrorType.auth)`.

---

### 3. Server discovery and connection

#### 3.1 Fetch resources

```dart
final servers = await plex.account.fetchResources(
  includeRelay: false,
);
```

`includeHttps`, `includeRelay` and `includeIPv6` are on by default. `serverOnly: true`
(default) filters resources to those whose `provides` includes
`"server"`, dropping player and client resources.

Each `PlexResource` carries:

* `name`, `clientIdentifier`, `platform`, `productVersion`, `owned`,
  `home`, `relay`, `presence`, `httpsRequired`
* `accessToken`, the **per-server** token (use this when connecting,
  not the account-level token)
* `connections`, a list of `PlexServerConnection` candidates

#### 3.2 Picking the best connection

```dart
final connection = server.bestConnection();
```

Picks in priority order:

1. Local, non-relay
2. HTTPS, non-relay
3. Any non-relay
4. Relay (last resort)

Each `PlexServerConnection` has `protocol`, `address`, `port`, `uri`,
`local`, `relay`, `ipv6`. You can iterate `server.connections` and
implement your own selection (e.g. parallel-race the candidates with a
2-second timeout).

#### 3.3 Connecting to a PMS

```dart
plex.connect(connection.uri, accessToken: server.accessToken);
```

`accessToken` overrides the current token. For shared servers it's
mandatory, the account-level token won't be authorised on someone
else's server.

#### 3.4 Switching servers

`PlexClient` is single-server-at-a-time. To switch, call `connect()`
with the new URI and token. To keep two servers alive simultaneously,
instantiate two `PlexClient`s with the same `PlexCredentials`.

---

### 4. Server info

#### 4.1 Identity (no auth)

```dart
final id = await plex.server.identity();
print('${id.machineIdentifier} ${id.version} claimed=${id.claimed}');
```

`/identity` doesn't require a token. Useful for reachability checks
before re-authenticating. Returns a `PlexServerIdentity`.

#### 4.2 Full info

```dart
final info = await plex.server.info();
print('${info.friendlyName} ${info.version} on ${info.platform}');
print('Plex Pass: ${info.myPlexSubscription}, '
    'sonic analysis: ${info.musicAnalysis}');
```

The root MediaContainer as a `PlexServerInfo`: everything `identity()`
has plus `friendlyName`, `platform`, `myPlex`, `myPlexUsername`,
`transcoderAudio`, `transcoderLyrics`, `allowSync`, `updatedAt`, and the
rest in `raw`.

#### 4.3 Ping

```dart
if (await plex.server.ping()) { /* server reachable */ }
```

Swallows all transport errors. Use `identity()` directly when you need
to inspect failures.

#### 4.4 Activities, butler tasks and settings

```dart
final running = await plex.activities.list(); // List<PlexActivity>
for (final a in running) {
  print('${a.title} ${a.progress ?? 0}% cancellable=${a.cancellable}');
}

final tasks = await plex.butler.tasks(); // List<PlexButlerTask>
final settings = await plex.preferences.all(); // List<PlexSetting>
final name = await plex.preferences.byId('FriendlyName');
print('${tasks.length} tasks, ${settings.length} settings, ${name?.value}');
```

Each model keeps the server's entry in `raw`.

---

### 5. Library browsing

#### 5.1 Sections

```dart
final sections = await plex.library.sections();
for (final s in sections) {
  print('${s.type.name}: ${s.title} (key=${s.id})');
}
```

`PlexLibraryType` is one of `music`, `movie`, `show`, `photo`,
`unknown`. The `id` field is the section's `key`, what every
`/library/sections/{id}/...` call expects.

#### 5.2 Items by type

```dart
final page = await plex.library.allByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
  start: 100,
  size: 100,
  sort: 'titleSort:asc',
);
print('Got ${page.items.length} of ${page.totalSize}');
```

`PlexMetadataType` integers mirror Plex's wire values:

| Type | Value | |
| :--- | :--- | :--- |
| `movie`       | 1  | |
| `show`        | 2  | |
| `season`      | 3  | |
| `episode`     | 4  | |
| `artist`      | 8  | music |
| `album`       | 9  | music |
| `track`       | 10 | music |
| `photoAlbum`  | 13 | |
| `photo`       | 14 | |
| `playlist`    | 15 | |
| `collection`  | 18 | |

Sort examples: `'titleSort:asc'`, `'addedAt:desc'`,
`'lastViewedAt:desc'`, `'originallyAvailableAt:desc'`,
`'random:<seed>'`.

`filters` narrows the result set. Each condition is a `PlexFilter`;
they travel as separate query parameters and the server ANDs them:

```dart
final page = await plex.library.allByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
  filters: [PlexFilter.genre(6), PlexFilter.yearAfter(2009)],
);
// GET /library/sections/3/all?type=9&genre=6&year>>=2009
```

Plex has no `filter` parameter. A filter *is* a query parameter named
after the field, with the comparison operator baked into the name —
which is why the operator belongs to the constructor you pick and not
to a string you write:

| Constructor | Sends |
| :--- | :--- |
| `PlexFilter.genre(6)` | `genre=6` |
| `PlexFilter.genre(6, exclude: true)` | `genre!=6` |
| `PlexFilter.tag('mood', [3, 7])` | `mood=3,7` (any of) |
| `PlexFilter.year(1994)` | `year=1994` |
| `PlexFilter.yearAfter(2009)` | `year>>=2009` |
| `PlexFilter.yearBefore(2000)` | `year<<=2000` |
| `PlexFilter.ratingAbove(9)` | `userRating>>=9` |
| `PlexFilter.rated()` | `userRating>>=0` |
| `PlexFilter.unplayed()` | `unwatched=1` |
| `PlexFilter.played()` | `unwatched=0` |
| `PlexFilter.titleContains('abbey')` | `title=abbey` |
| `PlexFilter.titleIs('Abbey Road')` | `title==Abbey Road` |
| `PlexFilter.firstCharacter('A')` | `firstCharacter=A` |

Tag fields (genre, mood, style, …) filter by numeric tag id, never by
display name — see [5.6](#56-genres) for where the ids come from.
Conditions in the list are ANDed; several values inside one condition
are ORed. Two conditions that would collide on the same query
parameter throw a `PlexException` rather than let one silently
overwrite the other.

Which fields a section accepts is a property of that section — ask the
server with `filters()` ([5.7](#57-filters-albums-folders-categories))
and use `PlexFilter(field: ..., values: [...])` for anything the named
constructors do not cover.

#### 5.3 Counting items

```dart
final count = await plex.library.countByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
  filters: [PlexFilter.genre(6)],
);
```

Runs the same request as `allByType` with `X-Plex-Container-Size=0`, so
the server answers with `totalSize` without streaming items and a count
can never disagree with the page it counts. `filters` means exactly
what it means there.

#### 5.4 Single item metadata

```dart
final metadata = await plex.library.item('12345');
if (metadata != null) {
  print(metadata.title);
  print(metadata.media.first.audioCodec); // e.g. 'flac'
}
```

Returns `null` when the answer holds no item; a rating key the server
does not know throws a `PlexException` whose `isNotFound` is true. The
model carries `media` (with parts and
streams), `genres`, `moods`, `styles`, counts such as `leafCount`,
`childCount` and `viewedLeafCount`, dates such as `addedAt`,
`lastViewedAt` and `originallyAvailableAt`, plus `raw` for fields not
promoted to typed properties. The full item is also where the streams,
and so `audioStream` and its loudness ([9.5](#95-loudness)), are; list
responses usually leave them out.

#### 5.5 Children and leaves

```dart
// An album's tracks, an artist's albums, a season's episodes.
final tracks = await plex.library.children(album.ratingKey);

// Sorted and paged.
final albumsNewestFirst = await plex.library.children(
  artist.ratingKey,
  sort: 'year:desc',
  start: 0,
  size: 20,
);

// How many, without transferring them.
final albumCount = await plex.library.countChildren(artist.ratingKey);

// Every track of an artist in album order, in one request per page.
final artistTracks = await plex.library.grandchildren(
  artist.ratingKey,
  start: 0,
  size: 100,
);

// Every leaf under an item (tracks of an artist, episodes of a show).
final leaves = await plex.library.allLeaves(artist.ratingKey, size: 100);
```

Without `size`, `children()`, `grandchildren()` and `allLeaves()` answer
every row; with it they read one page, and a page shorter than `size` is
the last ([20](#20-paging)). `children()` takes the section sort syntax
(`'year:desc'`, `'titleSort'`, verified on PMS 1.43.2). `allLeaves()` has
no `sort`: PMS 1.43.2 ignores it there and answers in library order.
`countChildren()` reads `totalSize` of an empty page.

#### 5.6 Genres

```dart
final genres = await plex.library.genres(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
);

final rock = genres.firstWhere((g) => g.title == 'Rock');
final rockAlbums = await plex.library.allByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
  filters: [PlexFilter.of(rock)],
);
```

Each entry is a `PlexTag` carrying the numeric `id` the server filters
by, so a genre goes straight back into a query via `PlexFilter.of()` —
which reads both the field name and the id off the tag. Servers report
that id in different shapes (`key` is a bare id on current versions, a
path on older ones, and `fastKey` is a ready-made query); `PlexTag`
resolves all of them. `id` is null when a server sends nothing usable,
and `PlexFilter.of()` throws rather than issue a query that would come
back unfiltered.

#### 5.7 Filters, albums, folders, categories

`filters()` returns the facets a section can be filtered on — the
authoritative list of filterable fields for *that* section.
`PlexLibraryFilter.field` is the query parameter to use, and
`filterValues()` enumerates what it accepts by following the values
endpoint the server nominates. The raw entry still carries the `Pivot`
array of pre-built sub-views like the A-Z index and folder view.

```dart
final facets = await plex.library.filters(sectionId: musicLib.id);
for (final f in facets) {
  print('${f.title}: field=${f.field} type=${f.valueType}');
}

final moodFacet = facets.firstWhere((f) => f.field == 'mood');
final moods = await plex.library.filterValues(
  filter: moodFacet,
  type: PlexMetadataType.track,
);
final mellow = moods.firstWhere((m) => m.title == 'Mellow');
final mellowTracks = await plex.library.allByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.track,
  filters: [PlexFilter.of(mellow)],
);
```

`albums()`, `folderLocations()`, and `categories()` are cheap
sub-bucket endpoints when the consumer does not need the full
sort and filter machinery of `allByType`:

```dart
final paged = await plex.library.albums(
  sectionId: musicLib.id,
  size: 100,
);
final folders = await plex.library.folderLocations(sectionId: musicLib.id);
final cats = await plex.library.categories(sectionId: photoLib.id);
```

#### 5.8 Recently added and the A-Z index

```dart
// Newest first, of one section or of the whole server.
final newInMusic = await plex.library.recentlyAdded(
  sectionId: musicLib.id,
  size: 20,
);
final newAnywhere = await plex.library.recentlyAdded(size: 20);

// The letters a section's titles start with, for an A-Z scrubber.
final letters = await plex.library.firstCharacters(
  sectionId: musicLib.id,
  type: '${PlexMetadataType.album.value}',
);
```

In a music section `recentlyAdded()` answers albums (verified on PMS
1.43.2, which ignores a `type` asking for tracks), so it takes no type.
`firstCharacters()` calls `/library/sections/{id}/firstCharacter`; jump to
a letter with `PlexFilter.firstCharacter('A')` on `allByType()`.

---

### 6. Playlists

#### 6.1 Listing and counting

```dart
final audio = await plex.playlists.list(type: 'audio', size: 100);

// Narrowed on the server: title contains "mix" (case-insensitive),
// and rated.
final mixes = await plex.playlists.list(
  type: 'audio',
  filters: [PlexFilter.titleContains('mix'), PlexFilter.rated()],
  sort: 'titleSort',
);
final count = await plex.playlists.count(
  type: 'audio',
  filters: [PlexFilter.titleContains('mix')],
);
```

`type` is `'audio' | 'video' | 'photo'`; `smart: true` or `false` keeps
only smart or regular playlists. `filters` works as on `allByType()`:
verified on PMS 1.43.2, `/playlists` honours `title` (a
case-insensitive "contains") and `userRating` filters together, plus
`sort`, so there is no need to scan pages and filter on the client. Each
entry is a `PlexMetadata` of `PlexMetadataType.playlist`.

#### 6.2 Creating a playlist

```dart
final machineId = (await plex.server.identity()).machineIdentifier;

final playlist = await plex.playlists.create(
  title: 'My Mix',
  type: 'audio',
  machineIdentifier: machineId,
  itemRatingKeys: const ['12345', '12346', '12347'],
);
```

Plex requires the server's `machineIdentifier` to build the playlist
URI. Pass an empty `itemRatingKeys` to create an empty playlist.

#### 6.3 Adding, removing and moving items

```dart
await plex.playlists.addItems(
  playlistId: playlist.ratingKey,
  machineIdentifier: machineId,
  itemRatingKeys: const ['99999'],
);

final entries = await plex.playlists.items(playlist.ratingKey);

// Remove one entry.
final added = entries.firstWhere((e) => e.ratingKey == '99999');
await plex.playlists.removeItem(
  playlistId: playlist.ratingKey,
  playlistItemId: added.playlistItemId!,
);

// Move the last entry to the start (leave afterPlaylistItemId out).
await plex.playlists.moveItem(
  playlistId: playlist.ratingKey,
  playlistItemId: entries.last.playlistItemId!,
);
```

`removeItem` and `moveItem` take the **entry** id,
`PlexMetadata.playlistItemId`, not the track's rating key, so a track
listed twice loses or moves only the entry you name. It is set on items
read from `playlists.items()`. Pass `start` and `size` to `items()` to
read one page of a long playlist.

#### 6.4 Renaming and deleting

```dart
await plex.playlists.rename(playlistId: '123', title: 'New name');
await plex.playlists.delete('123');
```

---

### 7. Search

#### 7.1 Hub search

```dart
final hubs = await plex.search.hubs(
  query: 'pink floyd',
  sectionId: musicLib.id, // optional, scope to a single library
);

for (final hub in hubs) {
  print('${hub.title} (${hub.type})');
  for (final hit in hub.items) {
    print('  - ${hit.title}');
  }
}
```

Modern type-as-you-go search; returns one `PlexHub` per result
category (artists, albums, tracks, …). `limit` defaults to 10 per hub.

#### 7.2 Legacy flat search

```dart
final results = await plex.search.flat(query: 'pink floyd', limit: 50);
```

Older endpoint; returns a flat `List<PlexMetadata>` mixing all
categories. Prefer `hubs()` when available.

#### 7.3 Section search

```dart
final tracks = await plex.search.section(
  sectionId: musicLib.id,
  query: 'money',
  type: PlexMetadataType.track,
  limit: 20,
);
```

One section, one kind of item, as a flat list: the shape for a "tracks
matching…" view. `type` is required; PMS 1.43.2 answers 400 without it.

---

### 8. Playback reporting

#### 8.1 Timeline heartbeat

```dart
await plex.playback.timeline(
  ratingKey: track.ratingKey,
  playState: PlexPlayState.playing, // playing | paused | buffering | stopped
  timeMs: 42000,
  durationMs: track.durationMs!,
  playQueueItemID: queueItemId, // only when playing a server play queue
);
```

Plex recommends sending a timeline every 10 s on LAN, 20 s on
cellular, plus one on every state change.

`durationMs` must be the item's real length: the call throws an
`ArgumentError` for a `durationMs` of 0 or less (PMS never counts such a
play) or a negative `timeMs`. `playQueueItemID` is the entry id of a
server-side play queue ([14](#14-play-queues)); leave it null otherwise.
`PlexPlayState.unknown` is refused. The `String state` argument, the
`PlexPlaybackApi.state*` constants and the `String playQueueItemId` are
deprecated.

`continuing: true` tells the server "I'm about to start a different
track in the same playback flow", so Plex won't reap the current
transcode session, which matters during gapless prefetch.

#### 8.2 What PMS counts as a play

Measured on PMS 1.43.2 (music, `viewCount` and the history):

* The server clocks the session itself. Reports must follow real time:
  a `playing` at 0 and a `stopped` at the end two seconds later counts
  nothing, however far `time` says the playhead moved.
* About half the track must be heard: stopping at 50% of a 60 s track
  counted, at 40% it did not.
* With `duration=0` nothing is ever counted, which is why `timeline()`
  refuses it.
* Very short tracks are never counted (a 3 s track played in full was
  not).

A counted play raises `viewCount`, sets `lastViewedAt` and adds an entry
to the playback history ([11.2](#112-playback-history)).

#### 8.3 Scrobble and unscrobble

```dart
await plex.playback.scrobble(ratingKey);   // mark as played
await plex.playback.unscrobble(ratingKey); // mark as unplayed
```

`scrobble()` raises `viewCount` without adding a history entry: use it
for "mark as played", and `timeline()` reports to record listening.
`unscrobble()` clears `viewCount` and keeps the history. Both, like
`rate()`, are sent as `PUT`.

#### 8.4 Rate and favourites

```dart
await plex.playback.rate(ratingKey: ratingKey, rating: 7.5); // 0..10
await plex.playback.setFavorite(ratingKey: ratingKey, isFavorite: true);
```

Plex does not have a separate "is favourite" flag; favourites are
encoded as `userRating == 10`. `setFavorite` is sugar around `rate`, and
`PlexMetadata.isFavorite` reads it back. To list them, filter a section
with `PlexFilter.ratingAbove(9)` ([5.2](#52-items-by-type)) — there is
no favourites endpoint.

---

### 9. Audio streaming

`startAudioTranscode()` talks to the server once, to make its decision;
the other methods only **build URLs**. Neither fetches the audio itself:
hand the URL to your audio engine (mpv, AVPlayer, ExoPlayer, …). The
`X-Plex-Token` is in the URL's query so segment requests work without
custom headers.

#### 9.1 Audio transcoding

```dart
final transcode = await plex.streaming.startAudioTranscode(
  ratingKey: track.ratingKey,
  session: 'my-uuid',   // stable per playback session
  protocol: 'dash',     // 'hls' (default, an .m3u8) or 'dash' (an .mpd)
  maxBitrateKbps: 128,  // the target codec is AAC unless audioCodec says otherwise
);
if (transcode.decision.isPlayable) {
  print(transcode.url); // hand to the player
}
```

What PMS 1.43.2 was measured to require, and this method does for you:

* **a decision first**: a `start` for a session with no decision is
  refused with 400, so the method calls
  `/music/:/transcode/universal/decision` for `session` and builds the
  `start` URL from the same parameters;
* **a client profile**: PMS picks one from `X-Plex-Platform` and has none
  for `Linux` or `macOS`; `clientProfileName` (`'Generic'` by default)
  names one explicitly, so any platform works;
* **a transcode target** in `X-Plex-Client-Profile-Extra`;
* **the bitrate cap as a profile limitation**: `maxBitrateKbps` becomes
  an `add-limitation` on `audio.bitrate` (96 gave a 96 kbps stream). The
  cap cannot go above the profile's own ceiling (256 kbps AAC for
  `Generic`).

The URL also carries the client identity, since the player opens it
without this client's headers. When `decision.isPlayable` is false the
URL will not play either. Stop sessions you no longer play
([9.3](#93-transcode-session-lifecycle)): PMS ties one client's
transcodes together, and a new session's bitrate cap was seen not to
apply while other transcodes of the same client were still open.

`PlexStreamingApi.musicProfileExtra()` builds the same profile-extra
value if you drive the decision yourself. `universalAudioUrl()` is
deprecated: PMS 1.43.2 refuses the URL it builds, and its
`maxAudioBitrate` has no effect.

#### 9.2 Direct file URL

```dart
final (url, ext) = plex.streaming.directFileUrl(
  partKey: track.media.first.parts.first.key!,
);
```

Best-quality, zero-server-CPU URL. Use for downloads ([22](#22-downloads))
and for clients that can decode whatever the file contains.

PMS 1.43.2 serves an MP3 part **without its ID3v2 tag** (the body is the
file minus the tag), so a downloaded MP3 carries no embedded tags or
cover and is a little shorter than `PlexPart.size`. Take metadata and
artwork from the server, not from the downloaded file.

#### 9.3 Transcode session lifecycle

```dart
await plex.streaming.pingUniversal(sessionId);  // keep alive
await plex.streaming.stopUniversal(sessionId);  // teardown
```

Plex reaps inactive sessions after ~2 minutes. Ping every 30 s while a
player is paused but the session must stay warm; `pingUniversal()`
throws a `PlexException` of type `notFound` once the session is gone.
`stopUniversal()` returns normally on 404: a session already stopped,
timed out, or never started (PMS creates a DASH session lazily, with its
first segment) is already the state you asked for.

#### 9.4 Lyrics

```dart
// The lyrics stream is a track's stream with streamType 4.
final full = await plex.library.item(track.ratingKey);
final lyricsStream = full!.media.first.parts.first.streams
    .firstWhere((s) => s.isLyrics);
final lyrics = await plex.streaming.lyrics(streamKey: lyricsStream.key!);
```

Returns the lyrics body (LRC or plain text) or `null` if not
available. Parsing into typed `LyricLine` is left to the consumer.

The body is fetched as bytes and decoded here, since a `.lrc` is a file
on disk whose encoding is not fixed: a UTF-8 or UTF-16 byte-order mark
wins if the file carries one (and is stripped, so the first
`[mm:ss.xx]` still starts the line), then the response's `charset` if
Plex sends one, then a strict UTF-8 attempt that falls back to Latin-1.
So the string you get back is already text, whatever the file was.

#### 9.5 Loudness

```dart
final full = await plex.library.item(track.ratingKey);
final audio = full?.audioStream;
if (audio != null && audio.hasLoudness) {
  print('track gain ${audio.gain} dB, album gain ${audio.albumGain} dB, '
      'peak ${audio.peak}, ${audio.loudness} LUFS');
}
```

An analysed audio stream carries `gain`, `albumGain`, `peak`,
`albumPeak`, `loudness` (LUFS) and `lra` (LU). They come from the
server's own analysis of the file, so they survive a transcode that
drops the file's ReplayGain tags: read them from the original stream
and apply the gain to the transcoded audio. `audioStream` is the
selected audio stream of the first part; streams are in the full item
from `library.item()`, not in list responses.

---

### 10. Video streaming and decision

For video, the universal endpoint alone is not enough. Plex wants a
`/decision` round-trip first: the server inspects the source and
your client profile and answers with a numeric `generalDecisionCode`.
A code in the 1xxx band means playback can succeed (whether by
direct-play, direct-stream, or transcode) while 2xxx, 3xxx and 4xxx are
error bands (general, direct-play, and transcode errors respectively).
Whether a playable decision is direct or transcode is read from the
sibling `directPlayDecisionCode` and `transcodeDecisionCode` fields.

#### 10.1 Decision call

```dart
final decision = await plex.streaming.decisionUniversal(
  params: {
    'path': '/library/metadata/$ratingKey',
    'mediaIndex': 0,
    'partIndex': 0,
    'protocol': 'hls',
    'directPlay': 0,
    'directStream': 1,
    'videoResolution': '1920x1080',
    'maxVideoBitrate': 8000,
    'videoCodec': 'h264',
    'audioCodec': 'aac',
    'session': 'my-uuid',
  },
  extraHeaders: const {
    // Pin the music or video profile per-call without touching the
    // global PlexCredentials.clientProfileExtra.
    'X-Plex-Client-Profile-Extra':
        'add-transcode-target(type=videoProfile&context=streaming'
            '&protocol=hls&container=mpegts&videoCodec=h264&audioCodec=aac)',
  },
);

if (decision.isDirect) {
  // playable, directPlayDecisionCode in 1xxx, start.{m3u8|mpd|mp4}
  // will work as-is
} else if (decision.isTranscode) {
  // playable, transcodeDecisionCode in 1xxx, fetch the manifest
} else {
  // not playable (generalDecisionCode 2xxx/3xxx/4xxx): bandwidth,
  // codec mismatch, unauthorised, ...
}
```

#### 10.2 Universal video URL

```dart
final url = plex.streaming.universalVideoUrl(
  ratingKey: ratingKey,
  videoResolution: '1920x1080',
  videoBitrate: 8000,
  audioBitrate: 256,
  videoCodec: 'h264',
  audioCodec: 'aac',
  subtitleSize: 100,
  session: 'my-uuid',
);
```

`protocol` (default `'hls'`) and `container` (default `'mpegts'`) pick
the target. The URL extension is derived from `protocol`: `.m3u8` for
HLS, `.mpd` for DASH, the container otherwise. Bandwidth is in kbps.

#### 10.3 Session lifecycle

Same `stopUniversal()` and `pingUniversal()` calls as audio. Plex
uses one universal endpoint family for both. Ping every 30 s while
the player is paused to keep the session warm; call `stopUniversal()`
when the user navigates away.

---

### 11. Sessions

"What's playing on the server right now" plus historical scrobble
data. Useful for multi-room awareness, dashboards, or to avoid
starting a new transcode when the user is already streaming.

#### 11.1 Active sessions

```dart
final sessions = await plex.sessions.active();
for (final s in sessions) {
  print('${s.user?.title} → ${s.metadata.title}'
      ' (${s.player?.state}, ${s.viewOffsetMs} ms,'
      ' ${s.transcodeSession == null ? 'direct' : 'transcode'})');
}
```

Each `PlexSession` carries the full `PlexMetadata` of the item
being played plus `user`, `player`, `transcodeSession` and a
`sessionId` you can pass to [11.3](#113-terminating-a-session).

#### 11.2 Playback history

```dart
final history = await plex.sessions.history(
  accountId: 1,
  mindate: DateTime.now()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch ~/
      1000,
  size: 100,
  sort: 'viewedAt:desc',
);
print('${history.items.length} of ${history.totalSize}');
for (final h in history.items) {
  print('${h.viewedAt} ${h.grandparentTitle} - ${h.title}');
}
```

A page of `PlexHistoryEntry` (`historyKey`, `ratingKey`, `title`,
`parentTitle`, `grandparentTitle`, `type`, `viewedAt`, `accountId`,
`deviceId`, `librarySectionId`, and `raw`), with `totalSize` for paging.

#### 11.3 Terminating a session

```dart
await plex.sessions.terminate(
  sessionId: session.sessionId!,
  reason: 'You started watching elsewhere',
);
```

The `reason` is shown to the user whose session was killed.

---

### 12. Images

#### 12.1 Building a transcoded URL

```dart
final url = plex.images.transcodeUrl(
  sourcePath: metadata.thumb!, // e.g. '/library/metadata/123/thumb/1700000000'
  width: 300,
  height: 300,
);
```

Goes through `/photo/:/transcode` so the server delivers a
pre-resized JPEG (~50-150KB at 500×500, the default size).

#### 12.2 Fetching bytes

```dart
final bytes = await plex.images.fetch( // Uint8List?
  sourcePath: metadata.thumb!,
);
```

Returns `null` on 404. Throws `PlexException` on transient failures
(5xx, network down) so the caller can distinguish "no artwork ever" from
"try again later".

#### 12.3 Artwork versions and cache keys

```dart
final cacheKey = '${album.ratingKey}@${album.thumbVersion}';
final version = PlexArtwork.versionOf('/library/metadata/123/thumb/1791659974');
// '1791659974'
```

PMS appends a Unix timestamp to artwork paths, and it changes whenever
the image does (verified on PMS 1.43.2: each new poster upload gets a new
one). Put it in your artwork cache key and a cover replaced on the server
is fetched again. `thumbVersion`, `artVersion`, `parentThumbVersion` and
`grandparentThumbVersion` read it off a `PlexMetadata`; a track without
art of its own carries its album's thumb, version included.

---

### 13. Hubs

Hubs power Plex's "Home" screen: `Recently Added Music`, `Continue
Listening`, `More from <artist>`, `On Deck`. Each hub is a typed row
of items; render them as horizontal carousels.

#### 13.1 Global and per-section hubs

```dart
// Global hubs (all libraries).
final globalHubs = await plex.hubs.global(count: 8);

// Hubs scoped to one library section.
final musicHubs = await plex.hubs.forSection(
  sectionId: musicLib.id,
);

for (final hub in musicHubs) {
  print('${hub.title}: ${hub.items.length} items');
}
```

Each `PlexHub` carries a small preview of items in `hub.items` (16 per
hub unless you pass `count`) plus a `more` flag indicating whether the
rail has more entries behind a `Show all` action.

#### 13.2 Promoted and on-deck

```dart
final promoted = await plex.hubs.promoted();
final onDeck = await plex.hubs.continueWatching();
final perLibrary = await plex.hubs.sectionOnDeck(
  sectionId: musicLib.id,
);
```

`continueWatching()` and `sectionOnDeck()` return a
`List<PlexMetadata>` directly (not wrapped in a hub) since the
data is already a flat list of "Up Next" entries.

#### 13.3 Drilling into a hub

When `hub.more == true` and the user taps "Show all", fetch the
rest:

```dart
final all = await plex.hubs.drill(
  hubKeyOrIdentifier: hub.hubKey, // or hub.hubIdentifier
  size: 100,
);
```

---

### 14. Play queues

Plex's canonical queue model. A play queue holds the
currently-playing item, what's next, and any shuffled order. Casting
to a Plex TV client reuses the same queue, and the queue ID is what
drives the cross-device "Resume" behaviour.

You can skip queues for local-only playback (just use `library` +
`streaming`). Reach for them when you want cast-friendly state,
persisted "Up Next", or party-mode add-to-queue from another device.

#### 14.1 Creating a queue

```dart
final machineId = (await plex.server.identity()).machineIdentifier;

final uri = PlexPlayQueuesApi.seedFromItems(
  machineIdentifier: machineId,
  ratingKeys: const ['12345', '12346', '12347'],
);
final queue = await plex.playQueues.create(
  type: 'audio',
  uri: uri,
);
final queueId = queue.id;
```

`shuffle` (off) and `continuous` (on) set the queue's mode. The
`PlexPlayQueue` carries `id`, `selectedItemId`, `shuffled`, `version`
and its `items`.

#### 14.2 Reading and editing

```dart
// Read the queue contents (optionally centred on the currently
// playing entry).
final items = await plex.playQueues.items(
  playQueueId: queueId,
  center: currentPlayQueueItemId,
  window: 50,
);

// Append more items.
await plex.playQueues.addItems(
  playQueueId: queueId,
  uri: PlexPlayQueuesApi.seedFromItems(
    machineIdentifier: machineId,
    ratingKeys: const ['99999'],
  ),
);

// "Play next": splice right after the current item.
await plex.playQueues.addItems(
  playQueueId: queueId,
  uri: PlexPlayQueuesApi.seedFromItems(
    machineIdentifier: machineId,
    ratingKeys: const ['99998'],
  ),
  playNext: true,
);

// Move an entry. Omit `afterPlaylistItemId` (leave it null) to move to
// the start.
await plex.playQueues.moveItem(
  playQueueId: queueId,
  playQueueItemId: entryId,
);

// Remove an entry.
await plex.playQueues.removeItem(
  playQueueId: queueId,
  playQueueItemId: entryId,
);
```

#### 14.3 Shuffle, unshuffle, reset, clear

```dart
await plex.playQueues.shuffle(queueId);
await plex.playQueues.unshuffle(queueId);

// Rewind the queue so the first item is current again.
await plex.playQueues.reset(queueId);

// Drop every item. The queue id stays valid.
await plex.playQueues.clear(queueId);
```

#### 14.4 Adding a Plex playlist

```dart
await plex.playQueues.addItems(
  playQueueId: queueId,
  playlistId: playlist.ratingKey,
);
```

`uri` and `playlistId` are mutually exclusive on the upstream
endpoint. Use `playlistId` to splice every track of a Plex playlist
into the queue.

---

### 15. Live TV and DVR

Plex Live TV streams broadcast and cable channels through a tuner +
listings provider; DVR records scheduled programs to disk. This
sub-API covers the **consumer-facing** slice: current sessions,
DVR backends, recording subscriptions. Tuner provisioning and EPG
listings provider setup stay on the escape hatch (admin-only).

#### 15.1 Active sessions

```dart
final liveSessions = await plex.liveTv.sessions();
for (final entry in liveSessions) {
  final player = entry['Player'];
  final playerTitle = player is Map<String, Object?> ? player['title'] : null;
  print('${entry['title']} on ${entry['channelCallSign']} ($playerTitle)');
}
```

> Past live-TV viewing history is not exposed by `plex.liveTv`; use
> [`plex.sessions.history()`](#112-playback-history). Live TV plays are
> reported into the same playback-history store as on-demand items.

#### 15.2 DVR backends

```dart
final dvrs = await plex.liveTv.dvrs();
for (final dvr in dvrs) {
  final lineup = dvr['lineup'];
  print('${dvr['title']} '
      '(${lineup is Map<String, Object?> ? lineup['name'] : '-'})');
}

// Drill into the channels grouped under one DVR:
final channels = await plex.liveTv.dvrChannels(dvrs.first['key']! as String);
```

#### 15.3 Subscriptions

DVR recording subscriptions live on their own sub-API,
`plex.subscriptions` (`PlexSubscriptionsApi`), not on `plex.liveTv`:

```dart
// List every recording rule. Returns the raw response map.
final body = await plex.subscriptions.list();
final container = body['MediaContainer'];
final list =
    container is Map<String, Object?> ? container['MediaSubscription'] : null;
final subs = list is List
    ? list.whereType<Map<String, Object?>>().toList()
    : const <Map<String, Object?>>[];
for (final sub in subs) {
  print('${sub['title']} - ${sub['type']}');
}

// Delete a subscription by its id.
await plex.subscriptions.delete('${subs.first['id']}');
```

> Live TV (sessions, DVRs) results come back as raw maps
> (`Map<String, Object?>`), so nested values need a type check before
> use. They could get typed wrappers later, but the underlying shapes are
> deeply nested and change often between Plex releases, so the raw map
> is the safer bet for now.

---

### 16. Similar items and sonic radio

Three endpoints for "what should I play next". The first returns the
server's general similar-items judgment (album to album, movie to
movie). The other two read the music sonic-analysis index that PMS
maintains for every track to surface sonically nearest tracks.

#### 16.1 Similar items

```dart
final picks = await plex.library.similar(
  ratingKey: album.ratingKey,
  count: 12,
);
```

Works for albums, artists, movies, and shows (any metadata item the
server has tagged with similarity).

#### 16.2 Sonically nearest tracks

```dart
final nearest = await plex.library.nearestToTrack(
  ratingKey: track.ratingKey,
  limit: 25,
  maxDistance: 0.25,
  excludeGrandparentRatingKey: track.grandparentRatingKey,
);
```

`excludeParentRatingKey` and `excludeGrandparentRatingKey` keep the
album or artist of the seed out of the result (useful when the seed
track dominates the radio); pass the rating key as the track has it.
The `int` forms, `excludeParentID` and `excludeGrandparentID`, are
deprecated. Each result carries its `distance` from the seed.

#### 16.3 Nearest tracks in a section

```dart
// The sonic vector lives in the raw envelope under `musicAnalysis`
// (a track has one once the server has analysed it).
final seed = (track.raw['musicAnalysis']! as List).cast<num>();
final radio = await plex.library.nearestInSection(
  sectionId: musicLib.id,
  values: seed,
  limit: 50,
);
```

Seeds the search from a raw music-analysis vector instead of a single
track. Average several such vectors together to build a "mood" radio.

---

### 17. UltraBlur

Plex servers can extract a four-corner colour palette from any image
and render that palette into a smooth gradient. Saves the client the
cost of running k-means locally, and the rendered image can be cached
just like any other transcoded artwork.

#### 17.1 Extracting colours

```dart
final palettes = await plex.ultraBlur.colors(
  sourceUrl: album.thumb!,
);
final palette = palettes.first;
print('${palette.topLeft} ${palette.topRight} '
    '${palette.bottomLeft} ${palette.bottomRight}');
```

The container shape returns an array; pick the first element for the
common case. `sourceUrl` accepts a relative PMS path (most common) or
an absolute URL. When the item details carry the palette already, it is
in `PlexMetadata.ultraBlurColors`.

#### 17.2 Server-rendered backdrop

```dart
final url = plex.ultraBlur.imageUrl(
  topLeft: palette.topLeft,
  topRight: palette.topRight,
  bottomLeft: palette.bottomLeft,
  bottomRight: palette.bottomRight,
  width: 1920,
  height: 1080,
  noise: 1,
);
```

Pass `noise: 1` when the image will be used behind text so the server
adds a small amount of dither to reduce gradient banding.

#### 17.3 Fetching the rendered image

```dart
final bytes = await plex.ultraBlur.fetchImage(
  topLeft: palette.topLeft,
  topRight: palette.topRight,
  bottomLeft: palette.bottomLeft,
  bottomRight: palette.bottomRight,
  width: 1280,
  height: 720,
);
```

Convenience wrapper around `imageUrl` plus `plex.requestBytes` for
when you want to cache the PNG yourself.

---

### 18. Error handling

#### 18.1 PlexException and PlexErrorType

Every public call throws `PlexException` on failure:

```dart
try {
  await plex.library.sections();
} on PlexException catch (e) {
  print('${e.type} → ${e.statusCode} → ${e.message}');
}
```

`PlexErrorType` values: `connection`, `timeout`, `auth`, `notFound`,
`badRequest`, `serverError`, `parse`, `state`, `cancelled`, `unknown`.
The exception also carries the request `path`, the underlying `cause`,
the original `stackTrace` and, when the server sent `Retry-After` (on a
`429` or `503`), `retryAfter`.

#### 18.2 Classifying a failure

```dart
try {
  await plex.library.sections();
} on PlexException catch (e) {
  if (e.isCancelled) {
    // the caller gave up; not a failure, ignore it
  } else if (e.isAuthError) {
    await reAuthenticate(); // 401 or 403, token rejected
  } else if (e.isTransient) {
    scheduleRetry(e.retryAfter); // network, 5xx or 429
  } else if (e.isNotFound) {
    showGone(); // 404: confirmed absence
  } else {
    surfaceError(e.message);
  }
}
```

| Getter | True for |
| :--- | :--- |
| `isNetworkFailure` | no answer at all: connection failed or timed out (same as `isRetriable`) |
| `isTransient` | may pass if sent again later: a network failure, a 5xx, or `429` |
| `isNotFound` | the server answered `404` |
| `isCancelled` | the request was cancelled through a `PlexCancelToken` |
| `isAuthError` | `401` / `403`, or a PIN that expired |

The getters mean the same in `dart_plex` and `dart_jellyfin`.

#### 18.3 Auth invalidation

`PlexException.isAuthError` is the signal to re-run the PIN flow or
the legacy sign-in. The library will not automatically re-fetch a
token; that's an app-level policy decision.

---

### 19. Cancellation and retries

#### 19.1 Cancelling requests

```dart
PlexCancelToken? _searchToken;

Future<List<PlexHub>> searchAsYouType(PlexClient plex, String text) async {
  _searchToken?.cancel(); // drop the previous keystroke's request
  final token = _searchToken = PlexCancelToken();
  try {
    return await plex.withCancelToken(token).search.hubs(query: text);
  } on PlexException catch (e) {
    if (e.isCancelled) return const [];
    rethrow;
  }
}
```

`withCancelToken(token)` returns a view of the client whose every
sub-API call is cancelled by `token.cancel()`. The view shares the
client's connection pool, server and token (`connect`, `setToken` and
`close` on either affect both) and costs nothing to create, so make one
per page, filter or search term. A token cancels only once: make a new
one for the next request. `request()`, `requestBytes()`,
`requestStream()` and `downloadToFile()` also take a `cancelToken`
directly.

A cancelled call throws a `PlexException` of type `cancelled`
(`isCancelled`), which is not a failure. `notifications` is the same
object on the view as on the client: a WebSocket or event stream is not
a request and is not cancelled.

#### 19.2 Retry policy

```dart
final plex = PlexClient(
  credentials: credentials,
  retryPolicy: const PlexRetryPolicy(
    maxAttempts: 4, // the first attempt included
    maxDelay: Duration(seconds: 10),
  ),
);
```

Off by default. With a policy, only idempotent requests (`GET`, `HEAD`)
are resent, and only after a failure another attempt can fix: no answer
(connection lost, timeout), `502`, `503`, `504` or `429`. A `500` is not
retried. The wait grows exponentially from `initialDelay` (300 ms) with
full jitter, a `Retry-After` header is honoured up to `maxDelay` (5 s),
and a cancel token cancels the wait too. `const PlexRetryPolicy()`
resends up to twice. Opening a stream is retried as well; a body already
flowing is not replayed.

---

### 20. Paging

#### 20.1 How Plex pages

Plex pages with `X-Plex-Container-Start` and `X-Plex-Container-Size`.
PMS 1.43.2 ignores `Size` sent on its own and answers the whole list
(verified on `/children`, `/allLeaves`, `/all` and
`/playlists/{id}/items`), so every paged method here sends both. Methods
whose `start` and `size` are optional (`children()`, `allLeaves()`,
`grandchildren()`, `recentlyAdded()`, `playlists.items()`) answer every
row when you pass neither, read one page when you pass `size` (`start`
defaults to 0), and throw an `ArgumentError` for a `start` without a
`size`.

#### 20.2 Walking every page

```dart
final tracks = PlexPaging.items(
  (start, size) => plex.library.grandchildren(
    artist.ratingKey,
    start: start,
    size: size,
  ),
  pageSize: 200,
);
await for (final track in tracks) {
  print(track.title);
}

// allByType answers a container: hand PlexPaging its items.
final albumPages = PlexPaging.pages(
  (start, size) async => (await plex.library.allByType(
    sectionId: musicLib.id,
    type: PlexMetadataType.album,
    start: start,
    size: size,
  ))
      .items,
  limit: 500,
);
```

`PlexPaging.pages()` streams one page at a time and `items()` the rows
one by one. Paging stops at the first page shorter than `pageSize`
(default 100) or once `limit` rows have been delivered, asking the last
page for exactly what is left. Nothing is fetched ahead: each page is
one request, made when the stream is listened to, so cancelling the
subscription stops the requests. Pair it with a cancel token
([19.1](#191-cancelling-requests)) to drop the request in flight too.

---

### 21. Notifications and events

#### 21.1 Connecting

```dart
final frames = await plex.notifications.connectWebSocket();
final subscription = frames.listen((frame) => print(frame.type));

// Later:
await subscription.cancel();
await plex.notifications.closeWebSocket();
```

`connectWebSocket()` waits for the handshake, so the stream is live when
it returns, and throws a `PlexException` of type `connection` if it
cannot open. `connectEventSource()` gives the same stream over
Server-Sent Events, for networks whose proxies block WebSockets (close it
with `closeEventSource()`). Both take an optional `filter` naming one
frame type (`'playing'`, `'activity'`, …). Each frame is a
`PlexNotification` with its `type` and `raw` body.

#### 21.2 Typed events

```dart
final frames = await plex.notifications.connectWebSocket();
final subscription = frames.events().listen((event) {
  switch (event) {
    case PlexPlaySessionEvent(:final ratingKey, :final state):
      print('$ratingKey is ${state.name}');
    case PlexLibraryItemEvent(:final itemId, isDeleted: true):
      print('$itemId was deleted');
    case PlexLibraryItemEvent(:final itemId, isReady: true):
      print('$itemId changed, re-read it');
    case PlexActivityEvent(isLibraryScan: true, isEnded: true):
      print('scan finished, reload the library');
    case _:
  }
});

// When done:
await subscription.cancel();
```

`events()` on a notification stream (or `PlexNotification.events` on one
frame, which can carry several entries) decodes frames into the sealed
`PlexEvent` hierarchy:

| Event | Frame type | |
| :--- | :--- | :--- |
| `PlexPlaySessionEvent` | `playing` | a player's `PlexPlayState`, playhead, rating key, play queue ids |
| `PlexLibraryItemEvent` | `timeline` | an item created, changed, analysed or deleted (`isCreated`, `isReady`, `isDeleted`, `updatedAt`) |
| `PlexActivityEvent` | `activity` | a background activity started, progressed or ended; `isLibraryScan` |
| `PlexStatusEvent` | `status` | a server status message |
| `PlexUnknownEvent` | anything else | the whole frame in `raw` |

The shapes follow frames captured from PMS 1.43.2. One library change
arrives as several `PlexLibraryItemEvent`s as the item moves through its
states; new artwork arrives as a ready event with a new `updatedAt`.

---

### 22. Downloads

#### 22.1 Downloading to a file

```dart
import 'package:dart_plex/dart_plex.dart';
import 'package:dart_plex/io.dart';

final (url, ext) = plex.streaming.directFileUrl(
  partKey: track.media.first.parts.first.key!,
);
final bytes = await plex.downloadToFile(
  url,
  '/music/${track.ratingKey}.$ext',
  cancelToken: token,
  onProgress: (received, total) => print('$received / ${total ?? '?'}'),
);
```

`downloadToFile()` is an extension on `PlexClient` in
`package:dart_plex/io.dart`, kept out of the main library so that stays
usable on the web. It streams the body to `<path>.part` as it arrives (a
whole track never sits in memory) and renames it to `path` once
complete, so `path` either holds the whole file or does not exist: a
failure, a stall past the receive timeout or a cancellation removes the
partial file and throws a `PlexException`. `onProgress` gets the bytes
received so far and the total when the server sent a `Content-Length`.
It returns the number of bytes written. Mind the MP3 note in
[9.2](#92-direct-file-url).

---

### 23. Escape hatch

When the typed sub-APIs don't yet cover an endpoint, drop down to:

#### 23.1 Raw request

```dart
final response = await plex.request<Map<String, Object?>>(
  '/library/sections/$id/all',
  queryParameters: {
    'type': 9,
    'X-Plex-Container-Start': 0,
    'X-Plex-Container-Size': 50,
  },
);
print('${response.statusCode} ${response.contentType}');
final container = response.data?['MediaContainer'];
```

Same HTTP client, headers, retry policy and `PlexException` translation
as the typed sub-APIs. A `PlexResponse<T>` carries `data`, `statusCode`,
`headers` (lower-case names), `contentType` and the requested `uri`.
Pass `method: 'POST'`, `'PUT'` or `'DELETE'` (or use `get`, `post`,
`put`, `delete`), `extraHeaders`, `data`, `absoluteUrl: true`,
`cancelToken` as needed. `responseType` picks the decoding:
`PlexResponseType.json` (JSON when the server says so, else text),
`bytes` or `plain`.

#### 23.2 Raw bytes and streams

```dart
// Small bodies, held in memory.
final art = await plex.requestBytes(
  '/library/metadata/123/thumb/1700000000',
  absoluteUrl: false,
);
final bytes = art.data; // Uint8List?

// Large bodies, chunk by chunk.
final res = await plex.requestStream(
  '${plex.baseUrl}/library/parts/123/1700000000/file.flac',
);
print('${res.contentLength} bytes of ${res.contentType}');
await for (final chunk in res.stream) {
  sink.add(chunk);
}
```

`requestBytes()` and `requestStream()` take a full URL by default
(`absoluteUrl: false` for a path on the connected server); the token
travels in the headers either way. Listen to a `PlexStreamedResponse`'s
`stream` once; cancelling the subscription closes the connection.

---

## Project background

All the typed models, sub-APIs, and architectural patterns were implemented through the use of Claude Code.

---

*Developed by Alessandro Di Ronza*
