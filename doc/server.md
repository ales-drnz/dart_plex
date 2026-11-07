Read the server's identity and settings, follow its background work and administer it.

## Identity and info

```dart
final id = await plex.server.identity();
print('${id.machineIdentifier} ${id.version} claimed=${id.claimed}');

final info = await plex.server.info();
print('${info.friendlyName} ${info.version} on ${info.platform}');
print('Plex Pass: ${info.myPlexSubscription}, '
    'sonic analysis: ${info.musicAnalysis}');

if (await plex.server.ping()) { /* reachable */ }
```

`identity()` needs no token, so it checks a server URL before you sign in
again. `info()` adds `friendlyName`, `platform`, `platformVersion`,
`myPlex`, `myPlexUsername`, `musicAnalysis`, `transcoderAudio`,
`transcoderLyrics`, `allowSync`, `countryCode` and `updatedAt`. `ping()`
returns `false` instead of throwing; call `identity()` to see why a
server is unreachable.

## Activities, butler tasks and settings

```dart
final running = await plex.activities.list(); // List<PlexActivity>
for (final a in running) {
  print('${a.title} ${a.progress ?? 0}% cancellable=${a.cancellable}');
}
final scan = running.where((a) => a.cancellable).firstOrNull;
if (scan != null) await plex.activities.cancel(activityId: scan.uuid);

final tasks = await plex.butler.tasks(); // List<PlexButlerTask>
await plex.butler.start(butlerTask: tasks.first.name);

final settings = await plex.preferences.all(); // List<PlexSetting>
final name = await plex.preferences.byId(id: 'FriendlyName');
await plex.preferences.set({'FriendlyName': 'Living room'});
print('${settings.length} settings, previous name ${name?.value}');
```

`butler.stop()`, `startAll()` and `stopAll()` control the other
maintenance tasks.

## Administration

These calls need an admin token.

| Call | Does |
| :--- | :--- |
| `server.backgroundTasks()` | Background transcode jobs (optimizing, converting for download), as `PlexTranscodeJob` |
| `server.transientToken()` | Issues a short-lived delegation token, for a cast target or a viewer link |
| `server.securityResources(source:)` | Connection info and token for a source, for cross-server playback (`PlexSecurityResource`) |
| `log.writeMessage(level:, message:, source:)` | Writes one line to the server log; `level` is 0 (error) to 4 (verbose) |
| `log.writeBlock(body:)` | Appends a multi-line body to the server log |
| `log.enablePapertrail(minutes:)` | Forwards the log to Papertrail for a while |
| `updater.status()`, `check()`, `apply()` | Server software updates (`PlexUpdaterStatus`, with its `releases`); `apply(tonight: true)` waits for the quiet hours |
| `providers.list()`, `add(url:)`, `refresh()`, `delete(provider:)` | Media providers registered on the server (`PlexMediaProvider`, with its `features`) |
