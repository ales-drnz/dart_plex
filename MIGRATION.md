# Migrating to 0.3.0

0.3.0 needs Dart 3.10, types the answers that were still maps, types the
sort and type parameters, and removes what 0.2 deprecated. Sign-in with a
plex.tv JWT is new and optional: a legacy token keeps working.

## Dart 3.10

The package needs Dart `3.10` or later. Flutter 3.38 ships Dart 3.10.

## Fakes of the client

`PlexClient` and the sub-APIs gained members. A fake that implements one
must add them, or extend a mocking library's mock instead.

## Removed

| 0.2.x | 0.3.0 |
| --- | --- |
| `PlexDVRsApi` | `PlexDvrsApi` |
| `e.isRetriable`, `type.isRetriable` | `e.isNetworkFailure`, or `e.isTransient` to include 5xx and 429 |
| `timeline(state: 'playing', …)`, `PlexPlaybackApi.statePlaying` | `timeline(playState: PlexPlayState.playing, …)` |
| `timeline(playQueueItemId: '7', …)` | `timeline(playQueueItemID: 7, …)` |
| `streaming.universalAudioUrl(…)` | `await streaming.startAudioTranscode(…)` |
| `nearestToTrack(excludeParentID: 2)` | `nearestToTrack(excludeParentRatingKey: '2')` |

## Sort and type parameters

Strings that the server reads as a fixed vocabulary are typed. A value
the package does not list is still one constructor away, since
`PlexSort`, `PlexMediaType` and `PlexMarkerType` are extension types over
the wire string.

| 0.2.x | 0.3.0 |
| --- | --- |
| `sort: 'titleSort:asc'` | `sort: PlexSort.titleSort.asc` |
| `sort: 'addedAt:desc'` | `sort: PlexSort.addedAt.desc` |
| `sort: 'viewedAt:desc'` | `sort: const PlexSort('viewedAt').desc` |
| `playlists.list(type: 'audio')`, `create(type: 'audio')`, `playQueues.create(type: 'audio')` | `type: PlexMediaType.audio` |
| `addSection(type: 'artist')` | `addSection(type: PlexLibraryType.music)` |
| `firstCharacters(type: '9')`, `collections.create(type: '9')` | `type: PlexMetadataType.album` |
| `createMarker(type: 'intro')` | `createMarker(type: PlexMarkerType.intro)` |
| `startAudioTranscode(protocol: 'dash')`, `universalVideoUrl(protocol: 'hls')` | `protocol: PlexStreamingProtocol.dash` |
| `library.tags()`, `sectionCommon(sectionId: s)` | `tags(type: …)`, `sectionCommon(sectionId: s, type: …)`: the server answers 400 without a type |

## Typed answers

| 0.2.x | 0.3.0 |
| --- | --- |
| `downloadQueue.create()`, `get()` → map | `PlexDownloadQueue` |
| `downloadQueue.items()`, `item()` → map | `PlexDownloadQueueItem` (`status`, `error`, `decision`) |
| `downloadQueue.itemDecision()` → map | `PlexTranscodeDecision` |
| `downloadQueue.itemMedia()` | `itemMediaUrl()`: the route answers the file |
| `liveTv.sessions()`, `liveSession()` → maps | `PlexMetadata` |
| `liveTv.dvrs()`, `dvrs.get()` → maps | `PlexDvr` (`key`, `devices`) |
| `devices.grabbers()`, `list()`, `discover()`, `add()`, `details()`, `channels()` → maps | `PlexMediaGrabber`, `PlexTunerDevice`, `PlexDeviceChannel` |
| `subscriptions.list()`, `get()`, `create()`, `template()` → maps | `PlexMediaSubscription` |
| `subscriptions.scheduledRecordings()` → map | `PlexMediaGrabOperation` |
| `epg.*` → maps | `PlexEpgCountry`, `PlexEpgLanguage`, `PlexLineup`, `PlexEpgChannel`, `PlexChannelMapping` |
| `library.tags()`, `matches()`, `person()` → maps | `PlexTag`, `PlexMetadata`, `PlexPerson` |
| `library.sectionDetails()` → map | `PlexSectionDetails` (`views`) |
| `playlists.generators()` → maps, `generators.first['id']` | `PlexPlayQueueGenerator`, `generators.first.id` |
| `updater.status()` → map | `PlexUpdaterStatus` |
| `server.securityResources()`, `backgroundTasks()` → maps | `PlexSecurityResource`, `PlexTranscodeJob` |
| `providers.list()`, `add()` → map | `PlexMediaProvider` |
| `streaming.lyrics()` → `String?` | `PlexLyrics?`: `.text` for the old string, `.lines` for the LRC lines |

