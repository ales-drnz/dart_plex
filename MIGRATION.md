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
