# Integration tests

This directory holds the integration test suite for `dart_plex`.
The tests exercise a real Plex Media Server running locally in
Docker, seeded with a small royalty-free media library.

The lightweight drift watchdog at
[`../spec_drift_watchdog_test.dart`](../spec_drift_watchdog_test.dart)
runs on every `dart test` and does not require Docker — it only
checks the upstream OpenAPI spec for changes. The Docker-backed
integration suite below is opt-in via the `integration` tag.

## Quick start

1. Install Docker (Desktop, OrbStack, Colima, anything that gives
   you a working `docker compose`).

2. **Create a dedicated Plex test account.** Plex Media Server
   cannot run unclaimed, so a Plex account is required to come
   online. **Do not use your real Plex account.** Sign up for a
   free, dedicated test account at <https://plex.tv/sign-up>:
   - A free account is enough; no Plex Pass needed.
   - Pick a throw-away email — a Gmail alias works
     (`yourname+plextest@gmail.com`), or a disposable forwarding
     service.
   - The account holds no personal data, no Plex Pass, no real
     library. It exists purely to claim the disposable Docker
     container.

   This is the same pattern used by every Plex SDK
   ([python-plexapi](https://python-plexapi.readthedocs.io/),
   [plex-api-spec](https://github.com/LukeHagar/plex-api-spec), …).

3. Copy `.env.test.example` to `.env.test` and fill in your test
   account credentials:

   ```
   PLEX_TEST_USERNAME=your-plex-handle   # NOT your email
   PLEX_TEST_PASSWORD=your-plex-password
   ```

   The username is the short auto-assigned handle plex.tv gives you
   on sign-up. Find yours at the top right of <https://plex.tv>
   after logging in. It is **not** the local part of your email.

   If the test account has 2FA enabled, the username/password flow
   won't work. Run
   `dart run test/integration/get_plex_token.dart` to get a token
   via the PIN flow and set `PLEX_TEST_TOKEN=…` instead.

4. Run the bootstrap. It signs in to plex.tv, requests a one-shot
   claim token, brings up the Docker stack with the claim, waits
   for plex.tv to register the server, creates a "Music" library,
   and waits for the scan to settle:

   ```sh
   dart run test/integration/bootstrap.dart
   ```

5. Run the integration tests:

   ```sh
   dart test --tags integration
   ```

6. Tear down when done:

   ```sh
   docker compose down       # keeps volumes (~30s next start)
   docker compose down -v    # wipes volumes (~5min next start)
   ```

## What's tested

The integration suite focuses on the consumer-facing surface of the
library — roughly 30-40 endpoints across:

- plex.tv account auth and server discovery (`account`)
- Library browsing (`library`, sections, items, children, leaves)
- Search (`search` — hubs, voice, legacy)
- Playback reporting and scrobble (`playback`)
- Sessions (`sessions`)
- Image transcoding URLs (`images`, `ultraBlur`)
- Play queues and playlists (`playQueues`, `playlists`)

Destructive admin endpoints (deleteSection, uninstallPlugin, …),
hardware-dependent endpoints (DVR tuner discovery, EPG lineup
fetching), and external-service-dependent endpoints (TMDB metadata
lookup) are tagged `@Tags(['destructive'])` / `@Tags(['hardware'])`
/ `@Tags(['external'])` and skipped by default.

## Why no CI?

These tests require Docker, a Plex test account, and several minutes
per cold start. They are designed to run on a contributor's machine
before opening a PR, not on every push. The spec drift watchdog is
the lightweight counterpart and runs on every `dart test`.
