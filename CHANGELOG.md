## [0.2.0] - 11-10-2026

Targets Plex Media Server `1.43.x`; every behaviour noted as verified below was checked against PMS `1.43.2` in the integration stack.

### Breaking
- **The transport is `package:http`, not Dio.** `PlexClient(dio:)` is gone: pass any `http.Client` as `httpClient:` (a `CupertinoClient` or `CronetClient` for HTTP/2 and the system proxy, a `MockClient` in tests), or none for the default `dart:io` one. `request()` / `get()` / `post()` / `put()` / `delete()` return a `PlexResponse<T>` (`.data`, `.statusCode`, `.headers`, `.contentType`) instead of Dio's `Response<T>`, take a `PlexResponseType` instead of Dio's `ResponseType`, and a `PlexCancelToken` instead of Dio's `CancelToken`. `requestBytes()` answers a `PlexResponse<Uint8List>`. `PlexException.fromDio` and the deprecated `fetchBytes()` are gone. The query string, body and headers on the wire are unchanged.
- **Typed answers instead of maps**: `server.identity()` → `PlexServerIdentity`, `server.info()` → `PlexServerInfo`, `sessions.history()` → `PlexMediaContainer<PlexHistoryEntry>` (with `totalSize`), `activities.list()` → `List<PlexActivity>`, `butler.tasks()` → `List<PlexButlerTask>`, `preferences.all()` / `byId()` → `PlexSetting`. Each keeps the body in `raw`, so `identity()['machineIdentifier']` becomes `identity().machineIdentifier` (or `.raw['machineIdentifier']`).
- **`Object?` instead of `dynamic`** in every map and list the API exposes (`raw`, `queryParameters`, the admin answers that are still maps). Reading and assigning work as before; a chained dynamic access such as `raw['a']['b']` now needs a type check.
- **Models are `final`**: they can no longer be extended or implemented outside the package. `PlexClient` and the sub-API classes stay open, so test fakes still work.
- `playback.timeline()` throws an `ArgumentError` for `durationMs <= 0` or a negative `timeMs`: PMS never counts a play reported with duration 0 (verified).
- `playlists.items()` and `children()` / `allLeaves()` refuse a `start` without a `size`, and always send `X-Plex-Container-Start` with `-Size`: PMS ignores `Size` on its own and answers the whole list (verified).
- `streaming.stopUniversal()` returns normally on 404 (the session is already gone).

### Added
- `PlexClient.withCancelToken(token)`: a view of the client whose every sub-API call is cancelled by `token.cancel()` — for leaving a page, changing a filter, typing in a search.
- `PlexRetryPolicy` (`retryPolicy:`): opt-in resend of `GET` / `HEAD` after a network failure, `502`, `503`, `504` or `429`, with backoff, jitter and `Retry-After`.
- `PlexException.isNetworkFailure`, `isTransient`, `isNotFound`, `isCancelled`, `retryAfter`, with the same meaning as in `dart_jellyfin`.
- `requestStream()`, and `downloadToFile()` in the new `package:dart_plex/io.dart` (streams to disk, whole file or none, with progress).
- `library.children(key, start:, size:, sort:)`, `countChildren()`, `allLeaves(key, start:, size:)`, `grandchildren()`, `recentlyAdded(sectionId:)`; `search.section()`.
- `playlists.list()` / `count()` take `filters:` — `/playlists` honours the general filter syntax, e.g. `PlexFilter.titleContains()` and `PlexFilter.rated()` (verified) — and `sort:`.
- `PlexMetadata.playlistItemId`, for removing or moving one entry of a track listed twice.
- `PlexMetadata.thumbVersion`, `artVersion`, `parentThumbVersion`, `grandparentThumbVersion` and `PlexArtwork.versionOf()`: the timestamp PMS appends to artwork paths, which changes with the image (verified) — for artwork cache keys.
- `PlexStream.gain`, `albumGain`, `peak`, `albumPeak`, `loudness`, `lra`; `PlexMetadata.audioStream`.
- `PlexMetadata.originallyAvailableAt`, `parentYear`, `leafCount`, `viewedLeafCount`, `childCount`, `skipCount`, `lastRatedAt`, `librarySectionId`, `librarySectionTitle`, `parentGuid`, `grandparentGuid`, `distance`, `score`, `ultraBlurColors`.
- Typed notification events: `PlexNotification.events` and `Stream<PlexNotification>.events()` decode frames into `PlexPlaySessionEvent`, `PlexLibraryItemEvent`, `PlexActivityEvent`, `PlexStatusEvent` and `PlexUnknownEvent`, following frames captured from PMS 1.43.2.
- `playback.timeline(playState: PlexPlayState, playQueueItemID: int)`.
- `streaming.startAudioTranscode()` and `PlexStreamingApi.musicProfileExtra()`.
- `PlexPaging.pages()` / `items()`.

