## [0.3.2]

### All platforms
**Fixed**
- A redirect to another host no longer takes the token there. plex.tv redirects an avatar URL (`PlexUser.thumb`) to Gravatar, which received it.
- `request()`, `requestBytes()`, `requestStream()` and `downloadToFile()` follow redirects themselves: a hop to another host loses the token, an `Authorization` and a `Cookie`.

**Changed**
- A redirect loop, a sixth redirect and a `Location` that is not an `http` URL are `unknown` errors with the status of the redirect.
- A redirect without a `Location` is an error with its status, not a `connection` error.
- A client passed as `httpClient` is asked not to follow redirects, since the connection does.
- In a browser the redirect is the browser's to follow: a host whose CORS policy accepts `X-Plex-Token` still receives it.

## [0.3.1] - 14-11-2026

### All platforms
**Deprecated**
- `account.friends()`: plex.tv removed the route (`410 Gone`) and has no REST replacement. `connectedUsers()` lists the users the account shares with.
- `transcoder.startUrl()` and `streaming.universalVideoUrl()`: PMS refuses a start without a decision, which `startVideoTranscode()` and `startAudioTranscode()` make first.

**Changed**
- The token goes only to the connected server and to plex.tv. A full URL to another host is requested without it, unless `extraHeaders` names one.
- `PlexMetadataType.photo` is `13` and `photoAlbum` is `14`, as PMS has them, instead of the other way round.
- A URL a player opens (`streamUrl()`, `transcodeUrl()`, `compositeImageUrl()` and the like) throws a `state` error before `connect()` instead of starting with `null`.
- Those URLs form-encode the token, put it last and leave it out when there is none, instead of sending `X-Plex-Token=` empty.
- An id in a request path is one encoded segment, so a `/` or a `?` in it cannot name another route. An empty id, `.` or `..` throws an `ArgumentError`.
- A call that returns a `Future` reports a wrong argument through it, never while it is being called.
- `playQueues.addItems()`, `epg.lineupChannels()`, `server.securityResources()`, `collections.create()` and `transcoder.imageUrl()` check their arguments in release builds too.
- `connect()` throws a `state` error at once for a URL without `http://` or `https://`, or without a host.
- `PlexClient.close()` also closes the notification WebSocket and event stream.
- `connectEventSource()` sends its request at the first listener, so a failure to open reaches the stream instead of being lost.
- An event stream that is silent for 60 seconds ends with a `timeout` error; `idleTimeout: null` turns that off.
- The event stream sends the token in a header, not in the query.
- `connectWebSocket()` gives up after `connectTimeout` (30 seconds), and a `401` or `403` on the handshake is an `auth` error.
- `server.ping()` rethrows a cancellation and a `state` error instead of answering `false`.
- `PlexHomeUser.protected` is the PIN flag alone; an account with a password and no PIN is no longer protected.
- A timestamp without a zone is read as UTC, not as the device's local time.
- `PlexFilter.tag()`, `of()`, `number()`, `text()` and `flag()` hold an unmodifiable list.
- A failed TLS handshake is a `connection` error instead of `unknown`.
- A token renewer that throws is the `cause` of the `401` it could not renew.
- The models are libraries of their own, one file per area, and the larger sub-APIs are split by concern. Nothing exported changed.

**Fixed**
- `collections.removeItem()` sends `DELETE`, which removes the item; PMS answers `404` to the `PUT` of the API document.
- `hubs.continueWatching()` reads the items inside its hub, so it no longer always comes back empty.
- A hub from `hubs.manage()` has its identifier, which `updateVisibility()`, `deleteCustom()` and `move()` need.
- `account.switchHomeUser()` reads plex.tv's `<user>` answer, whose children repeat its attributes, instead of failing with a `parse` error.
- Event-stream notifications have their real `type` and the WebSocket's shape, so `events()` reads them; the server's `ping` is no longer delivered.
- A second `connectWebSocket()` while the first is connecting throws a `state` error instead of leaking a socket.
- `pollJwtPin()` through `withCancelToken()` views asks plex.tv for one nonce, not one per view.
- A date out of range or a number that is not finite reads as `null` instead of failing the whole page.
- Lyrics lines that share a time keep the order of the file.
- Malformed plex.tv XML (a wrong closing tag, text after the root, absurd nesting) throws a `FormatException`, never a `StackOverflowError`.

