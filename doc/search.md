Search the whole server, one section, or with a spoken phrase.

## Hub search

```dart
final hubs = await plex.search.hubs(
  query: 'pink floyd',
  sectionId: musicLib.id, // optional: one library only
);

for (final hub in hubs) {
  print('${hub.title} (${hub.type})');
  for (final hit in hub.items) {
    print('  - ${hit.title} (score ${hit.score})');
  }
}
```

`hubs()` returns one `PlexHub` per kind of result (artists, albums,
tracks), at most `limit` (10) in each. It suits search as you type. To
drop the request of the previous keystroke, see the cancel tokens in
[Errors and paging](https://pub.dev/documentation/dart_plex/latest/topics/Errors%20and%20paging-topic.html).

## Section search

```dart
final tracks = await plex.search.section(
  sectionId: musicLib.id,
  query: 'money',
  type: PlexMetadataType.track,
  limit: 20,
);
```

One section and one kind of item, as a flat list: the shape for a
"tracks matching" view. `type` is required: the server answers 400
without it.

## Flat and voice search

```dart
final results = await plex.search.flat(query: 'pink floyd', limit: 50);

final spoken = await plex.search.voice(
  query: 'play something by pink floyd',
  type: PlexMetadataType.track,
);
```

`flat()` returns every kind of item in one list. `voice()` reads the
query as a spoken phrase and returns hubs like `hubs()`; the server
matches it slowly, so scope it with `type`.
