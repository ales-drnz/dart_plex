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
<td valign="middle"><code>dart_plex</code> is a Dart client for Plex Media Server <code>v1.43.x</code>. It covers libraries, hubs, playlists, audio streaming, playback reporting, search and play queues through typed Dart objects, and handles plex.tv sign-in and server discovery.</td>
</tr>
</table>

---

## Installation

Add `dart_plex` to your `pubspec.yaml`:

```yaml
dependencies:
  dart_plex: ^0.1.0
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
    * [1.3 Disposing](#13-disposing)

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

    </details>

    <details>
    <summary><a href="#6-playlists"><b>6. Playlists</b></a></summary>

    * [6.1 Listing and counting](#61-listing-and-counting)
    * [6.2 Creating a playlist](#62-creating-a-playlist)
    * [6.3 Adding and removing items](#63-adding-and-removing-items)
    * [6.4 Renaming and deleting](#64-renaming-and-deleting)

    </details>

    <details>
    <summary><a href="#7-search"><b>7. Search</b></a></summary>

    * [7.1 Hub search](#71-hub-search)
    * [7.2 Legacy flat search](#72-legacy-flat-search)

    </details>

    <details>
    <summary><a href="#8-playback-reporting"><b>8. Playback reporting</b></a></summary>

    * [8.1 Timeline heartbeat](#81-timeline-heartbeat)
    * [8.2 Scrobble and unscrobble](#82-scrobble-and-unscrobble)
    * [8.3 Rate and favourites](#83-rate-and-favourites)

    </details>

    <details>
    <summary><a href="#9-audio-streaming"><b>9. Audio streaming</b></a></summary>

    * [9.1 Universal transcode URL](#91-universal-transcode-url)
    * [9.2 Direct file URL](#92-direct-file-url)
    * [9.3 Transcode session lifecycle](#93-transcode-session-lifecycle)
    * [9.4 Lyrics](#94-lyrics)

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
    * [18.2 Retriable vs terminal](#182-retriable-vs-terminal)
    * [18.3 Auth invalidation](#183-auth-invalidation)

    </details>

    <details>
    <summary><a href="#19-escape-hatch"><b>19. Escape hatch</b></a></summary>

    * [19.1 Raw request](#191-raw-request)
    * [19.2 Raw bytes](#192-raw-bytes)

    </details>
*   [Project background](#project-background)

---

## Features

<table>
<tr>
<td valign="middle" width="48"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/package.png" width="32"></td>
<td valign="middle" width="45%"><b>Pure Dart</b><br>no native plugin, no Flutter dependency. Runs on every Dart-supported platform.</td>
<td valign="middle" width="48"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/shield-check.png" width="32"></td>
<td valign="middle" width="45%"><b>Typed DTOs</b><br>every response is a typed Dart object (libraries, items, media, streams, hubs, users), each with a <code>.raw</code> map so new server fields are never lost.</td>
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
<td valign="middle"><b>Audio streaming</b><br><code>streaming.universalAudioUrl()</code> builds <code>.m3u8</code> (HLS) or <code>.mpd</code> (DASH) manifest URLs; <code>directFileUrl()</code> gives the zero-transcode original.</td>
</tr>
<tr>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/triangle-alert.png" width="32"></td>
<td valign="middle"><b>Semantic errors</b><br>every failure is a <code>PlexException</code> you can branch on (auth, not found, timeout, connection), never a raw network error in your code.</td>
<td valign="middle"><img src="https://raw.githubusercontent.com/ales-drnz/svg-icons/main/png/terminal.png" width="32"></td>
<td valign="middle"><b>Escape hatch</b><br><code>client.request&lt;T&gt;()</code> and <code>client.requestBytes()</code> for endpoints not yet covered by the typed sub-APIs.</td>
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
      deviceName: "My iPhone",
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
    size: 50,
  );

  // 4. Play a track.
  final track = albums.items.first;
  final url = plex.streaming.universalAudioUrl(
    ratingKey: track.ratingKey,
    protocol: 'hls',
    audioCodec: 'aac',
    maxAudioBitrate: 320,
  );
  // hand `url` to your audio engine
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
    deviceName: "My iPhone",
    platform: 'iOS',
  ),
);
```