### Changed
- JSON decoding, model parsing and gzip inflation run on a background isolate above `jsonIsolateThreshold` (50 KB by default, now a constructor argument). Measured on six parallel 1.5 MB pages, the stall of the calling isolate went from 38–64 ms to 14–23 ms.
- `scrobble()`, `unscrobble()` and `rate()` are sent as `PUT`, as the API document asks (`GET` still works on 1.43.2).
- The pinned community API document moves to LukeHagar/plex-api-spec@3f0fb272b29c.
- Stricter lints; every documentation reference resolves.

### Fixed
- `library.firstCharacters()` called `/firstCharacters`, which answers 404; the route is `/firstCharacter`.
- A transcode PMS accepts: `universalAudioUrl()` built a URL PMS 1.43.2 refuses (no prior decision, no client profile — there is none for platform `Linux` or `macOS` — no transcode target) and its `maxAudioBitrate` had no effect. `startAudioTranscode()` makes the decision, sends `X-Plex-Client-Profile-Name` and the target, and caps the bitrate with a profile limitation (96 → a 96 kbps stream, verified).
- Two `create` calls threw a bare `Exception` when the server answered no item; they throw a `PlexException` of type `parse`.

### Deprecated
- `streaming.universalAudioUrl()` → `startAudioTranscode()`.
- `timeline(state: String)` and `PlexPlaybackApi.state*` → `timeline(playState: PlexPlayState)`; `timeline(playQueueItemId: String)` → `playQueueItemID: int`.
- `nearestToTrack(excludeParentID: int, excludeGrandparentID: int)` → `excludeParentRatingKey` / `excludeGrandparentRatingKey` (`String`).

### Notes (verified on PMS 1.43.2)
- **What counts a play**: timeline reports in real time covering about half the track (50 % of 60 s counted, 40 % did not); fast-forwarded reports and `duration=0` never count; a 3 s track never counted. A counted play adds a history entry; `scrobble()` does not.
- `/library/metadata/{id}/allLeaves` ignores `sort`.
- PMS serves an MP3 part without its ID3v2 tag: a downloaded file has no embedded tags or cover.
- PMS ignores adding an item that is already in a regular playlist.
- Several routes in the community document answer 404 (`/library/metadata/{id}/parent`, `/grandparent`, `/library/sections/{id}/hubs`, `/artists`, `/byDecade`, `/playlists`); they are not wrapped.

### Tests
- A spec contract test calls every public method and checks each request's route, method and query parameters against the pinned document; parameters the document misses are listed with how they were verified.
- Wire tests for the new surface, real anonymised fixtures, integration tests against PMS 1.43.2, and read-only live tests against any server (`PLEX_URL` / `PLEX_TOKEN`, tag `live`).

## [0.1.3] - 22-09-2026

### Added
- `playlists.items()` takes optional `start` and `size` for paging. Without them it still returns the whole playlist.

### Changed
- The default transport decodes JSON responses of 50 KB or more on a background isolate (`PlexConnection.jsonIsolateThreshold`), so large responses no longer block the caller's isolate. A `Dio` you inject keeps its own transformer.

## [0.1.2] - 09-09-2026

### Fixed
- `streaming.lyrics()` returns readable text whatever the file's encoding. Each byte was read as one code unit, so accented characters in a UTF-8 `.lrc` came back mangled and a UTF-16 one came back full of NUL.
- `notifications.connectEventSource()` decodes the event stream as a whole instead of one network chunk at a time, which turned any multi-byte character split across a chunk boundary into U+FFFD.

## [0.1.1] - 12-08-2026

