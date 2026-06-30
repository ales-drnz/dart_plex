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