The constructor optionally accepts a custom `dio: Dio()` instance plus
`connectTimeout` and `receiveTimeout`. By default it owns its own Dio.

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

#### 1.3 Disposing

```dart
plex.disconnect(); // clears baseUrl + token
```

`PlexClient` doesn't own any native resources, so a `disconnect()` is
sufficient. There's no `dispose()` to call. If you injected a custom
Dio, dispose it yourself if it owns native HTTP connections.

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
final pin = await plex.account.createPin(strong: true);
print('Open https://plex.tv/link and enter ${pin.code}');

// 2. Poll until the user authorises the device.
while (true) {
  await Future<void>.delayed(const Duration(seconds: 2));
  final fresh = await plex.account.pollPin(pin.id);
  if (fresh.isAuthenticated) {
    plex.setToken(fresh.authToken!);
    break;
  }
  if (fresh.isExpired) throw StateError('PIN expired');
}
```

`strong: true` opts into JWT-grade tokens (recommended). The pin expires
after ~15 minutes.

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
  includeHttps: true,
  includeRelay: true,
  includeIPv6: true,
  serverOnly: true,
);
```

`serverOnly: true` (default) filters resources to those whose
`provides` includes `"server"`, dropping player and client resources.

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
// {machineIdentifier: …, version: …, apiVersion: …}
```

`/identity` doesn't require a token. Useful for reachability checks
before re-authenticating.

#### 4.2 Full info

```dart
final info = await plex.server.info();
// machineIdentifier, version, platform, transcoderAudio, myPlex, …
```

Same as `identity()` but with the full root MediaContainer.

#### 4.3 Ping

```dart
if (await plex.server.ping()) { /* server reachable */ }
```

Swallows all transport errors. Use `identity()` directly when you need
to inspect failures.

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
  start: 0,
  size: 50,
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

`filter` accepts the raw Plex filter expression
(`'genre=Rock'`, `'year>=2010'`, `'userRating>>=8'`).

#### 5.3 Counting items

```dart
final count = await plex.library.countByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
);
```

Issues a request with `X-Plex-Container-Size=0` so the server answers
with `totalSize` without streaming items.

#### 5.4 Single item metadata

```dart
final metadata = await plex.library.item('12345');
if (metadata != null) {
  print(metadata.title);
  print(metadata.media.first.audioCodec); // e.g. 'flac'
}
```

Returns `null` on 404. The DTO carries `media`, `genres`, `moods`,
`styles`, plus `raw` for fields not promoted to typed properties.

#### 5.5 Children and leaves

```dart
final tracks = await plex.library.children('albumId');
final allTracksInArtist = await plex.library.allLeaves('artistId');
```

`children()` returns direct descendants (album to tracks, artist to
albums, season to episodes). `allLeaves()` returns every leaf-level
item recursively, useful for "play artist" or "play show".

#### 5.6 Genres

```dart
final genres = await plex.library.genres(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
);
```

Each entry is a `PlexMetadata` whose `key` is the genre id; pass it
back as `filter: 'genre=<id>'` to filter `allByType`.

#### 5.7 Filters, albums, folders, categories

`filters()` returns the list of facets the server can sort or filter
on. Each `Directory` carries a `Pivot` array (in its `raw` map) with
pre-built sub-views like the A-Z index and folder view.

```dart
final facets = await plex.library.filters(sectionId: musicLib.id);
for (final f in facets) {
  print('${f.title} key=${f.key} type=${f.type}');
}
```

`albums()`, `folderLocations()`, and `categories()` are cheap
sub-bucket endpoints when the consumer does not need the full
sort and filter machinery of `allByType`:

```dart
final paged = await plex.library.albums(
  sectionId: musicLib.id,
  start: 0,
  size: 100,
);
final folders = await plex.library.folderLocations(sectionId: musicLib.id);
final cats = await plex.library.categories(sectionId: photoLib.id);
```

---

### 6. Playlists

#### 6.1 Listing and counting

```dart
final audio = await plex.playlists.list(type: 'audio', start: 0, size: 50);
final count = await plex.playlists.count(type: 'audio');
```

`type` is `'audio' | 'video' | 'photo'`. Pass `smart: true` to filter
to smart playlists. Each entry is a `PlexMetadata` of
`PlexMetadataType.playlist`.

#### 6.2 Creating a playlist

```dart
final identity = await plex.server.identity();
final machineId = identity['machineIdentifier'] as String;