### Breaking
- `library.allByType()` and `library.countByType()`: the `filter` argument is gone, replaced by `filters` — a list of `PlexFilter`. The old argument was sent as a query parameter literally named `filter`, which Plex has no such thing as, so every filtered call quietly came back unfiltered. Instead of `filter: 'genre=6'` write `filters: [PlexFilter.genre(6)]`; instead of `filter: 'userRating>>=8'` write `filters: [PlexFilter.ratingAbove(8)]`. Several filters in the list are ANDed.
- `library.allByType()` lost its `title` argument. It was a filter wearing a different hat, and two ways to filter one call is how the bug above happened. Write `filters: [PlexFilter.titleContains('abbey')]` for the old behaviour, or `PlexFilter.titleIs('Abbey Road')` for a whole-title match.
- `library.genres()` now returns `List<PlexTag>` instead of `List<PlexMetadata>`. A `PlexTag` has the numeric `id` you filter by as a typed field; getting it used to mean digging through `raw['fastKey']` or `raw['key']` and knowing that `key` is a bare id on current servers but a path on older ones. Pass the tag straight to `PlexFilter.of(tag)`; use `tag.title` where you used `metadata.title`.
- `library.filters()` now returns `List<PlexLibraryFilter>` instead of `List<PlexMetadata>`. These entries were never metadata items. Use `f.field` for the query parameter to filter on (it was `raw['filter']`), `f.valueType` for `raw['filterType']`, and `f.valuesKey` for the endpoint listing the values (it was `f.key`). The `Pivot` array is still in `raw`.
- `library.updateSectionItems()`: the `filters` argument is now called `filterExpression`. Its wire form is unchanged — it is still sent as the PUT route's own `filters` parameter, which really does take one whole expression as a string. Only the Dart name changed, so that it can no longer be mistaken for `allByType`'s list of `PlexFilter`.

### Added
- `PlexFilter`, a typed library filter you compose instead of writing query fragments by hand: `PlexFilter.genre()`, `.tag()`, `.year()`, `.yearAfter()`, `.yearBefore()`, `.ratingAbove()`, `.rated()`, `.unplayed()`, `.played()`, `.titleContains()`, `.titleIs()`, `.firstCharacter()`, `.studio()`, `.contentRating()`, `.resolution()`, plus `.number()`, `.text()`, `.flag()` and a plain constructor for fields the named ones do not cover. Every operator these produce was checked against a live PMS 1.43.2.
- `PlexFilter.of(tag)` builds the filter for a genre, mood or style row you got back from the server, reading both the field name and the id off the tag so neither is spelled by hand.
- `library.filterValues()`: the values a facet can take (the moods, styles or decades behind a `PlexLibraryFilter`), fetched by following the endpoint the server itself nominates for them.
- `PlexTag` and `PlexLibraryFilter` DTOs, and `PlexFilterValueType` for a facet's `string` / `integer` / `boolean` value kind.

### Fixed
- Filtering a library section works. `library.allByType(filter: ...)` and `countByType(filter: ...)` sent `?filter=genre%3D6`; Plex ignores query parameters it does not recognise and answers 200 with the whole section, so every genre showed the same albums and a "favourites" view returned the entire library. Filters now travel the way the server states them in its own `fastKey` — one query parameter per condition, named after the field, with the operator in the name: `?genre=6`, `?year>>=2009`, `?unwatched=1`.
- `library.countByType()` now runs the identical request to `allByType()` with `X-Plex-Container-Size=0` rather than a second hand-rolled copy of it, so a count can no longer disagree with the page it counts, and it takes the same filters.

## [0.1.0] - 30-06-2026

### Deprecated
- `PlexClient.fetchBytes` is deprecated. Use `requestBytes` instead (same thing, and it already handles full URLs).

### Breaking
- `liveTv.history()`, `liveTv.subscriptions()` and `liveTv.cancelSubscription()` are gone. They pointed at Plex routes that don't exist, so they always failed. Use `sessions.history()` for playback history and `PlexClient.subscriptions` for recording rules instead.
- `streaming.directFileUrl()` now takes the item's full file key instead of a part id and container. The old form built a URL Plex couldn't serve.
- `server.securityResources()` now needs a `source`; Plex rejects the call without one.
- `server.transientToken()` no longer takes `type` or `scope` (Plex only allows one mode) and returns the token string directly.
- `transcoder.imageUrl()`: `chromaSubsampling` is now a number (0 to 3) instead of free text, matching what Plex accepts.
- `devices.setChannelMap()`: channel remapping actually works now. The mapping and enabled-channels arguments are sent the way Plex expects.
- `epg.bestLineup()` now needs both `device` and `lineupGroup`.
- `epg.lineupChannels()` takes a list of lineups instead of one, so you can fetch several at once.
- To move an item to the front with `playlists.moveItem()`, `playQueues.moveItem()` or `subscriptions.reorder()`, just leave `after` out. It is now optional (passing `0` never worked).
- `PlexStream.selected` now means only "the user picked this stream". The separate "file default" flag is its own `PlexStream.isDefault` field.
- `PlexHub` gained a `key` field for fetching its content; `hubKey` is documented as the optional re-fetch key.
- `subscriptions.create()`: `type` is now a number, matching what Plex expects.
- `notifications.connectWebSocket()` now returns a `Future` and waits for the connection to open before returning. `isWebSocketConnected` is only `true` once the socket is really open, and a failed connection throws straight away instead of showing up later on the stream.

