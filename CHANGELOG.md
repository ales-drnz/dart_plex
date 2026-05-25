## [0.0.1] - 25-05-2026

### Added
- Initial scaffold targeting Plex Media Server `v1.43.x`.
- Authentication flows: legacy username/password and the official PIN link.
- PMS HTTP client with `X-Plex-*` header injection (client identifier, product, version, device, platform, token).
- Exception hierarchy with semantic error classification (`auth`, `notFound`, `serverError`, `parse`, `state`, `connection`, `timeout`, `badRequest`, `unknown`).
- Music endpoints: libraries, sections, items by type, playlists, artwork, audio streaming (universal transcode + direct), playback reporting, search, favorites.
- Play queue lifecycle with the new `PlexPlayQueue` DTO surfacing the server-assigned queue id, selected item id, shuffle/version state and initial contents.
- Notifications transport over both WebSocket (`/:/websockets/notifications`) and Server-Sent Events (`/:/eventsource/notifications`).
- Typed DTOs across the documented API surface, plus a `raw` escape hatch on every model for fields not yet promoted.