final playlist = await plex.playlists.create(
  title: 'My Mix',
  type: 'audio',
  machineIdentifier: machineId,
  itemRatingKeys: const ['12345', '12346', '12347'],
);
```

Plex requires the server's `machineIdentifier` to build the playlist
URI. Pass an empty `itemRatingKeys` to create an empty playlist.

#### 6.3 Adding and removing items

```dart
await plex.playlists.addItems(
  playlistId: playlist.ratingKey,
  machineIdentifier: machineId,
  itemRatingKeys: const ['99999'],
);

// To remove, find the playlistItemID from .raw on each entry returned
// by .items().
final items = await plex.playlists.items(playlist.ratingKey);
final entryId = items.first.raw['playlistItemID'].toString();
await plex.playlists.removeItem(
  playlistId: playlist.ratingKey,
  playlistItemId: entryId,
);
```

> ⚠️ `removeItem` expects the **playlistItemID**, not the underlying
> rating key. Reading it from `items.raw[…]` is currently the only way;
> a typed field will be added when promoted out of `.raw`.

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
  limit: 10,
);

for (final hub in hubs) {
  print('${hub.title} (${hub.type})');
  for (final hit in hub.items) {
    print('  - ${hit.title}');
  }
}
```

Modern type-as-you-go search; returns one `PlexHub` per result
category (artists, albums, tracks, …).

#### 7.2 Legacy flat search

```dart
final results = await plex.search.flat(query: 'pink floyd', limit: 30);
```

Older endpoint; returns a flat `List<PlexMetadata>` mixing all
categories. Prefer `hubs()` when available.

---

### 8. Playback reporting

#### 8.1 Timeline heartbeat

```dart
await plex.playback.timeline(
  ratingKey: track.ratingKey,
  state: PlexPlaybackApi.statePlaying, // 'playing' | 'paused' | 'stopped' | 'buffering'
  timeMs: 42_000,
  durationMs: 240_000,
  playQueueItemId: 'optional-pq-id',
  continuing: false,
);
```

Plex recommends sending a timeline every 10 s on LAN, 20 s on
cellular, plus one on every state change.

`continuing: true` tells the server "I'm about to start a different
track in the same playback flow", so Plex won't reap the current
transcode session, which matters during gapless prefetch.

#### 8.2 Scrobble and unscrobble

```dart
await plex.playback.scrobble(ratingKey);   // mark as watched or listened
await plex.playback.unscrobble(ratingKey); // mark as unwatched
```

#### 8.3 Rate and favourites

```dart
await plex.playback.rate(ratingKey: ratingKey, rating: 7.5); // 0..10
await plex.playback.setFavorite(ratingKey: ratingKey, isFavorite: true);
```

Plex does not have a separate "is favourite" flag; favourites are
encoded as `userRating == 10`. `setFavorite` is sugar around `rate`.

---

### 9. Audio streaming

These methods primarily **build URLs**. They don't fetch the audio
stream themselves; hand the URL to your audio engine (mpv, AVPlayer,
ExoPlayer, …). The `X-Plex-Token` is appended as a query parameter so
segment requests work without custom headers.

#### 9.1 Universal transcode URL

```dart
final url = plex.streaming.universalAudioUrl(
  ratingKey: track.ratingKey,
  protocol: 'hls',          // 'hls' | 'dash' | 'http'
  container: 'mpegts',      // for HLS use 'mpegts'; for direct mp3 use 'mp3'
  audioCodec: 'aac',
  maxAudioBitrate: 320,     // kbps; pass null to let the server pick
  audioChannels: 2,
  session: 'my-uuid',       // stable per playback session
  directPlay: false,
  directStream: true,
);
```

The returned URL extension is derived from `protocol`: `.m3u8` for
HLS, `.mpd` for DASH, the supplied `container` for HTTP.

#### 9.2 Direct file URL

