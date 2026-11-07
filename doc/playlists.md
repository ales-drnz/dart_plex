List, create and edit playlists, read smart playlists and import playlist files.

## Listing and counting

```dart
final audio = await plex.playlists.list(type: PlexMediaType.audio, size: 100);

// Narrowed by the server: title contains "mix", and rated.
final mixes = await plex.playlists.list(
  type: PlexMediaType.audio,
  filters: [PlexFilter.titleContains('mix'), PlexFilter.rated()],
  sort: PlexSort.titleSort,
);
final count = await plex.playlists.count(
  type: PlexMediaType.audio,
  filters: [PlexFilter.titleContains('mix')],
);
```

`type` is `PlexMediaType.audio`, `video` or `photo`, and `smart` keeps only smart
(`true`) or regular (`false`) playlists. `filters` and `sort` work as on
`allByType()` (see the filters in
[Library](https://pub.dev/documentation/dart_plex/latest/topics/Library-topic.html));
the title filter matches without regard to case. `list()` returns 50
playlists from `start` by default. Each entry is a `PlexMetadata` of type
`playlist`.

## Creating a playlist

```dart
final machineId = (await plex.server.identity()).machineIdentifier;

final playlist = await plex.playlists.create(
  title: 'My Mix',
  type: PlexMediaType.audio,
  machineIdentifier: machineId,
  itemRatingKeys: const ['12345', '12346', '12347'],
);
```

The server's `machineIdentifier` builds the URI of the items. Leave
`itemRatingKeys` out to create an empty playlist.

## Adding, removing and moving items

```dart
await plex.playlists.addItems(
  playlistId: playlist.ratingKey,
  machineIdentifier: machineId,
  itemRatingKeys: const ['99999'],
);

final entries = await plex.playlists.items(playlistId: playlist.ratingKey);

// Remove one entry.
final added = entries.firstWhere((e) => e.ratingKey == '99999');
await plex.playlists.removeItem(
  playlistId: playlist.ratingKey,
  playlistItemId: added.playlistItemId!,
);

// Move the last entry to the start (no afterPlaylistItemId).
await plex.playlists.moveItem(
  playlistId: playlist.ratingKey,
  playlistItemId: entries.last.playlistItemId!,
);
```

`removeItem()` and `moveItem()` take the entry id,
`PlexMetadata.playlistItemId`, not the track's rating key, so a track
listed twice loses or moves only the entry you name. Items read with
`items()` carry it. Pass `size` (and `start`) to `items()` to read one
page of a long playlist.

## Renaming and deleting

```dart
await plex.playlists.rename(playlistId: playlist.ratingKey, title: 'New name');
await plex.playlists.delete(playlistId: playlist.ratingKey);
```

## Smart playlists and import

```dart
final generators = await plex.playlists.generators(playlistId: smart.ratingKey);
final generatorId = '${generators.first.id}';
final produced = await plex.playlists.generatorItems(
  playlistId: smart.ratingKey,
  generatorId: generatorId,
);

// Import .m3u files from a path on the server.
final imported = await plex.playlists.upload(path: '/srv/music/playlists');
```

`generators()` returns the `PlexPlayQueueGenerator`s that feed a smart
playlist: `id`, `uri` (the query), `createdAt`, `updatedAt`. `reprocessGenerator()` runs one again with the action
`'reprocess'`, `'disable'` or `'enable'`. `upload()` turns each `.m3u`
file at `path` into a playlist; with `force: false` an existing playlist
from the same path is kept and the import gets a new, dated name.