**Added**
- `connectWebSocket(connectTimeout:)`, `connectEventSource(idleTimeout:)`, and `webSocketCloseCode`, `webSocketCloseReason` and `malformedFrameCount` on `notifications`.
- The CI also checks the API docs, the web build and the pub.dev score, and runs on `quality/*` branches.

## [0.3.0] - 8-11-2026

### All platforms
**Breaking**
- The package needs Dart `3.10` or later.
- `PlexClient` and the sub-APIs have new members, so a fake that implements one must add them.
- The names 0.2 deprecated are gone: `PlexDVRsApi`, `isRetriable`, `timeline(state:)` and `playQueueItemId:` (`playState` is required), the `PlexPlaybackApi.state*` constants, `universalAudioUrl()` and `nearestToTrack(excludeParentID:, excludeGrandparentID:)`.
- A lookup returns `null` when the answer holds nothing: `subscriptions.get()`, `devices.details()`, `dvrs.get()`, `downloadQueue.get()` and `item()`, `liveTv.liveSession()` and `library.person()`, and also `subscriptions.create()`.
- The other creates, `downloadQueue.create()` among them, throw a `parse` error on such an answer. The Errors and paging topic states the rule.
- `downloadQueue`, `liveTv`, `dvrs`, `devices`, `subscriptions` and `epg` return typed models instead of maps: `PlexDownloadQueue`, `PlexDownloadQueueItem`, `PlexDvr`, `PlexTunerDevice`, `PlexMediaGrabber`, `PlexDeviceChannel`, `PlexMediaSubscription`, `PlexMediaGrabOperation`, `PlexEpgCountry`, `PlexEpgLanguage`, `PlexLineup`, `PlexEpgChannel` and `PlexChannelMapping`.
- `liveTv.sessions()` and `liveSession()` return `PlexMetadata`.
- `library.tags()`, `matches()`, `person()` and `sectionDetails()`, `playlists.generators()`, `updater.status()`, `server.securityResources()` and `backgroundTasks()`, and `providers.list()` and `add()` return typed models instead of maps: `PlexTag`, `PlexMetadata`, `PlexPerson`, `PlexSectionDetails`, `PlexPlayQueueGenerator`, `PlexUpdaterStatus`, `PlexSecurityResource`, `PlexTranscodeJob` and `PlexMediaProvider`.
- `streaming.lyrics()` returns `PlexLyrics`, with the lines read as LRC and the text in `text`.
- `account.tokenDetails()` returns the `PlexUser` the server token belongs to, from plex.tv, instead of asking the server, which answered an empty container.
- `account.connectedUsers()` returns `PlexAccountUser`s from `plex.tv/api/users/`, instead of asking the server, which answered an empty container.
- `downloadQueue.itemMedia()` is `itemMediaUrl()`, as the route answers the file, not JSON.
- `itemMediaUrl()` throws a `state` error before `connect()`, and leaves out an absent token.
- The download queue takes `int` ids (`queueId:`, `itemId:`), as its models give them.
- `playlists.generatorItems()` and `reprocessGenerator()` take an `int` `generatorId:`, as `PlexPlayQueueGenerator.id` is.
- The bitrate caps are named `max…BitrateKbps`: `startAudioTranscode()` and `musicProfileExtra()` take `maxAudioBitrateKbps` instead of `maxBitrateKbps`, and `universalVideoUrl()` takes `maxVideoBitrateKbps` and `maxAudioBitrateKbps` instead of `videoBitrate` and `audioBitrate`.
- `startAudioTranscode()` and `universalVideoUrl()` take a `PlexStreamingProtocol` instead of a string.
- `universalVideoUrl()` takes the protocol's container when `container` is `null`.
- `sort` parameters take a `PlexSort`: `sort: PlexSort.addedAt.desc` instead of `sort: 'addedAt:desc'`.
- Playlist and play queue types take a `PlexMediaType`, `addSection()` a `PlexLibraryType`, `firstCharacters()` and `collections.create()` a `PlexMetadataType`, and the marker calls a `PlexMarkerType`.
- `library.tags()` and `sectionCommon()` require a `type`, as the server answers 400 without one.
- `connect(accessToken:)` keeps the token it replaces as the account token, for plex.tv calls.
- `clearSession()` also drops the account token and the JWT session.
- `PlexErrorType` has a new value, `passRequired`, which a `switch` over the type must handle.
- A `498` is an `auth` error.