```dart
final (url, ext) = plex.streaming.directFileUrl(
  partKey: track.media.first.parts.first.key!,
  download: true,
);
```

Best-quality, zero-server-CPU URL. Use for downloads and for clients
that can decode whatever the file contains.

#### 9.3 Transcode session lifecycle

```dart
await plex.streaming.pingUniversal(sessionId);  // keep alive
await plex.streaming.stopUniversal(sessionId);  // teardown
```

Plex reaps inactive sessions after ~2 minutes. Ping every 30 s
while a player is paused but the session must stay warm.

#### 9.4 Lyrics

```dart
// streamKey is the .key of a track's Stream entry with streamType == 4.
final lyrics = await plex.streaming.lyrics(streamKey: streamKey);
```

Returns the raw lyrics body (LRC or plain text) or `null` if not
available. Parsing into typed `LyricLine` is left to the consumer.

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
  protocol: 'hls',
  container: 'mpegts',
  videoResolution: '1920x1080',
  videoBitrate: 8000,
  audioBitrate: 256,
  videoCodec: 'h264',
  audioCodec: 'aac',
  subtitleSize: 100,
  session: 'my-uuid',
);
```

The URL extension is derived from `protocol`: `.m3u8` for HLS, `.mpd`
for DASH, the container otherwise. Bandwidth is in kbps.

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

Each [`PlexSession`] carries the full [`PlexMetadata`] of the item
being played plus `user`, `player`, `transcodeSession` and a
`sessionId` you can pass to [11.3](#113-terminating-a-session).

#### 11.2 Playback history

```dart
final history = await plex.sessions.history(
  accountId: 1,
  mindate: DateTime.now()
      .subtract(const Duration(days: 30))
      .millisecondsSinceEpoch ~/ 1000,
  size: 100,
  sort: 'viewedAt:desc',
);
```

Returns raw maps (`viewedAt`, `ratingKey`, `accountID`, `deviceID`)
so callers stay flexible. Promote a typed DTO when usage justifies it.

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
  sourcePath: metadata.thumb!,  // e.g. '/library/metadata/123/thumb/1700000000'
  width: 500,
  height: 500,
  minSize: 1,
  upscale: false,
);
```

Goes through `/photo/:/transcode` so the server delivers a
pre-resized JPEG (~50-150KB at 500×500).

#### 12.2 Fetching bytes

```dart
final Uint8List? bytes = await plex.images.fetch(
  sourcePath: metadata.thumb!,
  width: 500,
  height: 500,
);
```

Returns `null` on 404. Throws `PlexException` on transient failures
(5xx, network down) so the caller can distinguish "no artwork ever" from
"try again later".

---

### 13. Hubs

Hubs power Plex's "Home" screen: `Recently Added Music`, `Continue
Listening`, `More from <artist>`, `On Deck`. Each hub is a typed row
of items; render them as horizontal carousels.

#### 13.1 Global and per-section hubs

```dart
// Global hubs (all libraries).
final globalHubs = await plex.hubs.global(count: 16);

// Hubs scoped to one library section.
final musicHubs = await plex.hubs.forSection(
  sectionId: musicLib.id,
  count: 16,
);

