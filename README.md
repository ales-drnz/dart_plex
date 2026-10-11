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
<td valign="middle"><code>dart_plex</code> is a Dart client for Plex Media Server 1.43. It covers libraries, playlists, streaming, playback reporting, play queues and search through typed Dart objects, and handles plex.tv sign-in and server discovery.</td>
</tr>
</table>

---

## Installation

Add `dart_plex` to your `pubspec.yaml`:

```yaml
dependencies:
  dart_plex: ^0.2.0
```

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
    <summary><a href="#2-sign-in-and-server-discovery"><b>2. Sign-in and server discovery</b></a></summary>

    * [2.1 PIN flow](#21-pin-flow)
    * [2.2 Username and password](#22-username-and-password)
    * [2.3 Account and sign-out](#23-account-and-sign-out)
    * [2.4 Finding servers](#24-finding-servers)
    * [2.5 Connecting to a server](#25-connecting-to-a-server)

    </details>

    <details>
    <summary><a href="#3-server"><b>3. Server</b></a></summary>

    * [3.1 Identity and info](#31-identity-and-info)
    * [3.2 Activities, butler tasks and settings](#32-activities-butler-tasks-and-settings)
    * [3.3 Administration](#33-administration)

    </details>

    <details>
    <summary><a href="#4-library"><b>4. Library</b></a></summary>

    * [4.1 Sections](#41-sections)
    * [4.2 Items by type](#42-items-by-type)
    * [4.3 Filters](#43-filters)
    * [4.4 Genres and other facets](#44-genres-and-other-facets)
    * [4.5 Single item](#45-single-item)
    * [4.6 Children and leaves](#46-children-and-leaves)
    * [4.7 Recently added, A-Z index and autocomplete](#47-recently-added-a-z-index-and-autocomplete)
    * [4.8 Albums, folders and categories](#48-albums-folders-and-categories)
    * [4.9 Collections](#49-collections)
    * [4.10 Editing and maintenance](#410-editing-and-maintenance)

    </details>

    <details>
    <summary><a href="#5-playlists"><b>5. Playlists</b></a></summary>

    * [5.1 Listing and counting](#51-listing-and-counting)
    * [5.2 Creating a playlist](#52-creating-a-playlist)
    * [5.3 Adding, removing and moving items](#53-adding-removing-and-moving-items)
    * [5.4 Renaming and deleting](#54-renaming-and-deleting)
    * [5.5 Smart playlists and import](#55-smart-playlists-and-import)

    </details>

    <details>
    <summary><a href="#6-search"><b>6. Search</b></a></summary>

    * [6.1 Hub search](#61-hub-search)
    * [6.2 Section search](#62-section-search)
    * [6.3 Flat and voice search](#63-flat-and-voice-search)

    </details>

    <details>
    <summary><a href="#7-playback-reporting"><b>7. Playback reporting</b></a></summary>

    * [7.1 Timeline reports](#71-timeline-reports)
    * [7.2 When a play counts](#72-when-a-play-counts)
    * [7.3 Scrobble and unscrobble](#73-scrobble-and-unscrobble)
    * [7.4 Ratings and favourites](#74-ratings-and-favourites)

    </details>

    <details>
    <summary><a href="#8-streaming-and-transcoding"><b>8. Streaming and transcoding</b></a></summary>

    * [8.1 Audio transcode](#81-audio-transcode)
    * [8.2 Direct file URL](#82-direct-file-url)
    * [8.3 Transcode sessions](#83-transcode-sessions)
    * [8.4 Video decision](#84-video-decision)
    * [8.5 Video URL](#85-video-url)
    * [8.6 Transcoder URLs](#86-transcoder-urls)
    * [8.7 Lyrics](#87-lyrics)
    * [8.8 Loudness](#88-loudness)

    </details>

    <details>
    <summary><a href="#9-sessions"><b>9. Sessions</b></a></summary>

    * [9.1 Active sessions](#91-active-sessions)
    * [9.2 Playback history](#92-playback-history)
    * [9.3 Terminating a session](#93-terminating-a-session)

    </details>

    <details>
    <summary><a href="#10-play-queues"><b>10. Play queues</b></a></summary>

    * [10.1 Creating a queue](#101-creating-a-queue)
    * [10.2 Reading and editing](#102-reading-and-editing)
    * [10.3 Shuffle, reset and clear](#103-shuffle-reset-and-clear)

    </details>

    <details>
    <summary><a href="#11-images"><b>11. Images</b></a></summary>

    * [11.1 Resized artwork](#111-resized-artwork)
    * [11.2 Artwork versions and cache keys](#112-artwork-versions-and-cache-keys)
    * [11.3 UltraBlur backdrops](#113-ultrablur-backdrops)

    </details>

    <details>
    <summary><a href="#12-hubs"><b>12. Hubs</b></a></summary>

    * [12.1 Home and section hubs](#121-home-and-section-hubs)
    * [12.2 Promoted and on deck](#122-promoted-and-on-deck)
    * [12.3 Drilling into a hub](#123-drilling-into-a-hub)
    * [12.4 Hubs of an item](#124-hubs-of-an-item)
    * [12.5 Managing a section's hubs](#125-managing-a-sections-hubs)

    </details>

    <details>
    <summary><a href="#13-similar-items-and-sonic-radio"><b>13. Similar items and sonic radio</b></a></summary>

    * [13.1 Similar items](#131-similar-items)
    * [13.2 Sonically nearest tracks](#132-sonically-nearest-tracks)
    * [13.3 Nearest tracks in a section](#133-nearest-tracks-in-a-section)

    </details>

    <details>
    <summary><a href="#14-live-tv-and-dvr"><b>14. Live TV and DVR</b></a></summary>

    * [14.1 Live sessions](#141-live-sessions)
    * [14.2 DVRs](#142-dvrs)
    * [14.3 Recording subscriptions](#143-recording-subscriptions)
    * [14.4 Tuners and the program guide](#144-tuners-and-the-program-guide)

    </details>

    <details>
    <summary><a href="#15-error-handling"><b>15. Error handling</b></a></summary>

    * [15.1 PlexException](#151-plexexception)
    * [15.2 Classifying a failure](#152-classifying-a-failure)

    </details>

    <details>
    <summary><a href="#16-cancellation-and-retries"><b>16. Cancellation and retries</b></a></summary>

    * [16.1 Cancelling requests](#161-cancelling-requests)
    * [16.2 Retry policy](#162-retry-policy)

    </details>

    <details>
    <summary><a href="#17-paging"><b>17. Paging</b></a></summary>

    * [17.1 Page parameters](#171-page-parameters)
    * [17.2 Walking every page](#172-walking-every-page)

    </details>

    <details>
    <summary><a href="#18-notifications-and-events"><b>18. Notifications and events</b></a></summary>

    * [18.1 Connecting](#181-connecting)
    * [18.2 Typed events](#182-typed-events)

    </details>

    <details>
    <summary><a href="#19-downloads"><b>19. Downloads</b></a></summary>

    * [19.1 Downloading to a file](#191-downloading-to-a-file)
    * [19.2 Download queues](#192-download-queues)

    </details>

    <details>
    <summary><a href="#20-escape-hatch"><b>20. Escape hatch</b></a></summary>

    * [20.1 Raw request](#201-raw-request)
    * [20.2 Raw bytes and streams](#202-raw-bytes-and-streams)

    </details>
*   [Project background](#project-background)

---

## Features

<table>
<tr>
<td valign="middle" width="48"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/package.png" width="32"></td>
<td valign="middle" width="45%"><b>Pure Dart</b><br>no native plugin and no Flutter dependency. The main library also runs on the web; only the file helpers in <code>io.dart</code> need <code>dart:io</code>.</td>
<td valign="middle" width="48"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/shield-check.png" width="32"></td>
<td valign="middle" width="45%"><b>Typed models</b><br>libraries, items, media, streams, hubs, server info, history and events are typed Dart objects, each with a <code>raw</code> map for the fields it does not lift.</td>
</tr>
<tr>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/key-round.png" width="32"></td>
<td valign="middle"><b>Both sign-in flows</b><br>the <a href="#21-pin-flow">PIN flow</a> at <code>plex.tv/link</code> and <a href="#22-username-and-password">username and password</a>.</td>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/globe.png" width="32"></td>
<td valign="middle"><b>Server discovery</b><br><code>fetchResources()</code> lists owned and shared servers; <a href="#24-finding-servers"><code>bestConnection()</code></a> picks local first, then HTTPS, then relay.</td>
</tr>
<tr>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/layers.png" width="32"></td>
<td valign="middle"><b>One client</b><br>a <code>PlexClient</code> holds the identity, the server and the token, and every sub-API works through it.</td>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/audio-lines.png" width="32"></td>
<td valign="middle"><b>Audio streaming</b><br><a href="#81-audio-transcode"><code>startAudioTranscode()</code></a> starts an HLS or DASH transcode with a bitrate cap; <a href="#82-direct-file-url"><code>directFileUrl()</code></a> gives the original file.</td>
</tr>
<tr>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/sliders-horizontal.png" width="32"></td>
<td valign="middle"><b>Your HTTP stack</b><br><a href="#13-choosing-the-http-stack">any <code>http.Client</code></a>: the default <code>dart:io</code> one, <code>cupertino_http</code> or <code>cronet_http</code> for HTTP/2 and the system proxy, a <code>MockClient</code> in tests.</td>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/cpu.png" width="32"></td>
<td valign="middle"><b>Off the calling isolate</b><br>large responses are inflated, decoded and parsed into models on a background isolate.</td>
</tr>
<tr>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/zap.png" width="32"></td>
<td valign="middle"><b>Cancellation and retries</b><br><a href="#161-cancelling-requests"><code>withCancelToken()</code></a> makes every call of a page cancellable; an opt-in <a href="#162-retry-policy"><code>PlexRetryPolicy</code></a> resends idempotent requests after transient failures.</td>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/activity.png" width="32"></td>
<td valign="middle"><b>Live events</b><br>the server's notifications decoded into a sealed <a href="#182-typed-events"><code>PlexEvent</code></a> type: play states, library changes, scans.</td>
</tr>
<tr>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/triangle-alert.png" width="32"></td>
<td valign="middle"><b>Typed errors</b><br>every failure is a <a href="#15-error-handling"><code>PlexException</code></a> you can branch on: auth, not found, network, transient, cancelled.</td>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/terminal.png" width="32"></td>
<td valign="middle"><b>Escape hatch</b><br><a href="#20-escape-hatch"><code>request()</code></a>, <code>requestBytes()</code> and <code>requestStream()</code> reach endpoints the typed sub-APIs do not cover.</td>
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

  // 1. Sign in: the user enters the code at plex.tv/link.
  final pin = await plex.account.createPin();
  print('Enter ${pin.code} at https://plex.tv/link');
  var state = pin;
  while (!state.isAuthenticated) {
    await Future<void>.delayed(const Duration(seconds: 2));
    state = await plex.account.pollPin(id: pin.id);
  }
  plex.setToken(state.authToken);

  // 2. Find the user's server and connect to it.
  final servers = await plex.account.fetchResources();
  final server = servers.firstWhere((s) => s.owned);
  plex.connect(server.bestConnection()!.uri, accessToken: server.accessToken);

  // 3. Browse the music library.
  final sections = await plex.library.sections();
  final music = sections.firstWhere((s) => s.type == PlexLibraryType.music);
  final albums = await plex.library.allByType(
    sectionId: music.id,
    type: PlexMetadataType.album,
    sort: 'titleSort:asc',
  );

  // 4. Stream the first track of the first album.
  final tracks =
      await plex.library.children(ratingKey: albums.items.first.ratingKey);
  final transcode = await plex.streaming.startAudioTranscode(
    ratingKey: tracks.first.ratingKey,
    session: 'a-uuid-per-playback',
    maxBitrateKbps: 192,
  );
  print(transcode.url); // hand this to your audio engine

  // 5. Release the HTTP client.
  plex.close();
}
```

---

## Guide

`PlexClient` holds the identity of your app, the server and the token. Each part of the Plex API is a sub-API on it (`plex.library`, `plex.playlists`, `plex.streaming` and so on), and every call goes through one connection, the same transport `dart_jellyfin` uses.

<img src="https://raw.githubusercontent.com/ales-drnz/dart_plex/main/imgs/diagrams/architecture.png" width="100%" alt="Architecture: your code calls PlexClient; PlexConnection sends through an http.Client and parses large answers on a background isolate into typed models">

### 1. Initialization and lifecycle

<img src="https://raw.githubusercontent.com/ales-drnz/dart_plex/main/imgs/diagrams/client_lifecycle.png" width="100%" alt="Client lifecycle: PlexClient, sign in and connect, sub-APIs, withCancelToken, close">

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

| Argument | Default | Description |
| :--- | :--- | :--- |
| `httpClient` | a `dart:io` client owned by `PlexClient` | Any `http.Client`, see [1.3](#13-choosing-the-http-stack) |
| `connectTimeout` | 15 s | The handshake (default client) and, with `receiveTimeout`, the wait for response headers |
| `receiveTimeout` | 30 s | Also bounds every pause inside a response body |
| `jsonIsolateThreshold` | 50 KB | Responses this large or larger are decoded and parsed on a background isolate |
| `retryPolicy` | `PlexRetryPolicy.none` | See [16.2](#162-retry-policy) |

Above `jsonIsolateThreshold` the JSON decode and the walk that builds the
typed models both run on a background isolate, and so does the gzip
inflate of the default client. Pass `0` to send every response there, or
a very large value to keep everything on the calling isolate.

#### 1.2 Credentials

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
| `clientProfileExtra` | `X-Plex-Client-Profile-Extra`: extra transcode targets for this client. `startAudioTranscode()` sends its own ([8.1](#81-audio-transcode)) |

`copyWith` returns a copy with some fields replaced.

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

Native clients inflate gzip on their own threads; the background isolate
still decodes and parses the JSON.

#### 1.4 Closing

```dart
plex.clearSession(); // drops the token, keeps the server
plex.disconnect();   // drops the token and the server; the client stays usable
plex.close();        // releases the HTTP client
```

`close()` closes the HTTP client that `PlexClient` created. Requests made
afterwards fail with `PlexErrorType.state`. An injected `httpClient` stays
open: close it yourself.

#### 1.5 Faking the client in tests

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

---

### 2. Sign-in and server discovery

<img src="https://raw.githubusercontent.com/ales-drnz/dart_plex/main/imgs/diagrams/sign_in_flow.png" width="100%" alt="Sign-in: createPin, the user enters the code at plex.tv/link, pollPin until a token, setToken; then fetchResources, bestConnection and connect">

Sign-in talks to plex.tv and returns a token. `setToken` applies it to the
client; no call applies it for you.

#### 2.1 PIN flow

The PIN flow works for every account, two-factor authentication
included. The user enters a 4-character code at `plex.tv/link`:

```dart
final pin = await plex.account.createPin();
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

`createPin()` asks for a strong (JWT) PIN; pass `strong: false` for the
classic kind. A PIN expires after about 15 minutes (`expiresAt`).

#### 2.2 Username and password

```dart
final user = await plex.account.signInWithPassword(
  username: 'me@example.com',
  password: 'hunter2',
);
plex.setToken(user.authToken);
```

Accounts with two-factor authentication cannot use this flow; prefer the
PIN flow. Bad credentials throw a `PlexException` of type `auth`.

#### 2.3 Account and sign-out

```dart
final me = await plex.account.currentUser();
print('${me.username} (${me.email}), Plex Pass: ${me.hasPlexPass}');

await plex.account.signOut(); // invalidates the token at plex.tv
plex.setToken(null);
```

`PlexUser` carries `id`, `uuid`, `username`, `email`, `thumb`,
`authToken` and `hasPlexPass`. Once connected to a server,
`tokenDetails()` describes the token in use and `connectedUsers()` lists
the server's users (admin only); both return the server's maps.

#### 2.4 Finding servers

```dart
final servers = await plex.account.fetchResources(includeRelay: false);
final server = servers.firstWhere((s) => s.owned);
final connection = server.bestConnection();
```

`includeHttps`, `includeRelay` and `includeIPv6` are on by default.
`serverOnly` (on by default) keeps the resources that provide `server`,
leaving out players and clients.

Each `PlexResource` carries `name`, `clientIdentifier`, `platform`,
`productVersion`, `owned`, `home`, `relay`, `presence`, `httpsRequired`,
`accessToken` (the token for that server) and `connections`.

`bestConnection()` returns `null` when there are no connections, and
otherwise picks in this order:

1. Local, not relayed
2. HTTPS, not relayed
3. Any connection not relayed
4. Relay

Each `PlexServerConnection` has `protocol`, `address`, `port`, `uri`,
`local`, `relay` and `ipv6`, so you can apply your own choice, for
example race the candidates with a short timeout.

#### 2.5 Connecting to a server

```dart
plex.connect(connection.uri, accessToken: server.accessToken);
```

Pass the resource's `accessToken`: a shared server does not accept the
account token. A client talks to one server at a time; `connect()` again
to switch, or create a second `PlexClient` with the same credentials to
keep two servers.

---

### 3. Server

#### 3.1 Identity and info

```dart
final id = await plex.server.identity();
print('${id.machineIdentifier} ${id.version} claimed=${id.claimed}');

final info = await plex.server.info();
print('${info.friendlyName} ${info.version} on ${info.platform}');
print('Plex Pass: ${info.myPlexSubscription}, '
    'sonic analysis: ${info.musicAnalysis}');

if (await plex.server.ping()) { /* reachable */ }
```

`identity()` needs no token, so it checks a server URL before you sign in
again. `info()` adds `friendlyName`, `platform`, `platformVersion`,
`myPlex`, `myPlexUsername`, `musicAnalysis`, `transcoderAudio`,
`transcoderLyrics`, `allowSync`, `countryCode` and `updatedAt`. `ping()`
returns `false` instead of throwing; call `identity()` to see why a
server is unreachable.

#### 3.2 Activities, butler tasks and settings

```dart
final running = await plex.activities.list(); // List<PlexActivity>
for (final a in running) {
  print('${a.title} ${a.progress ?? 0}% cancellable=${a.cancellable}');
}
final scan = running.where((a) => a.cancellable).firstOrNull;
if (scan != null) await plex.activities.cancel(activityId: scan.uuid);

final tasks = await plex.butler.tasks(); // List<PlexButlerTask>
await plex.butler.start(butlerTask: tasks.first.name);

final settings = await plex.preferences.all(); // List<PlexSetting>
final name = await plex.preferences.byId(id: 'FriendlyName');
await plex.preferences.set({'FriendlyName': 'Living room'});
print('${settings.length} settings, previous name ${name?.value}');
```

`butler.stop()`, `startAll()` and `stopAll()` control the other
maintenance tasks.

#### 3.3 Administration

These calls need an admin token and return the server's maps where no
model fits.

<details>
<summary><b>Server administration calls</b> (click to expand)</summary>

| Call | Does |
| :--- | :--- |
| `server.backgroundTasks()` | Lists background work: scans, intro detection |
| `server.transientToken()` | Issues a short-lived delegation token, for a cast target or a viewer link |
| `server.securityResources(source:)` | Connection info for a source, for cross-server playback |
| `log.writeMessage(level:, message:, source:)` | Writes one line to the server log; `level` is 0 (error) to 4 (verbose) |
| `log.writeBlock(body:)` | Appends a multi-line body to the server log |
| `log.enablePapertrail(minutes:)` | Forwards the log to Papertrail for a while |
| `updater.status()`, `check()`, `apply()` | Server software updates; `apply(tonight: true)` waits for the quiet hours |
| `providers.list()`, `add(url:)`, `refresh()`, `delete(provider:)` | Media providers registered on the server |

</details>

---

### 4. Library

#### 4.1 Sections

```dart
final sections = await plex.library.sections();
for (final s in sections) {
  print('${s.type.name}: ${s.title} (id=${s.id})');
}
```

`PlexLibraryType` is `music`, `movie`, `show`, `photo` or `unknown`.
`id` is the section key that every section call takes as `sectionId`.
Each section also carries `agent`, `scanner`, `language`, `locations`,
`scannedAt` and `createdAt`.

#### 4.2 Items by type

```dart
final page = await plex.library.allByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
  start: 100,
  size: 100,
  sort: 'titleSort:asc',
);
print('Got ${page.items.length} of ${page.totalSize}');

final count = await plex.library.countByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
);
```

`allByType()` returns a `PlexMediaContainer` page (50 rows from `start`
by default) with `items`, `totalSize` and the envelope's other fields in
`raw`. `countByType()` sends the same request with an empty page, so the
count always matches what `allByType()` would list; it takes the same
`filters`.

`PlexMetadataType` carries the server's numeric values:

| Type | Value | Type | Value |
| :--- | :--- | :--- | :--- |
| `movie` | 1 | `album` | 9 |
| `show` | 2 | `track` | 10 |
| `season` | 3 | `photoAlbum` | 13 |
| `episode` | 4 | `photo` | 14 |
| `trailer` | 5 | `playlist` | 15 |
| `artist` | 8 | `collection` | 18 |

Sort examples: `'titleSort:asc'`, `'addedAt:desc'`,
`'lastViewedAt:desc'`, `'originallyAvailableAt:desc'`, `'random:<seed>'`.

#### 4.3 Filters

`filters` narrows `allByType()`, `countByType()` and the playlist list.
Each condition is a `PlexFilter`, sent as its own query parameter:

```dart
final page = await plex.library.allByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
  filters: [PlexFilter.genre(6), PlexFilter.yearAfter(2009)],
);
// GET /library/sections/3/all?type=9&genre=6&year>>=2009
```

A Plex filter is a query parameter named after the field, with the
operator in the name, so the operator comes from the constructor you
pick:

| Constructor | Sends |
| :--- | :--- |
| `PlexFilter.genre(6)` | `genre=6` |
| `PlexFilter.genre(6, exclude: true)` | `genre!=6` |
| `PlexFilter.tag('mood', [3, 7])` | `mood=3,7` (any of) |
| `PlexFilter.of(tag)` | the tag's own field and id ([4.4](#44-genres-and-other-facets)) |
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
| `PlexFilter.studio('A24')` | `studio=A24` |
| `PlexFilter.contentRating('PG')` | `contentRating=PG` |
| `PlexFilter.resolution('4k')` | `resolution=4k` |

Conditions in the list are ANDed; several values in one condition are
ORed. Tag fields (genre, mood, style) take the numeric tag id, never the
name. Two conditions on the same parameter throw a `PlexException` of
type `state`, since one would overwrite the other.

The server ignores a parameter it does not know and answers unfiltered,
so ask each section which fields it accepts with `filters()`
([4.4](#44-genres-and-other-facets)). For a field without a named
constructor, use
`PlexFilter(field: ..., values: [...], operator: PlexFilterOperator...)`,
or `PlexFilter.number`, `PlexFilter.text` and `PlexFilter.flag`.

#### 4.4 Genres and other facets

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

Each `PlexTag` carries the numeric `id` the server filters by and the
`field` it belongs to, so `PlexFilter.of()` builds the condition with
nothing spelled by hand. `id` is `null` when the server sent nothing
usable, and `PlexFilter.of()` then throws instead of sending a query that
would come back unfiltered.

`filters()` lists the facets a section can be filtered on, and
`filterValues()` lists the values of one:

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

`PlexLibraryFilter.field` is the query parameter to use. A flag facet such
as `unwatched` has no values, and `filterValues()` throws a
`PlexException` of type `state` for it. `sectionSorts()` lists the sorts
a section offers.

#### 4.5 Single item

```dart
final item = await plex.library.item(ratingKey: '12345');
if (item != null) {
  print(item.title);
  print(item.media.first.audioCodec); // e.g. 'flac'
}
```

`item()` returns `null` when the answer holds no item; a rating key the
server does not know throws a `PlexException` whose `isNotFound` is true.
The full item is the place for `media` with its parts and streams
(`audioStream`, [loudness](#88-loudness), [lyrics](#87-lyrics)),
`librarySectionId` and `leafCount`; list responses usually leave them
out.

`PlexMetadata` carries the item's titles, its parent and grandparent
(`parentTitle`, `grandparentRatingKey` and so on), `genres`, `moods`,
`styles`, `roles` (a track's performers when it has more than one),
counts (`leafCount`, `childCount`, `viewedLeafCount`, `viewCount`,
`skipCount`), dates (`addedAt`, `lastViewedAt`, `originallyAvailableAt`,
`lastRatedAt`), `userRating`, `durationMs` and `raw`.

#### 4.6 Children and leaves

```dart
// An album's tracks, an artist's albums, a season's episodes.
final tracks = await plex.library.children(ratingKey: album.ratingKey);

// Sorted and paged.
final newestAlbums = await plex.library.children(
  ratingKey: artist.ratingKey,
  sort: 'year:desc',
  size: 20,
);

// How many, without transferring them.
final albumCount = await plex.library.countChildren(ratingKey: artist.ratingKey);

// Every track of an artist in album order.
final artistTracks = await plex.library.grandchildren(
  ratingKey: artist.ratingKey,
  size: 100,
);

// Every leaf under an item: an artist's tracks, a show's episodes.
final leaves = await plex.library.allLeaves(ratingKey: artist.ratingKey);
```

Without `size` these calls return every row; with `size` they return one
page ([17.1](#171-page-parameters)). `children()` takes the section sort
syntax. `allLeaves()` has no sort: the server ignores it and answers in
library order. `sectionAllLeaves(sectionId:)` returns every leaf of a
section.

#### 4.7 Recently added, A-Z index and autocomplete

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

// Suggestions while the user types.
final suggestions = await plex.library.autocomplete(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
  fieldQuery: {'title.query': 'Abb'},
);
```

In a music section `recentlyAdded()` returns albums: the server ignores a
type there, so the call takes none. Jump to a letter of the index with
`PlexFilter.firstCharacter('A')` on `allByType()`. `autocomplete()` needs
`type`: the server answers 400 without it. It returns the server's map.

#### 4.8 Albums, folders and categories

```dart
final albums = await plex.library.albums(sectionId: musicLib.id, size: 100);
final folders = await plex.library.folderLocations(sectionId: musicLib.id);
final categories = await plex.library.categories(sectionId: photoLib.id);
```

`albums()` pages a music section's albums without the sort and filter
parameters of `allByType()`. `folderLocations()` returns the section's
scanned folders and `categories()` the server's categories, mostly for
photo libraries. `sectionArts()`, `sectionClusters()` and
`sectionMoments()` return a section's backdrops and its photo clusters
and moments, `sectionCollections()` its collections and `all()` every
item of every section.

#### 4.9 Collections

A collection is a metadata item with its own rating key, so `item()` and
`children()` work on it. `plex.collections` creates and edits them:

```dart
final machineId = (await plex.server.identity()).machineIdentifier;
final seed = PlexPlayQueuesApi.seedFromItems(
  machineIdentifier: machineId,
  ratingKeys: const ['12345', '12346'],
);

final collection = await plex.collections.create(
  sectionId: musicLib.id,
  title: 'Road trip',
  type: '${PlexMetadataType.album.value}',
  seedUri: seed,
);
final items = await plex.collections.items(collectionId: collection.ratingKey);

await plex.collections.moveItem(
  collectionId: collection.ratingKey,
  itemId: items.last.ratingKey,
  afterItemId: '0', // to the start
);
await plex.collections.removeItem(
  collectionId: collection.ratingKey,
  itemId: items.first.ratingKey,
);
```

`addItems(collectionId:, uri:)` adds more items from a seed URI. A smart
collection (`smart: true`) needs a `seedUri`. `compositeImageUrl()` builds
the URL of the collection's composite cover, and
`library.deleteSectionCollection()` deletes one.

#### 4.10 Editing and maintenance

`plex.library` also edits metadata and runs library maintenance. These
calls need an admin token. Most take `ids`, one rating key or several
joined by commas.

```dart
await plex.library.editItem(
  ids: album.ratingKey,
  type: PlexMetadataType.album,
  args: {'title.value': 'New title', 'title.locked': 1},
);
await plex.library.refreshSection(sectionId: musicLib.id);
```

`<field>.value` sets a field and `<field>.locked` keeps the agent from
overwriting it. `updateSectionItems()` edits every item matching a
`filterExpression` in one call.

<details>
<summary><b>Editing and maintenance calls</b> (click to expand)</summary>

| Area | Calls |
| :--- | :--- |
| Items | `editItem`, `deleteMetadataItem`, `deleteMediaItem`, `refreshItems`, `analyzeItem`, `matchItem`, `listMatches`, `unmatch`, `mergeItems`, `splitItem`, `setItemPreferences` |
| Detection | `detectIntros`, `detectCredits`, `detectAds`, `detectVoiceActivity`, `generateChapterThumbs`, `startBifGeneration` |
| Markers | `createMarker`, `editMarker`, `deleteMarker` |
| Artwork and extras | `itemArtworkUrl`, `setItemArtwork`, `extras`, `addExtra`, `addSubtitles`, `chapterImageUrl`, `itemFileUrl` |
| Item reads | `relatedItems`, `itemTree`, `topUsers`, `person`, `personMedia` |
| Streams and parts | `streamUrl`, `setStreamOffset`, `deleteStream`, `streamLoudness`, `streamLevels`, `setPartStreamSelection`, `partFileUrl`, `partIndex`, `partBifThumbUrl` |
| Sections | `addSection`, `editSection`, `deleteSection`, `sectionDetails`, `sectionPreferences`, `setSectionPreferences`, `defaultSectionPrefs`, `sectionCommon`, `sectionsAll`, `sectionCompositeImageUrl` |
| Scanning | `refreshSection`, `cancelSectionRefresh`, `analyzeSection`, `refreshAllSections`, `stopAllRefreshes`, `emptyTrash` |
| Housekeeping | `deleteSectionIndexes`, `deleteSectionIntros`, `deleteCaches`, `cleanBundles`, `optimizeDatabase`, `ingestTransientItem` |
| Index reads | `tags`, `randomArtwork`, `matches` |

</details>

---

### 5. Playlists

#### 5.1 Listing and counting

```dart
final audio = await plex.playlists.list(type: 'audio', size: 100);

// Narrowed by the server: title contains "mix", and rated.
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

`type` is `'audio'`, `'video'` or `'photo'`, and `smart` keeps only smart
(`true`) or regular (`false`) playlists. `filters` and `sort` work as on
`allByType()` ([4.3](#43-filters)); the title filter matches without
regard to case. `list()` returns 50 playlists from `start` by default.
Each entry is a `PlexMetadata` of type `playlist`.

#### 5.2 Creating a playlist

```dart
final machineId = (await plex.server.identity()).machineIdentifier;

final playlist = await plex.playlists.create(
  title: 'My Mix',
  type: 'audio',
  machineIdentifier: machineId,
  itemRatingKeys: const ['12345', '12346', '12347'],
);
```

The server's `machineIdentifier` builds the URI of the items. Leave
`itemRatingKeys` out to create an empty playlist.

#### 5.3 Adding, removing and moving items

```dart
await plex.playlists.addItems(
  playlistId: playlist.ratingKey,
  machineIdentifier: machineId,
  itemRatingKeys: const ['99999'],
);

final entries = await plex.playlists.items(playlistId: playlist.ratingKey);

// Remove one entry.
final added = entries.firstWhere((e) => e.ratingKey == '99999');
await plex.playlists.removeItem(
  playlistId: playlist.ratingKey,
  playlistItemId: added.playlistItemId!,
);

// Move the last entry to the start (no afterPlaylistItemId).
await plex.playlists.moveItem(
  playlistId: playlist.ratingKey,
  playlistItemId: entries.last.playlistItemId!,
);
```

`removeItem()` and `moveItem()` take the entry id,
`PlexMetadata.playlistItemId`, not the track's rating key, so a track
listed twice loses or moves only the entry you name. Items read with
`items()` carry it. Pass `size` (and `start`) to `items()` to read one
page of a long playlist.

#### 5.4 Renaming and deleting

```dart
await plex.playlists.rename(playlistId: playlist.ratingKey, title: 'New name');
await plex.playlists.delete(playlistId: playlist.ratingKey);
```

#### 5.5 Smart playlists and import

```dart
final generators = await plex.playlists.generators(playlistId: smart.ratingKey);
final generatorId = '${generators.first['id']}';
final produced = await plex.playlists.generatorItems(
  playlistId: smart.ratingKey,
  generatorId: generatorId,
);

// Import .m3u files from a path on the server.
final imported = await plex.playlists.upload(path: '/srv/music/playlists');
```

`generators()` returns the server's maps for the generators that feed a
smart playlist. `reprocessGenerator()` runs one again with the action
`'reprocess'`, `'disable'` or `'enable'`. `upload()` turns each `.m3u`
file at `path` into a playlist; with `force: false` an existing playlist
from the same path is kept and the import gets a new, dated name.

---

### 6. Search

#### 6.1 Hub search

```dart
final hubs = await plex.search.hubs(
  query: 'pink floyd',
  sectionId: musicLib.id, // optional: one library only
);

for (final hub in hubs) {
  print('${hub.title} (${hub.type})');
  for (final hit in hub.items) {
    print('  - ${hit.title} (score ${hit.score})');
  }
}
```

`hubs()` returns one `PlexHub` per kind of result (artists, albums,
tracks), at most `limit` (10) in each. It suits search as you type.

#### 6.2 Section search

```dart
final tracks = await plex.search.section(
  sectionId: musicLib.id,
  query: 'money',
  type: PlexMetadataType.track,
  limit: 20,
);
```

One section and one kind of item, as a flat list: the shape for a
"tracks matching" view. `type` is required: the server answers 400
without it.

#### 6.3 Flat and voice search

```dart
final results = await plex.search.flat(query: 'pink floyd', limit: 50);

final spoken = await plex.search.voice(
  query: 'play something by pink floyd',
  type: PlexMetadataType.track,
);
```

`flat()` returns every kind of item in one list. `voice()` reads the
query as a spoken phrase and returns hubs like `hubs()`; the server
matches it slowly, so scope it with `type`.

---

### 7. Playback reporting

<img src="https://raw.githubusercontent.com/ales-drnz/dart_plex/main/imgs/diagrams/play_reporting.png" width="100%" alt="Timeline reports at each change and every 10 seconds; the play counts after about half the track in real time">

#### 7.1 Timeline reports

```dart
await plex.playback.timeline(
  ratingKey: track.ratingKey,
  playState: PlexPlayState.playing, // playing, paused, buffering or stopped
  timeMs: 42000,
  durationMs: track.durationMs!,
  playQueueItemID: queueItemId, // only when playing a server play queue
);
```

Send a report on every state change and every 10 s while playing on a
LAN (20 s on cellular). `durationMs` is the item's length and `timeMs`
the playhead, both in milliseconds. A `timeMs` past `durationMs` is sent
as `durationMs`. `timeline()` throws an `ArgumentError` for a `durationMs`
of 0 or less, a negative `timeMs` or `PlexPlayState.unknown`.

`playQueueItemID` is the entry id in a server play queue
([10](#10-play-queues)); leave it `null` otherwise. `continuing: true`
says another track follows in the same playback, so the server keeps the
transcode session, which matters during gapless prefetch.

#### 7.2 When a play counts

The server counts a play when:

* the reports follow real time: it clocks the session itself, so a
  `playing` at 0 and a `stopped` at the end a moment later count nothing;
* about half of the reported duration was played;
* `durationMs` is the real length: with a duration of 0 nothing ever
  counts. Very short tracks are not counted.

A counted play raises `viewCount`, sets `lastViewedAt` and adds an entry
to the playback history ([9.2](#92-playback-history)).

#### 7.3 Scrobble and unscrobble

```dart
await plex.playback.scrobble(ratingKey: track.ratingKey);   // mark as played
await plex.playback.unscrobble(ratingKey: track.ratingKey); // mark as unplayed
```

`scrobble()` raises `viewCount` without adding a history entry: use it
for "mark as played", and timeline reports to record listening.
`unscrobble()` clears `viewCount` and keeps the history.

#### 7.4 Ratings and favourites

```dart
await plex.playback.rate(ratingKey: track.ratingKey, rating: 7.5); // 0 to 10
await plex.playback.setFavorite(ratingKey: track.ratingKey, isFavorite: true);
```

Plex has no favourite flag: a favourite is a `userRating` of 10.
`setFavorite()` rates 10 or 0, and `PlexMetadata.isFavorite` reads it
back. To list favourites, filter a section with
`PlexFilter.ratingAbove(9)` ([4.3](#43-filters)).

---

### 8. Streaming and transcoding

<img src="https://raw.githubusercontent.com/ales-drnz/dart_plex/main/imgs/diagrams/audio_transcode_sequence.png" width="100%" alt="Audio transcode: startAudioTranscode makes the decision and returns the URL; the player opens it; pingUniversal while paused; stopUniversal at the end">

The streaming calls return URLs; none of them fetches the audio. Hand the
URL to your audio engine (mpv, AVPlayer, ExoPlayer). The URL carries
`X-Plex-Token` in its query, so segment requests need no headers.

#### 8.1 Audio transcode

```dart
final transcode = await plex.streaming.startAudioTranscode(
  ratingKey: track.ratingKey,
  session: 'my-uuid',   // one per playback session
  protocol: 'dash',     // 'hls' (default, an .m3u8) or 'dash' (an .mpd)
  maxBitrateKbps: 128,
);
if (transcode.decision.isPlayable) {
  print(transcode.url); // hand to the player
}
```

`startAudioTranscode()` asks the server for a decision for `session`,
then builds the `start` URL from the same parameters. It names a client
profile (`clientProfileName`, `'Generic'` by default), so it works from
any platform, and sends the transcode target and the bitrate cap the
server expects. `audioCodec` is `'aac'` by default; `offsetSeconds`,
`mediaIndex` and `partIndex` pick where and what to play. The cap cannot
go above the profile's own ceiling, 256 kbps AAC for `Generic`.

When `decision.isPlayable` is false the URL does not play either. Stop
each session you stop playing ([8.3](#83-transcode-sessions)): while
other transcodes of the same client stay open, a new session's bitrate
cap may not apply. To make the decision yourself,
`PlexStreamingApi.musicProfileExtra()` builds the same profile value for
`decisionUniversal()`.

#### 8.2 Direct file URL

```dart
final (url, ext) = plex.streaming.directFileUrl(
  partKey: track.media.first.parts.first.key!,
);
```

The original file, with no transcode. Use it for downloads
([19.1](#191-downloading-to-a-file)) and for players that decode whatever
the file contains. `ext` is the file's extension.

The server sends an MP3 without its ID3v2 tag, so a downloaded MP3 has no
embedded tags or cover and is a little shorter than `PlexPart.size`. Take
metadata and artwork from the server.

#### 8.3 Transcode sessions

```dart
await plex.streaming.pingUniversal(session: sessionId); // keep alive
await plex.streaming.stopUniversal(session: sessionId); // tear down
```

The same calls serve audio and video sessions. The server drops a
session after about 2 minutes without requests: ping every 30 s while
the player is paused, and stop the session when the user leaves.
`pingUniversal()` throws a `PlexException` of type `notFound` once the
session is gone. `stopUniversal()` returns normally when the session no
longer exists, or never started: the server creates a DASH session with
its first segment.

#### 8.4 Video decision

For video, ask the server for a decision first. It weighs the source
against your client profile and answers with `generalDecisionCode`: 1xxx
means playback can succeed; 2xxx (general), 3xxx (direct play) and 4xxx
(transcode) are errors.

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
    // The profile for this call only, instead of
    // PlexCredentials.clientProfileExtra.
    'X-Plex-Client-Profile-Extra':
        'add-transcode-target(type=videoProfile&context=streaming'
            '&protocol=hls&container=mpegts&videoCodec=h264&audioCodec=aac)',
  },
);

if (decision.isDirect) {
  // direct play or direct stream
} else if (decision.isTranscode) {
  // the server transcodes
} else {
  // not playable: bandwidth, codec mismatch, permissions
}
```

`transcodeType` is `'video'` by default; `'music'` and `'photo'` reach
the other transcoders. `isDirect` and `isTranscode` read
`directPlayDecisionCode` and `transcodeDecisionCode`; the whole answer is
in `raw`.

#### 8.5 Video URL

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

`protocol` (`'hls'` by default) and `container` (`'mpegts'`) pick the
target. The extension follows the protocol: `.m3u8` for HLS, `.mpd` for
DASH, the container otherwise. Bitrates are in kbps. The URL follows the
decision the server already made for the session.

#### 8.6 Transcoder URLs

`plex.transcoder` builds the raw transcoder URLs:

```dart
final cover = plex.transcoder.imageUrl(
  sourceUrl: album.thumb!,
  width: 600,
  height: 600,
  blur: 20,
  format: 'png',
);
final subtitles = plex.transcoder.subtitlesUrl(
  transcodeType: 'video',
  params: {'session': 'my-uuid'},
);
```

`imageUrl()` exposes every option of the photo transcoder (`quality`,
`blur`, `saturation`, `opacity`, `rotate`, `background`, `blendColor`).
`startUrl()` builds a `start.{extension}` URL from your own parameters,
and `triggerFallback()` asks the server for a full transcode after
direct play failed.

#### 8.7 Lyrics

```dart
final full = await plex.library.item(ratingKey: track.ratingKey);
final lyricsStream = full!.media.first.parts.first.streams
    .firstWhere((s) => s.isLyrics);
final lyrics = await plex.streaming.lyrics(streamKey: lyricsStream.key!);
```

The lyrics are a stream of the full item (`isLyrics`, stream type 4).
`lyrics()` returns the text, LRC or plain, or `null` when there is none.
It decodes the file whatever its encoding: a byte-order mark first
(removed, so the first `[mm:ss.xx]` still starts its line), then the
response's `charset`, then UTF-8 with Latin-1 as the fallback.

#### 8.8 Loudness

```dart
final full = await plex.library.item(ratingKey: track.ratingKey);
final audio = full?.audioStream;
if (audio != null && audio.hasLoudness) {
  print('track gain ${audio.gain} dB, album gain ${audio.albumGain} dB, '
      'peak ${audio.peak}, ${audio.loudness} LUFS');
}
```

An analysed audio stream carries `gain`, `albumGain`, `peak`,
`albumPeak`, `loudness` (LUFS) and `lra` (LU), from the server's own
analysis. They survive a transcode that drops the file's ReplayGain tags:
read them from the original stream and apply the gain to the transcoded
audio. `audioStream` is the selected audio stream of the first part.

---

### 9. Sessions

`plex.sessions` shows what plays on the server at the moment and what
played before.

#### 9.1 Active sessions

```dart
final sessions = await plex.sessions.active();
for (final s in sessions) {
  print('${s.user?.title} → ${s.metadata.title}'
      ' (${s.player?.state}, ${s.viewOffsetMs} ms,'
      ' ${s.transcodeSession == null ? 'direct' : 'transcode'})');
}
```

Each `PlexSession` carries the item as `metadata`, plus `user`, `player`,
`bandwidth`, `transcodeSession` and the `sessionId` that
[9.3](#93-terminating-a-session) takes.

#### 9.2 Playback history

```dart
final history = await plex.sessions.history(
  accountId: 1, // the owner
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
`deviceId`, `librarySectionId`), with `totalSize` for paging. `mindate`
and `maxdate` are Unix seconds, both inclusive. `historyItem()` reads one
entry and `deleteHistoryEntry(historyKey:)` removes one.

#### 9.3 Terminating a session

```dart
await plex.sessions.terminate(
  sessionId: session.sessionId!,
  reason: 'You started watching elsewhere',
);
```

`sessionId` is the session's own id, not the `session` of a transcode.
The user whose playback stops sees the `reason`.

---

### 10. Play queues

A play queue is a queue kept on the server: the current item, what comes
next and the shuffled order. A Plex player you cast to reuses it, and
another device can add to it. Local playback works without one, from
`library` and `streaming`.

#### 10.1 Creating a queue

```dart
final machineId = (await plex.server.identity()).machineIdentifier;

final queue = await plex.playQueues.create(
  type: 'audio',
  uri: PlexPlayQueuesApi.seedFromItems(
    machineIdentifier: machineId,
    ratingKeys: const ['12345', '12346', '12347'],
  ),
);
final queueId = queue.id;
```

`seedFromItems()` builds the seed URI from rating keys; a URI for one
album or artist seeds the queue with its tracks. `key` names the first
item to play, and an album-seeded queue shuffles only when it is set.
`shuffle` (off) and `continuous` (on) set the queue's mode. A
`PlexPlayQueue` carries `id`, `selectedItemId`, `shuffled`, `version`
and its `items`.

#### 10.2 Reading and editing

```dart
// The queue around the current entry.
final items = await plex.playQueues.items(
  playQueueId: queueId,
  center: queue.selectedItemId,
  window: 50,
);
// Each entry's own id in the queue.
final entryId = items.last.playQueueItemId!;

// Append, or play next.
await plex.playQueues.addItems(
  playQueueId: queueId,
  uri: PlexPlayQueuesApi.seedFromItems(
    machineIdentifier: machineId,
    ratingKeys: const ['99999'],
  ),
  playNext: true,
);

// Append every track of a Plex playlist.
await plex.playQueues.addItems(
  playQueueId: queueId,
  playlistId: playlist.ratingKey,
);

// Move an entry to the start (no afterPlaylistItemId), or remove it.
await plex.playQueues.moveItem(playQueueId: queueId, playQueueItemId: entryId);
await plex.playQueues.removeItem(playQueueId: queueId, playQueueItemId: entryId);
```

`addItems()` takes either `uri` or `playlistId`, not both. Pass the entry
id as `playQueueItemID` in timeline reports ([7.1](#71-timeline-reports)).

#### 10.3 Shuffle, reset and clear

```dart
await plex.playQueues.shuffle(playQueueId: queueId);
await plex.playQueues.unshuffle(playQueueId: queueId);
await plex.playQueues.reset(playQueueId: queueId); // first item is current again
await plex.playQueues.clear(playQueueId: queueId); // empty; the id stays valid
```

---

### 11. Images

#### 11.1 Resized artwork

```dart
final url = plex.images.transcodeUrl(
  sourcePath: item.thumb!, // e.g. '/library/metadata/123/thumb/1700000000'
  width: 300,
  height: 300,
);

final bytes = await plex.images.fetch(sourcePath: item.thumb!); // Uint8List?
```

The server resizes the image (500 × 500 by default) and sends a JPEG.
`fetch()` returns `null` on 404 and throws a `PlexException` on other
failures, so "no artwork" and "try again later" stay apart. For blur,
format and the other transcoder options see [8.6](#86-transcoder-urls).

#### 11.2 Artwork versions and cache keys

```dart
final cacheKey = '${album.ratingKey}@${album.thumbVersion}';
final version = PlexArtwork.versionOf('/library/metadata/123/thumb/1791659974');
// '1791659974'
```

An artwork path ends in a timestamp that changes whenever the image
does. Put it in your cache key and a cover replaced on the server is
fetched again. `thumbVersion`, `artVersion`, `parentThumbVersion` and
`grandparentThumbVersion` read it off a `PlexMetadata`; a track without
art of its own carries its album's thumb and version.

#### 11.3 UltraBlur backdrops

The server extracts four corner colours from an image and renders them
as a smooth gradient, for a backdrop behind a player screen:

```dart
final palettes = await plex.ultraBlur.colors(sourceUrl: album.thumb!);
final palette = palettes.first;

final url = plex.ultraBlur.imageUrl(
  topLeft: palette.topLeft,
  topRight: palette.topRight,
  bottomLeft: palette.bottomLeft,
  bottomRight: palette.bottomRight,
  width: 1920,
  height: 1080,
  noise: 1,
);
final png = await plex.ultraBlur.fetchImage(
  topLeft: palette.topLeft,
  topRight: palette.topRight,
  bottomLeft: palette.bottomLeft,
  bottomRight: palette.bottomRight,
  width: 1280,
  height: 720,
);
```

`sourceUrl` takes a library path or an absolute URL. The item details
may already carry the palette, as `PlexMetadata.ultraBlurColors`.
`noise: 1` adds dither against banding, for a backdrop behind text.
`fetchImage()` returns the PNG bytes, to cache yourself.

---

### 12. Hubs

Hubs are the rows of Plex's home screen: Recently Added, Continue
Listening, More from an artist. Each `PlexHub` is a titled row of items.

#### 12.1 Home and section hubs

```dart
final home = await plex.hubs.global(count: 8);
final musicHubs = await plex.hubs.forSection(sectionId: musicLib.id);

for (final hub in musicHubs) {
  print('${hub.title}: ${hub.items.length} items, more: ${hub.more}');
}
```

Each hub carries up to `count` items (16 by default) and `more` when it
has others behind a "Show all". `onlyTransient: true` keeps the hubs that
change with playback and additions.

#### 12.2 Promoted and on deck

```dart
final promoted = await plex.hubs.promoted();
final onDeck = await plex.hubs.continueWatching();
final musicOnDeck = await plex.hubs.sectionOnDeck(sectionId: musicLib.id);
```

`continueWatching()` and `sectionOnDeck()` return a `List<PlexMetadata>`,
not hubs.

#### 12.3 Drilling into a hub

```dart
final all = await plex.hubs.drill(
  hubKeyOrIdentifier: hub.hubKey, // or hub.hubIdentifier
  size: 100,
);
```

`drill()` pages the whole content of a hub with `more`.
`itemsByIdentifier(identifier:)` does the same from an identifier such as
`library.recentlyAdded.3`.

#### 12.4 Hubs of an item

```dart
final aroundAlbum = await plex.hubs.forMetadata(metadataId: album.ratingKey);
final related = await plex.hubs.related(metadataId: album.ratingKey);
final afterPlay = await plex.hubs.postplay(metadataId: track.ratingKey);
```

`forMetadata()` returns the discovery rows of an item, such as "More by
this artist", for music. `related()` returns related rows and
`postplay()` the suggestions to show when an item ends.

#### 12.5 Managing a section's hubs

With an admin token, `manage(sectionId:)` lists a section's hubs with
their promotion flags. `createCustom()`, `updateVisibility()`,
`deleteCustom()` and `move()` change them, and `resetSection()` restores
the defaults:

```dart
final configured = await plex.hubs.manage(sectionId: musicLib.id);
await plex.hubs.updateVisibility(
  sectionId: musicLib.id,
  identifier: configured.first.hubIdentifier,
  promotedToOwnHome: true,
);
```

---

### 13. Similar items and sonic radio

`similar()` returns what the server judges similar. The other two calls
read the sonic analysis the server keeps for music, so they need it
enabled (`PlexServerInfo.musicAnalysis`).

#### 13.1 Similar items

```dart
final picks = await plex.library.similar(ratingKey: album.ratingKey, count: 12);
```

Works for albums, artists, movies and shows.

#### 13.2 Sonically nearest tracks

```dart
final nearest = await plex.library.nearestToTrack(
  ratingKey: track.ratingKey,
  limit: 25,
  maxDistance: 0.25,
  excludeGrandparentRatingKey: track.grandparentRatingKey,
);
```

`excludeParentRatingKey` and `excludeGrandparentRatingKey` leave out the
album or the artist of the seed. Each result carries its `distance` from
the seed; smaller is closer.

#### 13.3 Nearest tracks in a section

```dart
// A track analysed by the server carries its sonic vector in raw.
final seed = (track.raw['musicAnalysis']! as List).cast<num>();
final radio = await plex.library.nearestInSection(
  sectionId: musicLib.id,
  values: seed,
  limit: 50,
);

// Tracks that bridge two songs.
final path = await plex.library.sonicPath(
  sectionId: musicLib.id,
  startId: track.ratingKey,
  endId: otherTrack.ratingKey,
);
```

`nearestInSection()` seeds the search from a sonic vector instead of a
track. Average the vectors of several tracks to build a radio for a
mood. `sonicPath()` returns tracks that lead from one song to another.

---

### 14. Live TV and DVR

Live TV streams broadcast channels through a tuner; the DVR records
programs to disk. Most of these calls return the server's maps
(`Map<String, Object?>`): check the type of a nested value before you
use it.

#### 14.1 Live sessions

```dart
final liveSessions = await plex.liveTv.sessions();
for (final entry in liveSessions) {
  final player = entry['Player'];
  final playerTitle = player is Map<String, Object?> ? player['title'] : null;
  print('${entry['title']} on ${entry['channelCallSign']} ($playerTitle)');
}
```

`liveSession(sessionId:)` reads one session. `sessionPlaylistUrl()` and
`sessionSegmentUrl()` build the HLS URLs of a consumer of the session.
Past Live TV plays are in the playback history
([9.2](#92-playback-history)).

#### 14.2 DVRs

```dart
final dvrs = await plex.liveTv.dvrs();
final channels =
    await plex.liveTv.dvrChannels(dvrKey: dvrs.first['key']! as String);

await plex.dvrs.reloadGuide(dvrId: dvrId);
await plex.dvrs.tuneChannel(dvrId: dvrId, channel: '2.1');
```

`dvrChannels()` takes the `key` of an entry from `liveTv.dvrs()`.
`plex.dvrs` takes the DVR's id and configures one DVR: `get()`, `delete()` (recordings stay on
disk), `setPreferences()`, `addLineup()` and `deleteLineup()`,
`reloadGuide()` and `stopReloadGuide()`, `tuneChannel()`, `addDevice()`
and `removeDevice()`.

#### 14.3 Recording subscriptions

```dart
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

await plex.subscriptions.delete(subscriptionId: '${subs.first['id']}');
```

A subscription is a recording rule. `create()` adds one for a library
section, starting from the `template(guid:)` of a program. `get()`,
`editPreferences()`, `reorder()` (the order settles conflicts) and
`delete()` manage one; recordings already on disk stay.
`scheduledRecordings()` lists what the DVR will record, `processAll()`
applies the rules to a new guide, and `cancelGrab(operationId:)` stops a
recording in progress.

#### 14.4 Tuners and the program guide

`plex.devices` manages the tuners (grabbers): `grabbers()`, `list()`,
`discover()`, `add(uri:)`, `details()`, `remove()`, `setEnabled()`,
`channels()`, `setChannelMap()`, `setPreferences()`, `startScan()`,
`stopScan()` and `thumbUrl()`.

`plex.epg` reads the program guide's lineups: `countries()`,
`languages()`, `countryLineups()`, `countryRegions()`,
`regionLineups()`, `bestLineup()`, `channelMap()`, `channels()` and
`lineupChannels()`.

```dart
await plex.devices.discover();
final tuners = await plex.devices.list();
final countries = await plex.epg.countries();
```

---

### 15. Error handling

#### 15.1 PlexException

Every call throws a `PlexException` on failure:

```dart
try {
  await plex.library.sections();
} on PlexException catch (e) {
  print('${e.type} ${e.statusCode} ${e.message}');
}
```

`PlexErrorType` is one of `connection`, `timeout`, `auth`, `notFound`,
`badRequest`, `serverError`, `parse`, `state`, `cancelled` and
`unknown`. The exception also carries the request `path`, the underlying
`cause`, the original `stackTrace` and, when the server sent
`Retry-After` (on a `429` or `503`), `retryAfter`.

#### 15.2 Classifying a failure

```dart
try {
  await plex.library.sections();
} on PlexException catch (e) {
  if (e.isCancelled) {
    // the caller gave up: not a failure, ignore it
  } else if (e.isAuthError) {
    await signInAgain(); // 401 or 403: the server rejects the token
  } else if (e.isTransient) {
    scheduleRetry(e.retryAfter); // network, 5xx or 429
  } else if (e.isNotFound) {
    showGone(); // 404: confirmed absence
  } else {
    showError(e.message);
  }
}
```

| Getter | True for |
| :--- | :--- |
| `isNetworkFailure` | No answer at all: the connection failed or timed out |
| `isTransient` | A failure that may pass if sent again: a network failure, a 5xx or a `429` |
| `isNotFound` | The server answered `404` |
| `isCancelled` | The request was cancelled through a `PlexCancelToken` |
| `isAuthError` | `401` or `403`, or a sign-in answered without a token |

The client never fetches a new token on its own: on `isAuthError`, run
the PIN flow ([2.1](#21-pin-flow)) again.

---

### 16. Cancellation and retries

#### 16.1 Cancelling requests

```dart
PlexCancelToken? searchToken;

Future<List<PlexHub>> searchAsYouType(PlexClient plex, String text) async {
  searchToken?.cancel(); // drop the previous keystroke's request
  final token = searchToken = PlexCancelToken();
  try {
    return await plex.withCancelToken(token).search.hubs(query: text);
  } on PlexException catch (e) {
    if (e.isCancelled) return const [];
    rethrow;
  }
}
```

`withCancelToken(token)` returns a view of the client whose every call is
cancelled by `token.cancel()`. The view shares the client's connections,
server and token (`connect`, `setToken` and `close` on either affect
both) and costs nothing to create, so make one per page, filter or
search term. A token cancels once: make a new one for the next request.
`request()`, `requestBytes()`, `requestStream()` and `downloadToFile()`
also take a `cancelToken` directly.

A cancelled call throws a `PlexException` of type `cancelled`.
`notifications` is the same object on the view as on the client: a
WebSocket is not a request and is not cancelled.

#### 16.2 Retry policy

```dart
final plex = PlexClient(
  credentials: credentials,
  retryPolicy: const PlexRetryPolicy(
    maxAttempts: 4, // the first attempt included
    maxDelay: Duration(seconds: 10),
  ),
);
```

Retries are off by default. With a policy, only `GET` and `HEAD`
requests are sent again, and only after a failure another attempt can
fix: no answer (connection lost, timeout), `502`, `503`, `504` or `429`.
A `500` is not retried. The wait grows exponentially from `initialDelay`
(300 ms) with random jitter, never above `maxDelay` (5 s); a
`Retry-After` header is honoured up to `maxDelay`, and a cancel token
cancels the wait too. `const PlexRetryPolicy()` sends a request up to
three times. Opening a stream is retried as well; a body already flowing
is not replayed.

---

### 17. Paging

#### 17.1 Page parameters

Plex pages with `X-Plex-Container-Start` and `X-Plex-Container-Size`, and
pages only when it gets both, so every paged call sends both.

`allByType()`, `albums()`, `playlists.list()`, `sessions.history()` and
`hubs.drill()` always read one page: 50 rows from `start` unless you pass
`size`. `children()`, `grandchildren()`, `allLeaves()`, `recentlyAdded()`
and `playlists.items()` return every row when you pass neither, and one
page when you pass `size` (`start` is 0 by default). Pass `start`
together with `size`: a `start` alone throws an `ArgumentError`, since
the server would ignore it.

#### 17.2 Walking every page

```dart
final tracks = PlexPaging.items(
  (start, size) => plex.library.grandchildren(
    ratingKey: artist.ratingKey,
    start: start,
    size: size,
  ),
  pageSize: 200,
);
await for (final track in tracks) {
  print(track.title);
}

// allByType returns a container: hand PlexPaging its items.
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
one by one. Paging stops at the first page shorter than `pageSize` (100
by default) or once `limit` rows have arrived, asking the last page for
exactly what is left. Each page is one request, made as the stream is
listened to; cancelling the subscription stops the requests. Pair it
with a cancel token ([16.1](#161-cancelling-requests)) to drop the
request in flight too.

---

### 18. Notifications and events

<img src="https://raw.githubusercontent.com/ales-drnz/dart_plex/main/imgs/diagrams/events.png" width="100%" alt="Notification frames from the WebSocket or the event source become a PlexNotification, and events() decodes them into the sealed PlexEvent subtypes">

#### 18.1 Connecting

```dart
final frames = await plex.notifications.connectWebSocket();
final subscription = frames.listen((frame) => print(frame.type));

// Later:
await subscription.cancel();
await plex.notifications.closeWebSocket();
```

`connectWebSocket()` returns once the socket is open, and throws a
`PlexException` of type `connection` when it cannot open.
`connectEventSource()` returns the same stream over Server-Sent Events,
for networks whose proxies block WebSockets; close it with
`closeEventSource()`. Both take an optional `filter` naming one frame
type (`'playing'`, `'activity'`). Each frame is a `PlexNotification` with
its `type` and `raw` body; `isWebSocketConnected` and
`isEventSourceConnected` tell which transport is open.

#### 18.2 Typed events

```dart
final frames = await plex.notifications.connectWebSocket();
final subscription = frames.events().listen((event) {
  switch (event) {
    case PlexPlaySessionEvent(:final ratingKey, :final state):
      print('$ratingKey is ${state.name}');
    case PlexLibraryItemEvent(:final itemId, isDeleted: true):
      print('$itemId was deleted');
    case PlexLibraryItemEvent(:final itemId, isReady: true):
      print('$itemId changed, read it again');
    case PlexActivityEvent(isLibraryScan: true, isEnded: true):
      print('scan finished, reload the library');
    case _:
  }
});
```

`events()` on a notification stream, or `PlexNotification.events` on one
frame (a frame can carry several entries), decodes frames into the
sealed `PlexEvent` type:

| Event | Frame type | Carries |
| :--- | :--- | :--- |
| `PlexPlaySessionEvent` | `playing` | A player's `PlexPlayState`, playhead, rating key, play queue ids |
| `PlexLibraryItemEvent` | `timeline` | An item created, changed, analysed or deleted (`isCreated`, `isReady`, `isDeleted`, `updatedAt`) |
| `PlexActivityEvent` | `activity` | A background activity started, progressed or ended; `isLibraryScan` |
| `PlexStatusEvent` | `status` | A server status message |
| `PlexUnknownEvent` | anything else | The whole frame in `raw` |

One library change arrives as several `PlexLibraryItemEvent`s as the item
moves through its states. New artwork arrives as a ready event with a new
`updatedAt`.

---

### 19. Downloads

#### 19.1 Downloading to a file

```dart
import 'package:dart_plex/dart_plex.dart';
import 'package:dart_plex/io.dart';

Future<void> download(PlexClient plex, PlexMetadata track) async {
  final (url, ext) = plex.streaming.directFileUrl(
    partKey: track.media.first.parts.first.key!,
  );
  final bytes = await plex.downloadToFile(
    url,
    '/music/${track.ratingKey}.$ext',
    onProgress: (received, total) => print('$received / ${total ?? '?'}'),
  );
  print('$bytes bytes written');
}
```

`downloadToFile()` is an extension on `PlexClient` in
`package:dart_plex/io.dart`. It writes the body to a temporary file as it
arrives, so a whole track never sits in memory, and renames it to the
target path once complete. A failure, a stall past the receive timeout or
a cancellation removes the temporary file, leaves the target as it was
and throws a `PlexException`. `onProgress` gets the bytes received and
the total when the server sent a `Content-Length`. The call returns the
number of bytes written. Mind the MP3 note in
[8.2](#82-direct-file-url).

#### 19.2 Download queues

`plex.downloadQueue` drives the server-side download queues that Plex's
mobile apps use for offline sync: `create()`, `get()`,
`add(queueId:, keys:)`, `items()`, `item()`, `remove()`, `restart()`,
`itemDecision()` and `itemMedia()`. They return the server's maps. For a
download of your own, `downloadToFile()` above is enough.

---

### 20. Escape hatch

For an endpoint the typed sub-APIs do not cover, send the request
yourself. It goes through the same HTTP client, headers, retry policy and
`PlexException` handling.

#### 20.1 Raw request

```dart
final response = await plex.request<Map<String, Object?>>(
  '/library/sections/${musicLib.id}/all',
  queryParameters: {
    'type': 9,
    'X-Plex-Container-Start': 0,
    'X-Plex-Container-Size': 50,
  },
);
print('${response.statusCode} ${response.contentType}');
final container = response.data?['MediaContainer'];
```

A `PlexResponse<T>` carries `data`, `statusCode`, `headers` (lower-case
names), `contentType` and the requested `uri`. `method` takes `'POST'`,
`'PUT'` or `'DELETE'`, and `get()`, `post()`, `put()` and `delete()` are
shorthands. `extraHeaders`, `data`, `absoluteUrl` and `cancelToken` are
optional. `responseType` picks the decoding: `PlexResponseType.json`
(JSON when the server says so, text otherwise), `bytes` or `plain`.

#### 20.2 Raw bytes and streams

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

`requestBytes()` and `requestStream()` take a full URL by default; pass
`absoluteUrl: false` for a path on the connected server. The token
travels in the headers either way. Listen to a `PlexStreamedResponse`'s
`stream` once; cancelling the subscription closes the connection. A
pause longer than the receive timeout fails the stream unless
`stallTimeout` is `false`.

---

## Project background

I wrote the typed models, the sub-APIs and the transport with Claude Code.

Plex is a trademark of Plex, Inc. dart_plex is not affiliated with it.

---

*Developed by Alessandro Di Ronza*
