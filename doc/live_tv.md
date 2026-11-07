Follow live sessions, configure DVRs and tuners, manage recording rules and read the program guide.

Live TV streams broadcast channels through a tuner; the DVR records
programs to disk. The answers are typed (`PlexDvr`, `PlexTunerDevice`,
`PlexMediaSubscription`, `PlexLineup`, …), each with its entry in `raw`.
Their shapes follow the API document: the test server has no tuner, so
beyond the grabber list and the guide languages they could not be checked
against a live answer.

## Live sessions

```dart
final liveSessions = await plex.liveTv.sessions(); // PlexMetadata
for (final item in liveSessions) {
  print('${item.title} (${item.raw['channelCallSign']})');
}
```

`liveSession(sessionId:)` reads one session. `sessionPlaylistUrl()` and
`sessionSegmentUrl()` build the HLS URLs of a consumer of the session.
Past Live TV plays are in the playback history (see
[Playback and play queues](https://pub.dev/documentation/dart_plex/latest/topics/Playback%20and%20play%20queues-topic.html)).

## DVRs

```dart
final dvrs = await plex.liveTv.dvrs();
final channels = await plex.liveTv.dvrChannels(dvrKey: dvrs.first.key);

await plex.dvrs.reloadGuide(dvrId: dvrId);
await plex.dvrs.tuneChannel(dvrId: dvrId, channel: '2.1');
```

A `PlexDvr` has its `key`, `uuid`, `lineup` and `devices`.
`dvrChannels()` takes the `key`.
`plex.dvrs` takes the DVR's id and configures one DVR: `get()`, `delete()` (recordings stay on
disk), `setPreferences()`, `addLineup()` and `deleteLineup()`,
`reloadGuide()` and `stopReloadGuide()`, `tuneChannel()`, `addDevice()`
and `removeDevice()`.

## Recording subscriptions

```dart
final subs = await plex.subscriptions.list(includeGrabs: true);
for (final sub in subs) {
  print('${sub.title} - ${sub.airingsType}, ${sub.grabs.length} recordings');
}

await plex.subscriptions.delete(
  subscriptionId: subs.first.key!.split('/').last,
);
```

A subscription is a recording rule. `create()` adds one for a library
section, starting from the `template(guid:)` of a program (the
subscriptions the server proposes for it). `get()`,
`editPreferences()`, `reorder()` (the order settles conflicts) and
`delete()` manage one; recordings already on disk stay.
`scheduledRecordings()` lists what the DVR will record, `processAll()`
applies the rules to a new guide, and `cancelGrab(operationId:)` stops a
recording in progress.

## Tuners and the program guide

`plex.devices` manages the tuners (grabbers): `grabbers()`, `list()`,
`discover()`, `add(uri:)`, `details()`, `remove()`, `setEnabled()`,
`channels()`, `setChannelMap()`, `setPreferences()`, `startScan()`,
`stopScan()` and `thumbUrl()`.

`plex.epg` reads the program guide's lineups: `countries()`,
`languages()`, `countryLineups()`, `countryRegions()`,
`regionLineups()`, `bestLineup()`, `channelMap()`, `channels()` and
`lineupChannels()`.

```dart
await plex.devices.discover();
final tuners = await plex.devices.list();
final countries = await plex.epg.countries();
```