Each model keeps its entry in `raw`.

A lookup returns `null` when the answer holds nothing, and a create
throws a `parse` error (`subscriptions.create()` returns `null` too):

| 0.2.x | 0.3.0 |
| --- | --- |
| `subscriptions.get()`, `create()` → map | `PlexMediaSubscription?` |
| `devices.details()` → map | `PlexTunerDevice?` |
| `dvrs.get()` → map | `PlexDvr?` |
| `downloadQueue.get()`, `item()` → map | `PlexDownloadQueue?`, `PlexDownloadQueueItem?` |
| `liveTv.liveSession()` → map | `PlexMetadata?` |
| `library.person()` → map | `PlexPerson?` |

The maps the package still returns
(`autocomplete()`, `sectionCommon()`, `sectionPreferences()`,
`streamLoudness()` and a few other admin reads) are unchanged.

## Ids and bitrates

| 0.2.x | 0.3.0 |
| --- | --- |
| `downloadQueue.items(queueId: '1')`, `remove(queueId: '1', itemId: '2')` | `queueId: 1`, `itemId: 2`: the ids are `int`, as `PlexDownloadQueue.id` is |
| `playlists.generatorItems(generatorId: '4')`, `reprocessGenerator(generatorId: '4', …)` | `generatorId: generator.id` (an `int`) |
| `startAudioTranscode(maxBitrateKbps: 128)`, `musicProfileExtra(maxBitrateKbps: 128, …)` | `maxAudioBitrateKbps: 128` |
| `universalVideoUrl(videoBitrate: 8000, audioBitrate: 256)` | `maxVideoBitrateKbps: 8000, maxAudioBitrateKbps: 256` |

## plex.tv calls and tokens

`account.tokenDetails()` and `connectedUsers()` ask plex.tv now; the
server routes they called answered nothing useful.

| 0.2.x | 0.3.0 |
| --- | --- |
| `account.tokenDetails()` → map of the server | `PlexUser` the server token belongs to |
| `account.connectedUsers()` → maps of the server | `PlexAccountUser`, with the servers shared |

`connect(url, accessToken: t)` used to replace the only token, so plex.tv
calls afterwards carried the server's token. The token it replaces is now
kept as `accountToken` and plex.tv calls send it. Code that relied on the
old behaviour sets it apart with `setAccountToken()`. `clearSession()`
also drops the account token and any JWT session.

## New error type