**Added**
- plex.tv JWT sign-in: `PlexDeviceKey` (an Ed25519 key pair, pure Dart, on every platform), `account.createJwtPin()`, `pollJwtPin()`, `authAppUrl()`, `registerJwtKey()`, `authNonce()`, `exchangeDeviceJwt()` and `refreshJwt()`.
- `PlexDeviceKey.privateKey` and `publicKey` are copies.
- `PlexJwt` reads a token's expiry.
- `PlexJwt.parse()` throws a `parse` error for an `exp`, `iat` or `thumbprint` claim of the wrong type.
- `PlexClient.useJwt()` with a `PlexJwtSession` refreshes the 7-day JWT before it expires and after a `401` or `498`.
- `PlexJwtSession` hands each new token to `onChanged` to persist.
- A token received in a run is timed from its arrival by its `exp - iat`, so a skewed device clock does not refresh it on every call.
- A token issued for less than two days is refreshed at half its lifetime.
- A refreshed token bound to another key is refused.
- When the first refresh fails, `useJwt()` leaves the client as it was.
- `PlexClient.tokenRenewer`, a `PlexTokenRenewer`, is called with the connection's token when the server refuses it with `401` or `498`, and the request is retried once with the new one.
- A request that sets `X-Plex-Token` in `extraHeaders`, or that the renewer makes itself, is not renewed.
- `PlexClient.accountToken` and `setAccountToken()`, the plex.tv token apart from the server's.
- `PlexClient.connectToResource()` and `account.findConnection()` try every connection at once, and the best that answers with the resource's machine identifier wins.
- A `401` on the resource token falls back to the token `account.devices()` lists for the server (`account.serverTokenFromDevices()`).
- When no token works, the client keeps its previous server and tokens.
- `PlexResource.rankedConnections()`, `PlexServerConnection.kind`, `httpUri`, `raw` and `bracketIpv6()`, `PlexClient.connectTo()`, `connection` and `connectionKind`.
- An unbracketed IPv6 host in `PlexServerConnection.uri`, or in the URL given to `connect()`, is put in brackets.
- `streaming.startVideoTranscode()`, `PlexVideoTranscode` and `PlexStreamingApi.videoProfileExtra()`.
- `PlexErrorType.passRequired` and `PlexException.isPassRequired`, for playback refused for want of a Plex Pass or Remote Watch Pass.
- A decision, or a 4xx other than `401`, `404` and `498`, is `passRequired` when its text says so. An HTML page does not count.
- A bare `403` stays an `auth` error.
- `decisionUniversal()` returns a pass refusal as it is.
- `PlexException.body` holds the whole error answer.
- `PlexException.withType()` copies an exception with another type.
- `PlexTranscodeDecision.fromJson()`, `text` and `isPassRequired`.
- `account.homeUsers()`, `managedUsers()`, `switchHomeUser()`, `friends()`, `devices()`, `geoip()`, `watchlist()` with `PlexWatchlistFilter`, `addToWatchlist()`, `removeFromWatchlist()` and `PlexAccountApi.discoverKeyOf()`.
- `library.folder()`, for `/library/sections/{id}/folder`.
- `library.item(includeMarkers:, includeChapters:)`, `PlexMetadata.markers`, `chapters`, `markersOf()`, `images`, `squareArt`, `logo` and `editionTitle`.
- A marker of type `credit`, the API document's spelling, reads as `PlexMarkerType.credits`, the one PMS sends.
- `PlexSort.then()`, for ties.
- `PlexSort.asc` and `desc` change the direction of the last field only.
- `PlexLyrics` reads the LRC ID tags `ar`, `ti`, `al`, `au`, `by`, `length`, `offset`, `re`, `ve` and `#`.
- Any other bracketed line of the lyrics, such as `[Chorus: Jay-Z]`, is text.
- `PlexLyricCue.end` holds when a word ends.
- `raw` on `PlexChannelMapping`, `PlexMediaGrabber`, `PlexDeviceChannel`, `PlexEpgLanguage`, `PlexEpgChannel`, `PlexRelease`, `PlexSectionView` and `PlexImage`.
- `PlexEpgChannel.signalQuality` and `signalStrength`, and `PlexTunerDevice.lineupType`.
- `PlexStream.canNormalizeLoudness`, `albumRange`, `startRamp`, `endRamp`, `audioChannelLayout`, `displayTitle` and `extendedDisplayTitle`.
- `PlexFilter.atmos()`, `dolbyVision()`, `hdr()`, `videoCodec()`, `audioCodec()`, `subtitleCodec()`, `audioLayout()`, `audioLanguage()`, `subtitleLanguage()`, `inProgress()` and `duplicate()`.
- `PlexUser.restricted`, `home`, `homeAdmin`, `protected`, `subscriptionFeatures`, `title` and `raw`, and `PlexResource.raw`.
- A dependency on `cryptography` `^2.9.0`, for the Ed25519 signatures of the JWT sign-in.
- A CI workflow: analysis and tests at the SDK floor and on stable, formatting, a publish dry run, the transport drift check and, on demand, the integration suite.