### Added
- `library.editItem()`, `library.deleteMetadataItem()`, `library.setItemArtwork()` and `library.updateSectionItems()`: edit an item's fields, delete an item, set custom artwork, and bulk-edit many items at once.
- `hubs.forMetadata()`: the related rows for one item (e.g. "More from this artist").
- `sessions.historyItem()`: fetch a single playback-history entry by id.
- `playlists.upload()`: import an m3u playlist from a path on the server.
- `PlexClient.clearSession()`: drop the token but stay connected to the server.

### Changed
- `collections.create()` can now make empty, named, typed and smart collections (the seed item is optional, with a new `smart` flag).
- `playQueues.create()` gained a `key` to pick the starting item and turn on shuffle.
- `search.voice()` gained a `type` filter to limit a voice search to one kind of media.
- `streaming.decisionUniversal()` gained `transcodeType` so it works for video, audio and photo.
- `PlexCredentials` now accepts the optional `X-Plex-Model`, `X-Plex-Device-Vendor` and `X-Plex-Marketplace` identity headers.
- You can pass a `CancelToken` to `request()` and `requestBytes()` to cancel a request that is still running; a cancelled request now reports `PlexErrorType.cancelled` instead of a generic `unknown`.
- `PlexException` now keeps the original stack trace, so crash reports point at where the failure actually happened.

### Fixed
- Library settings passed to `addSection()` and `editSection()` are now actually applied. Before, they were sent in a form Plex ignored, so a new or edited library quietly kept its defaults.
- The transcode decision is read correctly now: a successful decision counts as playable (direct play or transcode) and error codes count as errors, so `isPlayable`, `isDirect` and `isTranscode` no longer mistake an error for "needs transcoding".
- `playlists.generators()` reads the right field, so it no longer always comes back empty.
- `preferences.byId()` returns the setting itself, in the same shape as the entries from `all()`, instead of the raw response wrapper.
- `sessions.history()` date filters now include the start and end dates you pass, instead of dropping items that land exactly on them.
- `transcoder.imageUrl()`, `subtitlesUrl()` and `startUrl()` now throw a clear error when called before connecting, instead of returning a broken URL.
- `subscriptions.editPreferences()` now sends recording settings in the form Plex expects, so edits take effect.
- A response body that can't be decoded is now reported as a `parse` error instead of a generic `unknown`.
- `PlexResource.provides` returns an empty list (not a list holding one empty string) when a resource advertises nothing, and trims stray spaces.
- `PlexMetadataType.photoAlbum` now uses the exact value Plex sends.

## [0.0.2] - 25-05-2026

### Fixed
- General minor fixes.

## [0.0.1] - 25-05-2026

### Added
- Initial scaffold targeting Plex Media Server `v1.43.x`.
- Authentication flows: legacy username and password, and the official PIN link.
- PMS HTTP client with `X-Plex-*` header injection (client identifier, product, version, device, platform, token).
- Exception hierarchy with semantic error classification (`auth`, `notFound`, `serverError`, `parse`, `state`, `connection`, `timeout`, `badRequest`, `unknown`).
- Music endpoints: libraries, sections, items by type, playlists, artwork, audio streaming (universal transcode + direct), playback reporting, search, favorites.
- Play queue lifecycle with the new `PlexPlayQueue` DTO surfacing the server-assigned queue id, selected item id, shuffle and version state, and initial contents.
- Notifications transport over both WebSocket (`/:/websockets/notifications`) and Server-Sent Events (`/:/eventsource/notifications`).
- Typed DTOs across the documented API surface, plus a `raw` escape hatch on every model for fields not yet promoted.