for (final hub in musicHubs) {
  print('${hub.title}: ${hub.items.length} items');
}
```

Each [`PlexHub`] carries a small preview of items in `hub.items`
plus a `more` flag indicating whether the rail has more entries
behind a `Show all` action.

#### 13.2 Promoted and on-deck

```dart
final promoted = await plex.hubs.promoted();
final onDeck   = await plex.hubs.continueWatching();
final perLibrary = await plex.hubs.sectionOnDeck(
  sectionId: musicLib.id,
);
```

`continueWatching()` and `sectionOnDeck()` return
[`List<PlexMetadata>`] directly (not wrapped in a hub) since the
data is already a flat list of "Up Next" entries.

#### 13.3 Drilling into a hub

When `hub.more == true` and the user taps "Show all", fetch the
rest:

```dart
final all = await plex.hubs.drill(
  hubKeyOrIdentifier: hub.hubKey, // or hub.hubIdentifier
  start: 0,
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
final identity = await plex.server.identity();
final machineId = identity['machineIdentifier'] as String;

final uri = PlexPlayQueuesApi.seedFromItems(
  machineIdentifier: machineId,
  ratingKeys: const ['12345', '12346', '12347'],
);
final queue = await plex.playQueues.create(
  type: 'audio',
  uri: uri,
  shuffle: false,
  continuous: true,
);
final queueId = int.parse(queue.raw['playQueueID'].toString());
```

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
  print('${entry['title']} on ${entry['channelCallSign']}'
        ' (${entry['Player']?['title']})');
}
```

> Past live-TV viewing history is not exposed by `plex.liveTv`; use
> [`plex.sessions.history()`](#112-playback-history). Live TV plays are
> reported into the same playback-history store as on-demand items.

#### 15.2 DVR backends

```dart
final dvrs = await plex.liveTv.dvrs();
for (final dvr in dvrs) {
  print('${dvr['title']} (${dvr['lineup']?['name']})');
}

// Drill into the channels grouped under one DVR:
final channels = await plex.liveTv.dvrChannels(dvrs.first['key'] as String);
```

#### 15.3 Subscriptions

DVR recording subscriptions live on their own sub-API,
`plex.subscriptions` (`PlexSubscriptionsApi`), not on `plex.liveTv`:

```dart
// List every recording rule. Returns the raw `MediaContainer` map.
final container = await plex.subscriptions.list();
final subs = (container['MediaContainer']?['MediaSubscription'] as List?)
    ?.cast<Map<String, dynamic>>() ?? const [];
for (final sub in subs) {
  print('${sub['title']} - ${sub['type']}');
}

// Delete a subscription by its id.
await plex.subscriptions.delete(subs.first['id'].toString());
```

> Live TV (sessions, DVRs) results come back as raw maps. They could get
> typed wrappers later, but the underlying shapes are deeply nested and
> change often between Plex releases, so the raw map is the safer bet for now.

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
);
```

Use `excludeParentID` and `excludeGrandparentID` to keep the album
or artist of the seed out of the result (useful when the seed track
dominates the radio).

#### 16.3 Nearest tracks in a section

```dart
// The sonic vector lives in the raw envelope under `musicAnalysis`
// (a track has one once the server has analysed it).
final seed = (track.raw['musicAnalysis'] as List).cast<num>();
final radio = await plex.library.nearestInSection(
  sectionId: musicSection.key,
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
print('${palette.topLeft} ${palette.topRight} ${palette.bottomLeft} ${palette.bottomRight}');
```

The container shape returns an array; pick the first element for the
common case. `sourceUrl` accepts a relative PMS path (most common) or
an absolute URL.

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
`badRequest`, `serverError`, `parse`, `state`, `unknown`.

#### 18.2 Retriable vs terminal

```dart
} on PlexException catch (e) {
  if (e.isRetriable) {       // connection or timeout
    scheduleRetry();
  } else if (e.isAuthError) { // 401 or 403, token rejected
    await reAuthenticate();
  } else {
    surfaceError(e.message);
  }
}
```

#### 18.3 Auth invalidation

`PlexException.isAuthError` is the signal to re-run the PIN flow or
the legacy sign-in. The library will not automatically re-fetch a
token; that's an app-level policy decision.

---

### 19. Escape hatch

When the typed sub-APIs don't yet cover an endpoint, drop down to:

#### 19.1 Raw request

```dart
final response = await plex.request<Map<String, dynamic>>(
  '/library/sections/$id/all',
  queryParameters: {'type': 9, 'X-Plex-Container-Size': 50},
);
final container = response.data?['MediaContainer'];
```

Same Dio, same headers, same `PlexException` translation as the
typed sub-APIs. Pass `method: 'POST'`, `'PUT'` or `'DELETE'`,
`extraHeaders`, `data`, `absoluteUrl: true` as needed.

#### 19.2 Raw bytes

```dart
final response = await plex.requestBytes(
  '${plex.baseUrl}/library/parts/123/file.flac?X-Plex-Token=${plex.token}',
);
final bytes = response.data;
```

---

## Project background

All the typed DTOs, sub-APIs, and architectural patterns were implemented through the use of Claude Code.

---

*Developed by Alessandro Di Ronza*