**Changed**
- `PlexResource.bestConnection()` follows `rankedConnections()`: local, remote, relay; HTTPS before HTTP; IPv4 before IPv6.
- `bestConnection()` leaves out the local addresses of a server neither owned nor shared through Plex Home.
- An empty value in `extraHeaders` removes that header: `{'X-Plex-Token': ''}` sends none.
- The value of an `X-Plex-Token`, `deviceJWT` or `pin` query parameter reads `REDACTED` in `PlexException.path`, `message` and `toString()`.
- A flag reads `true`, `1`, `"1"` and `"true"` in every model.
- The pinned API document is LukeHagar/plex-api-spec@23137a920c17.
- The drift test skips when the document cannot be fetched.
- The tests read PMS 1.43.2's own answers from `test/fixtures/real/`.
- The package description lists the web.

**Fixed**
- `liveTv.dvrs()` reads the `DVR` spelling of the API document as well as the server's `Dvr`.
- A `PlexTag` from `/library/tags` has its name and filter.

## [0.2.2] - 2-11-2026

### Docs
- A shorter README, with the guide moved to topics of the API reference.

## [0.2.1] - 11-10-2026

### Changed
- The package icon is a white mark on the navy disc.

## [0.2.0] - 11-10-2026

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
- `PlexMetadata.roles`, `playlistItemId`, `playQueueItemId`, `audioStream`, `originallyAvailableAt`, `parentYear`, `leafCount`, `viewedLeafCount`, `childCount`, `skipCount`, `lastRatedAt`, `librarySectionId`, `librarySectionTitle`, `parentGuid`, `grandparentGuid`, `distance`, `score` and `ultraBlurColors`.
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
