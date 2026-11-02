Browse sections and items, filter them, edit collections and metadata, and find similar and sonically close tracks.

## Sections

```dart
final sections = await plex.library.sections();
for (final s in sections) {
  print('${s.type.name}: ${s.title} (id=${s.id})');
}
```

`PlexLibraryType` is `music`, `movie`, `show`, `photo` or `unknown`.
`id` is the section key that every section call takes as `sectionId`.
Each section also carries `agent`, `scanner`, `language`, `locations`,
`scannedAt` and `createdAt`.

## Items by type

```dart
final page = await plex.library.allByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
  start: 100,
  size: 100,
  sort: 'titleSort:asc',
);
print('Got ${page.items.length} of ${page.totalSize}');

final count = await plex.library.countByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
);
```

`allByType()` returns a `PlexMediaContainer` page (50 rows from `start`
by default) with `items`, `totalSize` and the envelope's other fields in
`raw`. `countByType()` sends the same request with an empty page, so the
count always matches what `allByType()` would list; it takes the same
`filters`.

`PlexMetadataType` carries the server's numeric values:

| Type | Value | Type | Value |
| :--- | :--- | :--- | :--- |
| `movie` | 1 | `album` | 9 |
| `show` | 2 | `track` | 10 |
| `season` | 3 | `photoAlbum` | 13 |
| `episode` | 4 | `photo` | 14 |
| `trailer` | 5 | `playlist` | 15 |
| `artist` | 8 | `collection` | 18 |

Sort examples: `'titleSort:asc'`, `'addedAt:desc'`,
`'lastViewedAt:desc'`, `'originallyAvailableAt:desc'`, `'random:<seed>'`.

## Filters

`filters` narrows `allByType()`, `countByType()` and the playlist list.
Each condition is a `PlexFilter`, sent as its own query parameter:

```dart
final page = await plex.library.allByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
  filters: [PlexFilter.genre(6), PlexFilter.yearAfter(2009)],
);
// GET /library/sections/3/all?type=9&genre=6&year>>=2009
```

A Plex filter is a query parameter named after the field, with the
operator in the name, so the operator comes from the constructor you
pick:

| Constructor | Sends |
| :--- | :--- |
| `PlexFilter.genre(6)` | `genre=6` |
| `PlexFilter.genre(6, exclude: true)` | `genre!=6` |
| `PlexFilter.tag('mood', [3, 7])` | `mood=3,7` (any of) |
| `PlexFilter.of(tag)` | the tag's own field and id (see Genres and other facets below) |
| `PlexFilter.year(1994)` | `year=1994` |
| `PlexFilter.yearAfter(2009)` | `year>>=2009` |
| `PlexFilter.yearBefore(2000)` | `year<<=2000` |
| `PlexFilter.ratingAbove(9)` | `userRating>>=9` |
| `PlexFilter.rated()` | `userRating>>=0` |
| `PlexFilter.unplayed()` | `unwatched=1` |
| `PlexFilter.played()` | `unwatched=0` |
| `PlexFilter.titleContains('abbey')` | `title=abbey` |
| `PlexFilter.titleIs('Abbey Road')` | `title==Abbey Road` |
| `PlexFilter.firstCharacter('A')` | `firstCharacter=A` |
| `PlexFilter.studio('A24')` | `studio=A24` |
| `PlexFilter.contentRating('PG')` | `contentRating=PG` |
| `PlexFilter.resolution('4k')` | `resolution=4k` |

Conditions in the list are ANDed; several values in one condition are
ORed. Tag fields (genre, mood, style) take the numeric tag id, never the
name. Two conditions on the same parameter throw a `PlexException` of
type `state`, since one would overwrite the other.

The server ignores a parameter it does not know and answers unfiltered,
so ask each section which fields it accepts with `filters()`, described
in the next section. For a field without a named constructor, use
`PlexFilter(field: ..., values: [...], operator: PlexFilterOperator...)`,
or `PlexFilter.number`, `PlexFilter.text` and `PlexFilter.flag`.

## Genres and other facets

```dart
final genres = await plex.library.genres(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
);
final rock = genres.firstWhere((g) => g.title == 'Rock');
final rockAlbums = await plex.library.allByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
  filters: [PlexFilter.of(rock)],
);
```

Each `PlexTag` carries the numeric `id` the server filters by and the
`field` it belongs to, so `PlexFilter.of()` builds the condition with
nothing spelled by hand. `id` is `null` when the server sent nothing
usable, and `PlexFilter.of()` then throws instead of sending a query that
would come back unfiltered.

`filters()` lists the facets a section can be filtered on, and
`filterValues()` lists the values of one:

```dart
final facets = await plex.library.filters(sectionId: musicLib.id);
for (final f in facets) {
  print('${f.title}: field=${f.field} type=${f.valueType}');
}

final moodFacet = facets.firstWhere((f) => f.field == 'mood');
final moods = await plex.library.filterValues(
  filter: moodFacet,
  type: PlexMetadataType.track,
);
final mellow = moods.firstWhere((m) => m.title == 'Mellow');
final mellowTracks = await plex.library.allByType(
  sectionId: musicLib.id,
  type: PlexMetadataType.track,
  filters: [PlexFilter.of(mellow)],
);
```

`PlexLibraryFilter.field` is the query parameter to use. A flag facet such
as `unwatched` has no values, and `filterValues()` throws a
`PlexException` of type `state` for it. `sectionSorts()` lists the sorts
a section offers.

## Single item

```dart
final item = await plex.library.item(ratingKey: '12345');
if (item != null) {
  print(item.title);
  print(item.media.first.audioCodec); // e.g. 'flac'
}
```

`item()` returns `null` when the answer holds no item; a rating key the
server does not know throws a `PlexException` whose `isNotFound` is true.
The full item is the place for `media` with its parts and streams
(`audioStream`, and the loudness and lyrics described in
[Streaming](https://pub.dev/documentation/dart_plex/latest/topics/Streaming-topic.html)),
`librarySectionId` and `leafCount`; list responses usually leave them
out.

`PlexMetadata` carries the item's titles, its parent and grandparent
(`parentTitle`, `grandparentRatingKey` and so on), `genres`, `moods`,
`styles`, `roles` (a track's performers when it has more than one),
counts (`leafCount`, `childCount`, `viewedLeafCount`, `viewCount`,
`skipCount`), dates (`addedAt`, `lastViewedAt`, `originallyAvailableAt`,
`lastRatedAt`), `userRating`, `durationMs` and `raw`.

## Children and leaves

```dart
// An album's tracks, an artist's albums, a season's episodes.
final tracks = await plex.library.children(ratingKey: album.ratingKey);

// Sorted and paged.
final newestAlbums = await plex.library.children(
  ratingKey: artist.ratingKey,
  sort: 'year:desc',
  size: 20,
);

// How many, without transferring them.
final albumCount = await plex.library.countChildren(ratingKey: artist.ratingKey);

// Every track of an artist in album order.
final artistTracks = await plex.library.grandchildren(
  ratingKey: artist.ratingKey,
  size: 100,
);

// Every leaf under an item: an artist's tracks, a show's episodes.
final leaves = await plex.library.allLeaves(ratingKey: artist.ratingKey);
```

Without `size` these calls return every row; with `size` they return one
page (see the page parameters in
[Errors and paging](https://pub.dev/documentation/dart_plex/latest/topics/Errors%20and%20paging-topic.html)).
`children()` takes the section sort syntax. `allLeaves()` has no sort:
the server ignores it and answers in library order.
`sectionAllLeaves(sectionId:)` returns every leaf of a section.

## Recently added, A-Z index and autocomplete

```dart
// Newest first, of one section or of the whole server.
final newInMusic = await plex.library.recentlyAdded(
  sectionId: musicLib.id,
  size: 20,
);
final newAnywhere = await plex.library.recentlyAdded(size: 20);

// The letters a section's titles start with, for an A-Z scrubber.
final letters = await plex.library.firstCharacters(
  sectionId: musicLib.id,
  type: '${PlexMetadataType.album.value}',
);

// Suggestions while the user types.
final suggestions = await plex.library.autocomplete(
  sectionId: musicLib.id,
  type: PlexMetadataType.album,
  fieldQuery: {'title.query': 'Abb'},
);
```

In a music section `recentlyAdded()` returns albums: the server ignores a
type there, so the call takes none. Jump to a letter of the index with
`PlexFilter.firstCharacter('A')` on `allByType()`. `autocomplete()` needs
`type`: the server answers 400 without it. It returns the server's map.

## Albums, folders and categories

```dart
final albums = await plex.library.albums(sectionId: musicLib.id, size: 100);
final folders = await plex.library.folderLocations(sectionId: musicLib.id);
final categories = await plex.library.categories(sectionId: photoLib.id);
```

`albums()` pages a music section's albums without the sort and filter
parameters of `allByType()`. `folderLocations()` returns the section's
scanned folders and `categories()` the server's categories, mostly for
photo libraries. `sectionArts()`, `sectionClusters()` and
`sectionMoments()` return a section's backdrops and its photo clusters
and moments, `sectionCollections()` its collections and `all()` every
item of every section.

## Collections

A collection is a metadata item with its own rating key, so `item()` and
`children()` work on it. `plex.collections` creates and edits them:

```dart
final machineId = (await plex.server.identity()).machineIdentifier;
final seed = PlexPlayQueuesApi.seedFromItems(
  machineIdentifier: machineId,
  ratingKeys: const ['12345', '12346'],
);

final collection = await plex.collections.create(
  sectionId: musicLib.id,
  title: 'Road trip',
  type: '${PlexMetadataType.album.value}',
  seedUri: seed,
);
final items = await plex.collections.items(collectionId: collection.ratingKey);

await plex.collections.moveItem(
  collectionId: collection.ratingKey,
  itemId: items.last.ratingKey,
  afterItemId: '0', // to the start
);
await plex.collections.removeItem(
  collectionId: collection.ratingKey,
  itemId: items.first.ratingKey,
);
```

`addItems(collectionId:, uri:)` adds more items from a seed URI. A smart
collection (`smart: true`) needs a `seedUri`. `compositeImageUrl()` builds
the URL of the collection's composite cover, and
`library.deleteSectionCollection()` deletes one.

## Editing and maintenance

`plex.library` also edits metadata and runs library maintenance. These
calls need an admin token. Most take `ids`, one rating key or several
joined by commas.

```dart
await plex.library.editItem(
  ids: album.ratingKey,
  type: PlexMetadataType.album,
  args: {'title.value': 'New title', 'title.locked': 1},
);
await plex.library.refreshSection(sectionId: musicLib.id);
```

`<field>.value` sets a field and `<field>.locked` keeps the agent from
overwriting it. `updateSectionItems()` edits every item matching a
`filterExpression` in one call.

The editing and maintenance calls:

| Area | Calls |
| :--- | :--- |
| Items | `editItem`, `deleteMetadataItem`, `deleteMediaItem`, `refreshItems`, `analyzeItem`, `matchItem`, `listMatches`, `unmatch`, `mergeItems`, `splitItem`, `setItemPreferences` |
| Detection | `detectIntros`, `detectCredits`, `detectAds`, `detectVoiceActivity`, `generateChapterThumbs`, `startBifGeneration` |
| Markers | `createMarker`, `editMarker`, `deleteMarker` |
| Artwork and extras | `itemArtworkUrl`, `setItemArtwork`, `extras`, `addExtra`, `addSubtitles`, `chapterImageUrl`, `itemFileUrl` |
| Item reads | `relatedItems`, `itemTree`, `topUsers`, `person`, `personMedia` |
| Streams and parts | `streamUrl`, `setStreamOffset`, `deleteStream`, `streamLoudness`, `streamLevels`, `setPartStreamSelection`, `partFileUrl`, `partIndex`, `partBifThumbUrl` |
| Sections | `addSection`, `editSection`, `deleteSection`, `sectionDetails`, `sectionPreferences`, `setSectionPreferences`, `defaultSectionPrefs`, `sectionCommon`, `sectionsAll`, `sectionCompositeImageUrl` |
| Scanning | `refreshSection`, `cancelSectionRefresh`, `analyzeSection`, `refreshAllSections`, `stopAllRefreshes`, `emptyTrash` |
| Housekeeping | `deleteSectionIndexes`, `deleteSectionIntros`, `deleteCaches`, `cleanBundles`, `optimizeDatabase`, `ingestTransientItem` |
| Index reads | `tags`, `randomArtwork`, `matches` |

## Similar items and sonic radio

`similar()` returns what the server judges similar. The other two calls
read the sonic analysis the server keeps for music, so they need it
enabled (`PlexServerInfo.musicAnalysis`).

### Similar items

```dart
final picks = await plex.library.similar(ratingKey: album.ratingKey, count: 12);
```

Works for albums, artists, movies and shows.

### Sonically nearest tracks

```dart
final nearest = await plex.library.nearestToTrack(
  ratingKey: track.ratingKey,
  limit: 25,
  maxDistance: 0.25,
  excludeGrandparentRatingKey: track.grandparentRatingKey,
);
```

`excludeParentRatingKey` and `excludeGrandparentRatingKey` leave out the
album or the artist of the seed. Each result carries its `distance` from
the seed; smaller is closer.

### Nearest tracks in a section

```dart
// A track analysed by the server carries its sonic vector in raw.
final seed = (track.raw['musicAnalysis']! as List).cast<num>();
final radio = await plex.library.nearestInSection(
  sectionId: musicLib.id,
  values: seed,
  limit: 50,
);

// Tracks that bridge two songs.
final path = await plex.library.sonicPath(
  sectionId: musicLib.id,
  startId: track.ratingKey,
  endId: otherTrack.ratingKey,
);
```

`nearestInSection()` seeds the search from a sonic vector instead of a
track. Average the vectors of several tracks to build a radio for a
mood. `sonicPath()` returns tracks that lead from one song to another.