`PlexErrorType.passRequired` is new: a refusal of remote video playback
for want of a Plex Pass or Remote Watch Pass. It is not an auth error. A
`switch` over `PlexErrorType` must handle it. `498` (plex.tv's "token
expired") is an `auth` error.

`PlexException.path` and `message` show `REDACTED` for the value of an
`X-Plex-Token`, `deviceJWT` or `pin` query parameter. Code that read the
token back from an exception's path reads it from the client instead.

## Moving to JWT sign-in (optional)

A legacy token keeps working. To move an existing sign-in to the 7-day
JWT that the client refreshes on its own:

```dart
final key = await PlexDeviceKey.generate();
await plex.account.registerJwtKey(key: key, token: legacyToken);
await plex.useJwt(PlexJwtSession(key: key, onChanged: persist));
```

New sign-ins use `createJwtPin()` and `pollJwtPin()` instead of
`createPin()` and `pollPin()`. See the Client and sign-in topic.

## Connecting

`bestConnection()` keeps its name and now follows `rankedConnections()`
(local, remote, relay; HTTPS before HTTP; IPv4 before IPv6), still without
checking that the connection answers. `connectToResource()` checks:

| 0.2.x | 0.3.0 |
| --- | --- |
| `plex.connect(server.bestConnection()!.uri, accessToken: server.accessToken)` | `await plex.connectToResource(server)` |

# Migrating to 0.2.0

0.2.0 replaces Dio with `package:http`, names every id, and returns typed
models where 0.1 returned maps. Most apps need the first three sections.

## The transport is package:http

`PlexClient` takes any `http.Client`, or none for the default `dart:io`
one. Dio types are gone from the API.

| 0.1.x | 0.2.0 |
| --- | --- |
| `PlexClient(credentials: c, dio: myDio)` | `PlexClient(credentials: c, httpClient: myClient)` |
| Dio's `Response<T>`, `ResponseType`, `CancelToken` | `PlexResponse<T>`, `PlexResponseType`, `PlexCancelToken` |
| `on DioException`, `PlexException.fromDio` | `on PlexException` |
| `plex.fetchBytes(url)` | `plex.requestBytes(url)` |
| `e.isRetriable` | `e.isNetworkFailure`, or `e.isTransient` to include 5xx and 429 |

`res.data` keeps its shape: `plex.get<Map<String, Object?>>(path)` returns
a `PlexResponse<Map<String, Object?>>`.

Tests that injected a Dio `HttpClientAdapter` inject an `http.Client`
instead (`MockClient` from `package:http/testing.dart`, or a `BaseClient`
subclass) and read `request.url`.

To cancel what a page started, use a view of the client:

```dart
final token = PlexCancelToken();
final page = plex.withCancelToken(token);
final albums = await page.library.children(ratingKey: artistKey);
token.cancel(); // every pending call of the view fails with isCancelled
```

## Every id is a named parameter

Ids were positional in some methods and named in others. All are named.

| 0.1.x | 0.2.0 |
| --- | --- |
| `plex.library.item(key)` | `plex.library.item(ratingKey: key)` |
| `plex.library.children(key)` | `plex.library.children(ratingKey: key)` |
| `plex.playlists.items(id)`, `delete(id)` | `plex.playlists.items(playlistId: id)`, `delete(playlistId: id)` |
| `plex.playback.scrobble(key)` | `plex.playback.scrobble(ratingKey: key)` |
| `plex.streaming.stopUniversal(session)` | `plex.streaming.stopUniversal(session: session)` |
| `plex.playQueues.clear(id)` | `plex.playQueues.clear(playQueueId: id)` |
| `plex.account.pollPin(id)` | `plex.account.pollPin(id: id)` |

The analyzer names every call to change. `preferences.set(values)` and
`library.matches(filters)` keep their positional map.

## Typed answers

| 0.1.x | 0.2.0 |
| --- | --- |
| `(await plex.server.identity())['machineIdentifier']` | `(await plex.server.identity()).machineIdentifier` |
| `server.info()` → map | `PlexServerInfo` |
| `sessions.history()` → `List<Map>` | `PlexMediaContainer<PlexHistoryEntry>`: `.items`, `.totalSize` |
| `activities.list()`, `butler.tasks()`, `preferences.all()` → maps | `PlexActivity`, `PlexButlerTask`, `PlexSetting` |
| `preferences.byId(id)` | `preferences.byId(id: id)`, `null` for an unknown id |
| `container.raw['Metadata']` | `container.items`: `raw` holds the envelope's other fields |
| `metadata.raw['Role']` | `metadata.roles` |
| `metadata.raw['playlistItemID']` | `metadata.playlistItemId` |

Each model keeps the server's map in `raw`. Maps and lists the API exposes
are `Object?` instead of `dynamic`: `raw['a']['b']` becomes
`(raw['a'] as Map<String, Object?>)['b']`.

## Final classes

Models, `PlexException`, `PlexCredentials`, `PlexFilter`,
`PlexNotification` and `PlexTranscodeDecision` are `final`: build a model
with its `fromJson` instead of extending it. `PlexClient` and the sub-APIs
stay open but gained members (`close`, `withCancelToken`,
`requestStream`, new methods), so a fake that implements one must add
them, or use `noSuchMethod`.

## Playback reporting and streaming

| 0.1.x | 0.2.0 |
| --- | --- |
| `timeline(state: 'playing', …)` | `timeline(playState: PlexPlayState.playing, …)` |
| `timeline(playQueueItemId: '7', …)` | `timeline(playQueueItemID: 7, …)` |
| `streaming.universalAudioUrl(…)` | `await streaming.startAudioTranscode(…)`: `.url`, `.decision`, `.session` |
| `nearestToTrack(excludeParentID: int.parse(key))` | `nearestToTrack(excludeParentRatingKey: key)` |
| `library.autocomplete(sectionId: s, fieldQuery: q)` | `library.autocomplete(sectionId: s, type: PlexMetadataType.track, fieldQuery: q)` |
| `PlexDVRsApi` | `PlexDvrsApi` |

The old forms of the first four, and `PlexDVRsApi`, still work and are
deprecated.

## Behavior changes

- `timeline()` throws `ArgumentError` for a duration of zero or less: the
  server never counts a play reported without its length. Send the real
  duration, or no report while it is unknown.
- `playlists.items()`, `library.children()` and `allLeaves()` throw
  `ArgumentError` for a `start` without a `size`: the server ignores a
  start alone and answers the whole list.
- `streaming.stopUniversal()` returns normally when the session is
  already gone.
- `scrobble()`, `unscrobble()`, `rate()` and `setFavorite()` are sent as
  `PUT`.
- In `request()`, an empty answer without a JSON content type is `null`,
  not `""`; a `List<int>` body is sent as bytes; query values that are not
  strings are form-encoded.
- The wait for the response headers is bounded by `connectTimeout` plus
  `receiveTimeout`. An injected client brings its own connect timeout.
