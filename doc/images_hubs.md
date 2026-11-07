Resize and cache artwork, render UltraBlur backdrops, and read the hubs of the home screen, a section or an item.

## Images

### Resized artwork

```dart
final url = plex.images.transcodeUrl(
  sourcePath: item.thumb!, // e.g. '/library/metadata/123/thumb/1700000000'
  width: 300,
  height: 300,
);

final bytes = await plex.images.fetch(sourcePath: item.thumb!); // Uint8List?
```

Besides `thumb` and `art`, an item lists its artwork in `images`
(`PlexImage`: `type` and `url`); `squareArt` is the 1:1 background
(`backgroundSquare`) and `logo` the title logo (`clearLogo`), when the
server has them. Any of these paths goes to `transcodeUrl()`.

The server resizes the image (500 × 500 by default) and sends a JPEG.
`fetch()` returns `null` on 404 and throws a `PlexException` on other
failures, so "no artwork" and "try again later" stay apart. For blur,
format and the other transcoder options see the transcoder URLs in
[Streaming](https://pub.dev/documentation/dart_plex/latest/topics/Streaming-topic.html).

### Artwork versions and cache keys

```dart
final cacheKey = '${album.ratingKey}@${album.thumbVersion}';
final version = PlexArtwork.versionOf('/library/metadata/123/thumb/1791659974');
// '1791659974'
```

An artwork path ends in a timestamp that changes whenever the image
does. Put it in your cache key and a cover replaced on the server is
fetched again. `thumbVersion`, `artVersion`, `parentThumbVersion` and
`grandparentThumbVersion` read it off a `PlexMetadata`; a track without
art of its own carries its album's thumb and version.

### UltraBlur backdrops

The server extracts four corner colours from an image and renders them
as a smooth gradient, for a backdrop behind a player screen:

```dart
final palettes = await plex.ultraBlur.colors(sourceUrl: album.thumb!);
final palette = palettes.first;

final url = plex.ultraBlur.imageUrl(
  topLeft: palette.topLeft,
  topRight: palette.topRight,
  bottomLeft: palette.bottomLeft,
  bottomRight: palette.bottomRight,
  width: 1920,
  height: 1080,
  noise: 1,
);
final png = await plex.ultraBlur.fetchImage(
  topLeft: palette.topLeft,
  topRight: palette.topRight,
  bottomLeft: palette.bottomLeft,
  bottomRight: palette.bottomRight,
  width: 1280,
  height: 720,
);
```

`sourceUrl` takes a library path or an absolute URL. The item details
may already carry the palette, as `PlexMetadata.ultraBlurColors`.
`noise: 1` adds dither against banding, for a backdrop behind text.
`fetchImage()` returns the PNG bytes, to cache yourself.

## Hubs

Hubs are the rows of Plex's home screen: Recently Added, Continue
Listening, More from an artist. Each `PlexHub` is a titled row of items.

### Home and section hubs

```dart
final home = await plex.hubs.global(count: 8);
final musicHubs = await plex.hubs.forSection(sectionId: musicLib.id);

for (final hub in musicHubs) {
  print('${hub.title}: ${hub.items.length} items, more: ${hub.more}');
}
```

Each hub carries up to `count` items (16 by default) and `more` when it
has others behind a "Show all". `onlyTransient: true` keeps the hubs that
change with playback and additions.

### Promoted and on deck

```dart
final promoted = await plex.hubs.promoted();
final onDeck = await plex.hubs.continueWatching();
final musicOnDeck = await plex.hubs.sectionOnDeck(sectionId: musicLib.id);
```

`continueWatching()` and `sectionOnDeck()` return a `List<PlexMetadata>`,
not hubs.

### Drilling into a hub

```dart
final all = await plex.hubs.drill(
  hubKeyOrIdentifier: hub.hubKey, // or hub.hubIdentifier
  size: 100,
);
```

`drill()` pages the whole content of a hub with `more`.
`itemsByIdentifier(identifier:)` does the same from an identifier such as
`library.recentlyAdded.3`.

### Hubs of an item

```dart
final aroundAlbum = await plex.hubs.forMetadata(metadataId: album.ratingKey);
final related = await plex.hubs.related(metadataId: album.ratingKey);
final afterPlay = await plex.hubs.postplay(metadataId: track.ratingKey);
```

`forMetadata()` returns the discovery rows of an item, such as "More by
this artist", for music. `related()` returns related rows and
`postplay()` the suggestions to show when an item ends.

### Managing a section's hubs

With an admin token, `manage(sectionId:)` lists a section's hubs with
their promotion flags. `createCustom()`, `updateVisibility()`,
`deleteCustom()` and `move()` change them, and `resetSection()` restores
the defaults:

```dart
final configured = await plex.hubs.manage(sectionId: musicLib.id);
await plex.hubs.updateVisibility(
  sectionId: musicLib.id,
  identifier: configured.first.hubIdentifier,
  promotedToOwnHome: true,
);
```
