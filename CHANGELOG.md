## [0.2.0] - unreleased

A revision of the whole package. See [MIGRATION.md](MIGRATION.md) for the changes to make in an app.

### Breaking
- The transport is `package:http`, not Dio. Pass any `http.Client` as `httpClient:` (`dio:` is gone). `request()` and its siblings return a `PlexResponse<T>` and take a `PlexResponseType` and a `PlexCancelToken`. `PlexException.fromDio` and `fetchBytes()` are gone.
- Every id is a named parameter: `library.item(ratingKey: …)`, `playlists.items(playlistId: …)`, `playback.scrobble(ratingKey: …)` and so on.
- `server.identity()`, `server.info()`, `sessions.history()`, `activities.list()`, `butler.tasks()` and `preferences.all()` return typed models instead of maps. `preferences.byId()` returns `null` for an unknown id.
- The API exposes `Object?` instead of `dynamic` in its maps and lists.
- Models, `PlexException`, `PlexCredentials`, `PlexFilter`, `PlexNotification` and `PlexTranscodeDecision` are `final`. `PlexClient` and the sub-APIs gained members, so a fake that implements one must add them.
- `PlexMediaContainer.raw` holds the envelope's own fields, without the entry array.
- `playback.timeline()` takes exactly one of `playState:` and the deprecated `state:`, and throws `ArgumentError` for a duration of zero or less, a negative time or `PlexPlayState.unknown`.
- `playlists.items()`, `library.children()` and `allLeaves()` throw `ArgumentError` for a `start` without a `size`.
- `library.autocomplete()` requires a `PlexMetadataType type`.
- `streaming.stopUniversal()` returns normally when the session is already gone.
- An empty answer without a JSON content type is `null` in `PlexResponse.data`, not `""`. Query values that are not strings are form-encoded, and a `List<int>` body is sent as bytes.

### Added
- `PlexClient.withCancelToken()`, a view of the client whose calls one token cancels, and `PlexClient.close()`.
- `PlexRetryPolicy`: opt-in resend of `GET` and `HEAD` after a network failure, `502`, `503`, `504` or `429`, with backoff and `Retry-After`.
- `PlexException.isNetworkFailure`, `isTransient`, `isNotFound`, `isCancelled` and `retryAfter`.
- `requestStream()`, and `downloadToFile()` in the new `package:dart_plex/io.dart`.
- `library.children()` with paging and sort, `countChildren()`, `allLeaves()` with paging, `grandchildren()`, `recentlyAdded()` and `search.section()`.
- `playlists.list()` and `count()` take `filters:` and `sort:`.
- `streaming.startAudioTranscode()`, which makes the decision and caps the bitrate the way the server accepts, and `PlexStreamingApi.musicProfileExtra()`.
- Typed notification events: `PlexEvent` with `PlexPlaySessionEvent`, `PlexLibraryItemEvent`, `PlexActivityEvent`, `PlexStatusEvent` and `PlexUnknownEvent`, through `notification.events` or `stream.events()`.
- `timeline(playState:, playQueueItemID:)`.
- `PlexMetadata.roles`, `playlistItemId`, `audioStream`, `originallyAvailableAt`, `parentYear`, `leafCount`, `viewedLeafCount`, `childCount`, `skipCount`, `lastRatedAt`, `librarySectionId`, `librarySectionTitle`, `parentGuid`, `grandparentGuid`, `distance`, `score` and `ultraBlurColors`.
- `PlexMetadata.thumbVersion`, `artVersion`, `parentThumbVersion`, `grandparentThumbVersion` and `PlexArtwork.versionOf()`, for artwork cache keys.
- `PlexStream.gain`, `albumGain`, `peak`, `albumPeak`, `loudness` and `lra`.
- `PlexPaging.pages()` and `items()`.

### Changed
- Large responses are decoded, inflated and parsed into models on a background isolate, above `jsonIsolateThreshold` (50 KB by default).
- `scrobble()`, `unscrobble()`, `rate()` and `setFavorite()` are sent as `PUT`.
- `timeline()` sends a time past the duration as the duration.
- `PlexDVRsApi` is `PlexDvrsApi`; the old name is a deprecated typedef.
- `streaming.universalAudioUrl()` is deprecated: use `startAudioTranscode()`.
- `timeline(state: String)` and the `PlexPlaybackApi.state*` constants are deprecated: use `playState:`. `timeline(playQueueItemId: String)` is deprecated: use `playQueueItemID: int`.
- `nearestToTrack(excludeParentID:, excludeGrandparentID:)` are deprecated: use `excludeParentRatingKey` and `excludeGrandparentRatingKey`.
- `isRetriable` is deprecated: use `isNetworkFailure`, or `isTransient` to include 5xx and 429.
- The pinned API document is LukeHagar/plex-api-spec@3f0fb272b29c, and a contract test checks every request against it.

### Fixed
- `library.firstCharacters()` calls `/firstCharacter`: the old route answered 404.
- `library.setItemArtwork(data:)` uploads the bytes instead of their text.
- `notifications.connectEventSource()` keeps a quiet stream open, and closing it before the server answers cancels the request.
- A gzip body cut short fails instead of coming back short.
- Two `create` calls throw a `PlexException` of type `parse`, not a bare `Exception`, when the server answers no item.

## [0.1.3] - 22-09-2026

### Added
- `playlists.items()` takes optional `start` and `size` for paging. Without them it still returns the whole playlist.

### Changed
- The default transport decodes JSON responses of 50 KB or more on a background isolate (`PlexConnection.jsonIsolateThreshold`). A `Dio` you inject keeps its own transformer.

## [0.1.2] - 09-09-2026

