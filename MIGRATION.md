# Migrating to dart_plex 0.2

## What breaks, and what to write instead

| 0.1.x | 0.2 |
|---|---|
| `PlexClient(credentials: c, dio: myDio)` | `PlexClient(credentials: c, httpClient: myHttpClient)` — any `package:http` `Client`; omit it for the default |
| `import 'package:dio/dio.dart'` for `Response`, `CancelToken`, `ResponseType` | `PlexResponse<T>`, `PlexCancelToken`, `PlexResponseType` (exported by `dart_plex`) |
| `final res = await plex.get<Map<String, dynamic>>(path); res.data` | unchanged shape: `res.data` is there; the type is `PlexResponse<Map<String, Object?>>` |
| `plex.request(path, cancelToken: CancelToken())` | `plex.request(path, cancelToken: PlexCancelToken())` — or `plex.withCancelToken(token).library…` for every call |
| `on DioException` / `PlexException.fromDio` | `on PlexException` only; `e.isNetworkFailure`, `e.isTransient`, `e.isNotFound`, `e.isCancelled` |
| `plex.fetchBytes(url)` | `plex.requestBytes(url)` |
| `(await plex.server.identity())['machineIdentifier']` | `(await plex.server.identity()).machineIdentifier` |
| `plex.sessions.history()` → `List<Map>` | → `PlexMediaContainer<PlexHistoryEntry>`; read `.items`, `.totalSize` |
| `activities.list()`, `butler.tasks()`, `preferences.all()/byId()` → maps | `PlexActivity`, `PlexButlerTask`, `PlexSetting` (`.raw` keeps the map) |
| `timeline(state: 'playing', …)` | `timeline(playState: PlexPlayState.playing, …)` (the `String` still works, deprecated) |
| `timeline(durationMs: 0, …)` | throws `ArgumentError`: PMS never counts such a play — send the real length |
| `timeline(playQueueItemId: '7')` | `timeline(playQueueItemID: 7)` |
| `nearestToTrack(excludeParentID: int.parse(key))` | `nearestToTrack(excludeParentRatingKey: key)` |
| `playlists.items(id, start: 10)` (no size) | throws `ArgumentError`: PMS ignores paging without a size |
| `streaming.universalAudioUrl(…)` | `await streaming.startAudioTranscode(…)` → `.url`, `.decision`, `.session` |
| `raw['a']['b']` (dynamic access) | `(raw['a'] as Map<String, Object?>)['b']` |
| `class Fake extends PlexMetadata` | models are `final`; build them with `PlexMetadata.fromJson` |

Tests that injected a Dio `HttpClientAdapter` to inspect the outgoing URI now
inject an `http.Client` (`MockClient` from `package:http/testing.dart`, or a
`BaseClient` subclass) through `httpClient:` and read `request.url`.

## New API to adopt

```dart
// Cancel what a page started when the page goes away.
final token = PlexCancelToken();
final page = plex.withCancelToken(token);
final albums = await page.library.children(artistKey, start: 0, size: 50, sort: 'year:desc');
token.cancel();

// Counts without rows; an artist's tracks without a request per album.
final albumCount = await plex.library.countChildren(artistKey);
final tracks = await plex.library.grandchildren(artistKey, size: 200);

// Playlists narrowed on the server.
final favourites = await plex.playlists.list(
  type: 'audio',
  filters: [PlexFilter.rated(), PlexFilter.titleContains(query)],
);

// One entry of a playlist, not every copy of the track.
await plex.playlists.removeItem(playlistId: id, playlistItemId: entry.playlistItemId!);

// Artwork cache key that changes when the cover does.
final version = track.parentThumbVersion ?? track.thumbVersion;

// Loudness, when the transcode drops ReplayGain tags.
final gain = (await plex.library.item(track.ratingKey))?.audioStream?.gain;

// Live updates.
final socket = await plex.notifications.connectWebSocket();
socket.events().listen((event) { /* PlexLibraryItemEvent, PlexPlaySessionEvent, … */ });

// A transcode PMS accepts.
final t = await plex.streaming.startAudioTranscode(
  ratingKey: track.ratingKey,
  session: sessionId,
  maxBitrateKbps: 192,
);
if (t.decision.isPlayable) player.open(t.url);
```

See `CHANGELOG.md` for everything verified on PMS 1.43.2 along the way.