### Fixed
- `streaming.lyrics()` returns readable text whatever the file's encoding: accented characters in a UTF-8 `.lrc` came back mangled, and a UTF-16 one full of NUL.
- `notifications.connectEventSource()` decodes the event stream as a whole, so a multi-byte character split across two network chunks no longer becomes U+FFFD.

## [0.1.1] - 12-08-2026

### Breaking
- `library.allByType()` and `countByType()` take `filters`, a list of `PlexFilter`, instead of `filter`: write `filters: [PlexFilter.genre(6)]` for `filter: 'genre=6'`. Several filters are combined with AND.
- `library.allByType()` loses its `title` argument: use `PlexFilter.titleContains()` or `PlexFilter.titleIs()`.
- `library.genres()` returns `List<PlexTag>` instead of `List<PlexMetadata>`. Pass a tag to `PlexFilter.of(tag)`; use `tag.title` for its name.
- `library.filters()` returns `List<PlexLibraryFilter>`: `field`, `valueType` and `valuesKey` replace `raw['filter']`, `raw['filterType']` and `key`.
- `library.updateSectionItems()` names its argument `filterExpression` instead of `filters`. The request is unchanged.

### Added
- `PlexFilter`, a typed library filter: `genre()`, `tag()`, `year()`, `yearAfter()`, `yearBefore()`, `ratingAbove()`, `rated()`, `unplayed()`, `played()`, `titleContains()`, `titleIs()`, `firstCharacter()`, `studio()`, `contentRating()`, `resolution()`, and `number()`, `text()`, `flag()` and a plain constructor for other fields.
- `PlexFilter.of(tag)`, the filter for a genre, mood or style the server returned.
- `library.filterValues()`: the values a facet can take.
- `PlexTag`, `PlexLibraryFilter` and `PlexFilterValueType`.

### Fixed
- Filtering a library section works. `filter: ...` was sent as a parameter named `filter`, which Plex ignores, so every filtered call returned the whole section. Filters travel as one parameter per condition, with the operator in the name: `?genre=6`, `?year>>=2009`, `?unwatched=1`.
- `library.countByType()` sends the same request as `allByType()` with a page size of zero, so a count matches the page it counts, filters included.

## [0.1.0] - 30-06-2026

### Breaking
- `liveTv.history()`, `liveTv.subscriptions()` and `liveTv.cancelSubscription()` are gone: their routes do not exist. Use `sessions.history()` and `PlexClient.subscriptions`.
- `streaming.directFileUrl()` takes the item's file key instead of a part id and container.
- `server.securityResources()` requires a `source`.
- `server.transientToken()` takes no `type` or `scope` and returns the token string.
- `transcoder.imageUrl()`: `chromaSubsampling` is a number from 0 to 3.
- `devices.setChannelMap()` sends the mapping and the enabled channels the way Plex reads them.
- `epg.bestLineup()` requires `device` and `lineupGroup`.
- `epg.lineupChannels()` takes a list of lineups.
- `playlists.moveItem()`, `playQueues.moveItem()` and `subscriptions.reorder()` move an item to the front when `after` is left out.
- `PlexStream.selected` means the user picked the stream; the file default is `PlexStream.isDefault`.
- `PlexHub.key` fetches a hub's content; `hubKey` is the optional re-fetch key.
- `subscriptions.create()`: `type` is a number.
- `notifications.connectWebSocket()` returns a `Future` that completes once the socket is open, and a failed connection throws.

### Added
- `library.editItem()`, `deleteMetadataItem()`, `setItemArtwork()` and `updateSectionItems()`.
- `hubs.forMetadata()`: the related rows of one item.
- `sessions.historyItem()`: one playback history entry.
- `playlists.upload()`: import an m3u playlist from a path on the server.
- `PlexClient.clearSession()`: drop the token and stay connected.

### Changed
- `collections.create()` makes empty, named, typed and smart collections.
- `playQueues.create()` takes a `key` for the starting item.
- `search.voice()` takes a `type`.
- `streaming.decisionUniversal()` takes a `transcodeType`.
- `PlexCredentials` accepts the optional `X-Plex-Model`, `X-Plex-Device-Vendor` and `X-Plex-Marketplace` headers.
- `request()` and `requestBytes()` take a `CancelToken`; a cancelled request is `PlexErrorType.cancelled`.
- `PlexException` keeps the original stack trace.
- `PlexClient.fetchBytes` is deprecated: use `requestBytes`.

### Fixed
- `addSection()` and `editSection()` apply the library settings they are given.
- The transcode decision reads error codes as errors, so `isPlayable`, `isDirect` and `isTranscode` are right.
- `playlists.generators()` reads the right field.
- `preferences.byId()` returns the setting in the same shape as `all()`.
- `sessions.history()` includes the start and end dates it is given.
- `transcoder.imageUrl()`, `subtitlesUrl()` and `startUrl()` throw before connecting instead of returning a broken URL.
- `subscriptions.editPreferences()` sends the settings in the form Plex reads.
- A body that cannot be decoded is a `parse` error.
- `PlexResource.provides` is empty when a resource advertises nothing.
- `PlexMetadataType.photoAlbum` uses the value Plex sends.

## [0.0.2] - 25-05-2026

### Fixed
- General minor fixes.

## [0.0.1] - 25-05-2026

### Added
- Initial release, for Plex Media Server `v1.43.x`.
- Sign-in with username and password, and the PIN link flow.
- The PMS HTTP client with the `X-Plex-*` identity headers.
- `PlexException` with a semantic `PlexErrorType`.
- Music endpoints: libraries, sections, items by type, playlists, artwork, audio streaming, playback reporting, search and favourites.
- Play queues, with `PlexPlayQueue`.
- Notifications over WebSocket and Server-Sent Events.
- Typed models, each with a `raw` map.
