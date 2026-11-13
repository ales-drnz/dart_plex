// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of '../plex_models.dart';

// ---------------------------------------------------------------------------
// Metadata items (artists, albums, tracks, movies, episodes, …)
// ---------------------------------------------------------------------------

/// A single item under `/library/metadata/{ratingKey}` (or as an entry in
/// any list response). Generic across types — the [type] tag tells you
/// which fields are meaningful.
///
/// {@category Library}
final class PlexMetadata {
  /// `ratingKey` — the numeric id used in every `/library/metadata/...`
  /// path. Always present.
  final String ratingKey;

  /// `key` — the relative path to the item's metadata (e.g.
  /// `/library/metadata/12345/children`). Differs from [ratingKey] for
  /// some endpoint shapes.
  final String key;

  /// Globally unique Plex `guid` (e.g. `plex://album/...`).
  final String? guid;

  /// Item kind — determines which fields below are meaningful.
  final PlexMetadataType type;

  /// Display title.
  final String title;

  /// Optional sort title used by Plex when ordering alphabetically.
  final String? titleSort;

  /// Original-language title when localised differently from [title].
  final String? originalTitle;

  /// Long-form description / synopsis.
  final String? summary;

  /// Release year (4-digit), when known.
  final int? year;

  /// Parent (album for tracks, artist for albums, season for episodes).
  /// `ratingKey` of the parent item.
  final String? parentRatingKey;

  /// Relative `/library/metadata/...` path of the parent.
  final String? parentKey;

  /// Display title of the parent.
  final String? parentTitle;

  /// Parent thumbnail path, relative to the server root.
  final String? parentThumb;

  /// Parent index (e.g. season number for episodes, disc number for
  /// tracks).
  final int? parentIndex;

  /// Grandparent (artist for tracks, show for episodes).
  final String? grandparentRatingKey;

  /// Relative `/library/metadata/...` path of the grandparent.
  final String? grandparentKey;

  /// Display title of the grandparent.
  final String? grandparentTitle;

  /// Grandparent thumbnail path.
  final String? grandparentThumb;

  /// Thumbnail path, relative to the server root.
  final String? thumb;

  /// Art / backdrop path, relative to the server root.
  final String? art;

  /// Track / episode index within its parent.
  final int? index;

  /// Duration, in milliseconds (Plex uses ms, not 100ns ticks).
  final int? durationMs;

  /// User rating, 0..10 (used for favorites — `userRating == 10` means
  /// "favourite" in the music UI).
  final double? userRating;

  /// Aggregated audience/critic rating, 0..10.
  final double? rating;

  /// Number of times the user has played this item to completion.
  final int? viewCount;

  /// Resume position from the last partial playback, in milliseconds.
  final int? viewOffsetMs;

  /// Timestamp of the most recent playback (UTC).
  final DateTime? lastViewedAt;

  /// Timestamp when the item was added to the library (UTC).
  final DateTime? addedAt;

  /// Timestamp of the last metadata update (UTC).
  final DateTime? updatedAt;

  /// Audio/video container/codec metadata. Empty for items where Plex
  /// hasn't surfaced any `<Media>` nodes (e.g. artist roots).
  final List<PlexMedia> media;

  /// Genres, tags, moods, …
  final List<String> genres;

  /// Mood tags (typically music-only).
  final List<String> moods;

  /// Style tags (typically music-only).
  final List<String> styles;

  /// The `Role` tags: performers, one name per entry, in the server's
  /// order. On a track these are its artists when there is more than one
  /// (a featured artist, a collaboration); empty when the server sent
  /// none, which is the usual case for a single-artist track.
  final List<String> roles;

  /// Release date (`originallyAvailableAt`, a calendar date), when known.
  final DateTime? originallyAvailableAt;

  /// The parent's year — a track's album year (`parentYear`).
  final int? parentYear;

  /// Number of leaves under the item (`leafCount`): an album's tracks.
  /// On PMS 1.43.2 it comes with the item details and
  /// `PlexLibraryApi.recentlyAdded`, not with section listings or
  /// `/children`.
  final int? leafCount;

  /// How many of those leaves were played (`viewedLeafCount`).
  final int? viewedLeafCount;

  /// Number of children (`childCount`): an artist's albums, when the
  /// response carries it. On PMS 1.43.2 search hubs do; section listings
  /// and the artist's own details do not — use
  /// `PlexLibraryApi.countChildren` there.
  final int? childCount;

  /// How many times the item was skipped (`skipCount`).
  final int? skipCount;

  /// When the user last rated the item (`lastRatedAt`).
  final DateTime? lastRatedAt;

  /// The library section the item belongs to (`librarySectionID`); in
  /// item details, not in section listings.
  final String? librarySectionId;

  /// That section's title (`librarySectionTitle`).
  final String? librarySectionTitle;

  /// The parent's `guid`.
  final String? parentGuid;

  /// The grandparent's `guid`.
  final String? grandparentGuid;

  /// Sonic distance from the seed, on items from
  /// `PlexLibraryApi.nearestToTrack` (`distance`; smaller is closer).
  final double? distance;

  /// Search relevance, on items from search (`score`).
  final double? score;

  /// Corner colours for an UltraBlur background, when the item details
  /// carry them (`UltraBlurColors`).
  final PlexUltraBlurColors? ultraBlurColors;

  /// The entry id inside a regular playlist (`playlistItemID`), present
  /// only on items read from `/playlists/{id}/items`.
  ///
  /// It names one *entry*, not the track: pass it to
  /// `PlexPlaylistsApi.removeItem` / `PlexPlaylistsApi.moveItem`. Kept as
  /// a `String` like [ratingKey] and the ids those methods take.
  final String? playlistItemId;

  /// The edition of a movie or show (`editionTitle`): "Director's Cut",
  /// "Extended"…; `null` for the plain one.
  final String? editionTitle;

  /// Intro, credits and commercial markers (`Marker`). Only in item
  /// details asked with `includeMarkers` (`PlexLibraryApi.item`).
  final List<PlexMarker> markers;

  /// Chapters (`Chapter`). Only in item details asked with
  /// `includeChapters` (`PlexLibraryApi.item`).
  final List<PlexChapter> chapters;

  /// The artwork list (`Image`): poster, background, square background,
  /// logo, … — see [squareArt] and [logo].
  final List<PlexImage> images;

  /// The entry id inside a server play queue (`playQueueItemID`), present
  /// only on items read from `PlexPlayQueuesApi`: what
  /// `PlexPlaybackApi.timeline(playQueueItemID:)` and the play queue's
  /// move and remove calls take.
  final int? playQueueItemId;

  /// Full raw map — keep around for fields not lifted onto strongly
  /// typed properties yet.
  final Map<String, Object?> raw;

  /// Creates a metadata item; only [ratingKey], [key], [type], [title],
  /// [media], [genres], [moods], [styles] and [raw] are required.
  const PlexMetadata({
    required this.ratingKey,
    required this.key,
    required this.type,
    required this.title,
    required this.media,
    required this.genres,
    required this.moods,
    required this.styles,
    required this.raw,
    this.guid,
    this.titleSort,
    this.originalTitle,
    this.summary,
    this.year,
    this.parentRatingKey,
    this.parentKey,
    this.parentTitle,
    this.parentThumb,
    this.parentIndex,
    this.grandparentRatingKey,
    this.grandparentKey,
    this.grandparentTitle,
    this.grandparentThumb,
    this.thumb,
    this.art,
    this.index,
    this.durationMs,
    this.userRating,
    this.rating,
    this.viewCount,
    this.viewOffsetMs,
    this.lastViewedAt,
    this.addedAt,
    this.updatedAt,
    this.playlistItemId,
    this.playQueueItemId,
    this.originallyAvailableAt,
    this.parentYear,
    this.leafCount,
    this.viewedLeafCount,
    this.childCount,
    this.skipCount,
    this.lastRatedAt,
    this.librarySectionId,
    this.librarySectionTitle,
    this.parentGuid,
    this.grandparentGuid,
    this.distance,
    this.score,
    this.ultraBlurColors,
    this.roles = const [],
    this.editionTitle,
    this.markers = const [],
    this.chapters = const [],
    this.images = const [],
  });

  /// Parses one `<Video>` / `<Track>` / `<Directory>` metadata entry. The
  /// input is the inner item map — caller is responsible for unwrapping the
  /// `MediaContainer` envelope first.
  factory PlexMetadata.fromJson(Map<String, Object?> json) {
    return PlexMetadata(
      ratingKey: asString(json['ratingKey']) ?? '',
      key: asString(json['key']) ?? '',
      guid: asString(json['guid']),
      type: PlexMetadataType.fromWire(asString(json['type'])),
      title: asString(json['title']) ?? '',
      titleSort: asString(json['titleSort']),
      originalTitle: asString(json['originalTitle']),
      summary: asString(json['summary']),
      year: asInt(json['year']),
      parentRatingKey: asString(json['parentRatingKey']),
      parentKey: asString(json['parentKey']),
      parentTitle: asString(json['parentTitle']),
      parentThumb: asString(json['parentThumb']),
      parentIndex: asInt(json['parentIndex']),
      grandparentRatingKey: asString(json['grandparentRatingKey']),
      grandparentKey: asString(json['grandparentKey']),
      grandparentTitle: asString(json['grandparentTitle']),
      grandparentThumb: asString(json['grandparentThumb']),
      thumb: asString(json['thumb']),
      art: asString(json['art']),
      index: asInt(json['index']),
      durationMs: asInt(json['duration']),
      userRating: asDouble(json['userRating']),
      rating: asDouble(json['rating']),
      viewCount: asInt(json['viewCount']),
      viewOffsetMs: asInt(json['viewOffset']),
      lastViewedAt: asEpochSeconds(json['lastViewedAt']),
      addedAt: asEpochSeconds(json['addedAt']),
      updatedAt: asEpochSeconds(json['updatedAt']),
      media: asObjectList(json['Media'], PlexMedia.fromJson),
      genres: tagNames(json['Genre']),
      moods: tagNames(json['Mood']),
      styles: tagNames(json['Style']),
      roles: tagNames(json['Role']),
      playlistItemId: asString(json['playlistItemID']),
      playQueueItemId: asInt(json['playQueueItemID']),
      originallyAvailableAt: asCalendarDate(json['originallyAvailableAt']),
      parentYear: asInt(json['parentYear']),
      leafCount: asInt(json['leafCount']),
      viewedLeafCount: asInt(json['viewedLeafCount']),
      childCount: asInt(json['childCount']),
      skipCount: asInt(json['skipCount']),
      lastRatedAt: asEpochSeconds(json['lastRatedAt']),
      librarySectionId: asString(json['librarySectionID']),
      librarySectionTitle: asString(json['librarySectionTitle']),
      parentGuid: asString(json['parentGuid']),
      grandparentGuid: asString(json['grandparentGuid']),
      distance: asDouble(json['distance']),
      score: asDouble(json['score']),
      ultraBlurColors: json['UltraBlurColors'] is Map<String, Object?>
          ? PlexUltraBlurColors.fromJson(
              json['UltraBlurColors'] as Map<String, Object?>,
            )
          : null,
      editionTitle: asString(json['editionTitle']),
      markers: asObjectList(json['Marker'], PlexMarker.fromJson),
      chapters: asObjectList(json['Chapter'], PlexChapter.fromJson),
      images: asObjectList(json['Image'], PlexImage.fromJson),
      raw: json,
    );
  }

  /// The square background (`backgroundSquare` in [images]), a 1:1 art
  /// for grids and widgets; `null` when the item has none.
  String? get squareArt => _image('backgroundSquare');

  /// The logo (`clearLogo` in [images]): the title as a transparent
  /// image, for overlays.
  String? get logo => _image('clearLogo');

  String? _image(String type) =>
      images.where((i) => i.type == type).firstOrNull?.url;

  /// The [markers] of [type].
  List<PlexMarker> markersOf(PlexMarkerType type) => [
    for (final m in markers)
      if (m.type == type) m,
  ];

  /// Version of [thumb] — the timestamp PMS appends to it
  /// (`/library/metadata/123/thumb/1791659974`), or `null` when there is
  /// no thumb.
  ///
  /// It changes whenever the artwork does (verified on PMS 1.43.2: each
  /// new poster upload gets a new one), so put it in an artwork cache key
  /// and a cover replaced on the server is fetched again. A track without
  /// art of its own carries its album's thumb, version included.
  String? get thumbVersion => PlexArtwork.versionOf(thumb);

  /// Version of [art] (the backdrop); see [thumbVersion].
  String? get artVersion => PlexArtwork.versionOf(art);

  /// Version of [parentThumb] (a track's album cover); see [thumbVersion].
  String? get parentThumbVersion => PlexArtwork.versionOf(parentThumb);

  /// Version of [grandparentThumb] (a track's artist image); see
  /// [thumbVersion].
  String? get grandparentThumbVersion =>
      PlexArtwork.versionOf(grandparentThumb);

  /// The first selected audio stream of the first media part, or the first
  /// audio stream when none is flagged. Streams (and so [PlexStream.gain]
  /// and the other loudness fields) are in the full item from
  /// `PlexLibraryApi.item`; list responses usually leave them out.
  PlexStream? get audioStream {
    for (final m in media) {
      for (final part in m.parts) {
        final audio = part.streams.where((s) => s.isAudio);
        if (audio.isEmpty) continue;
        return audio.firstWhere((s) => s.selected, orElse: () => audio.first);
      }
    }
    return null;
  }

  /// True when [userRating] indicates a favourite (>= 10 on Plex's 0..10
  /// scale).
  bool get isFavorite => (userRating ?? 0) >= 10;
}

/// A span of a video the server marked (`Marker`): an intro or credits to
/// skip, a commercial break.
///
/// {@category Library}
final class PlexMarker {
  /// Marker id.
  final int? id;

  /// What it marks.
  final PlexMarkerType type;

  /// Where it starts (`startTimeOffset`).
  final Duration start;

  /// Where it ends (`endTimeOffset`).
  final Duration end;

  /// For credits: whether these are the final credits (`final`), after
  /// which nothing of the item remains.
  final bool isFinal;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a marker.
  const PlexMarker({
    required this.type,
    required this.start,
    required this.end,
    this.id,
    this.isFinal = false,
    this.raw = const {},
  });

  /// Parses one `Marker`.
  factory PlexMarker.fromJson(Map<String, Object?> json) => PlexMarker(
    id: asInt(json['id']),
    type: switch (asString(json['type'])) {
      'credit' => PlexMarkerType.credits,
      final t => PlexMarkerType(t ?? ''),
    },
    start: Duration(milliseconds: asInt(json['startTimeOffset']) ?? 0),
    end: Duration(milliseconds: asInt(json['endTimeOffset']) ?? 0),
    isFinal: asBool(json['final']),
    raw: json,
  );
}

/// A chapter of a video (`Chapter`).
///
/// {@category Library}
final class PlexChapter {
  /// Chapter id.
  final int? id;

  /// Position among the chapters (`index`).
  final int? index;

  /// Name (`tag`).
  final String? title;

  /// Where it starts (`startTimeOffset`).
  final Duration start;

  /// Where it ends (`endTimeOffset`).
  final Duration end;

  /// Thumbnail path.
  final String? thumb;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds a chapter.
  const PlexChapter({
    required this.start,
    required this.end,
    this.id,
    this.index,
    this.title,
    this.thumb,
    this.raw = const {},
  });

  /// Parses one `Chapter`.
  factory PlexChapter.fromJson(Map<String, Object?> json) => PlexChapter(
    id: asInt(json['id']),
    index: asInt(json['index']),
    title: asString(json['tag']) ?? asString(json['title']),
    start: Duration(milliseconds: asInt(json['startTimeOffset']) ?? 0),
    end: Duration(milliseconds: asInt(json['endTimeOffset']) ?? 0),
    thumb: asString(json['thumb']),
    raw: json,
  );
}

/// One entry of [PlexMetadata.images].
///
/// {@category Images and hubs}
final class PlexImage {
  /// What the image is for: `coverPoster`, `background`,
  /// `backgroundSquare`, `banner`, `clearLogo`, `snapshot`.
  final String type;

  /// Its path on the server, or an absolute URL.
  final String url;

  /// Text for accessibility (`alt`).
  final String? alt;

  /// The entry as received.
  final Map<String, Object?> raw;

  /// Builds an image entry.
  const PlexImage({
    required this.type,
    required this.url,
    this.alt,
    this.raw = const {},
  });

  /// Parses one `Image`.
  factory PlexImage.fromJson(Map<String, Object?> json) => PlexImage(
    type: asString(json['type']) ?? '',
    url: asString(json['url']) ?? '',
    alt: asString(json['alt']),
    raw: json,
  );
}

/// One `<Media>` node under a [PlexMetadata]. Tracks/movies usually have
/// exactly one; some items have alternate versions and produce several.
///
/// {@category Library}
final class PlexMedia {
  /// Per-server media id.
  final int? id;

  /// Total runtime of this media variant, in milliseconds.
  final int? durationMs;

  /// Overall bitrate in kbps.
  final int? bitrate;

  /// Number of audio channels (2, 6, …).
  final int? audioChannels;

  /// Audio codec short name (e.g. `flac`, `aac`).
  final String? audioCodec;

  /// Video codec short name (e.g. `h264`, `hevc`).
  final String? videoCodec;

  /// File container short name (e.g. `mp4`, `mkv`, `flac`).
  final String? container;

  /// Audio sample rate in Hz.
  final int? sampleRate;

  /// Audio bit depth in bits per sample (16, 24, …).
  final int? bitDepth;

  /// Pixel width for video media.
  final int? width;

  /// Pixel height for video media.
  final int? height;

  /// Backing file parts — usually exactly one.
  final List<PlexPart> parts;

  /// Full raw JSON for fields not lifted above.
  final Map<String, Object?> raw;

  /// Creates a media variant; only [parts] and [raw] are required.
  const PlexMedia({
    required this.parts,
    required this.raw,
    this.id,
    this.durationMs,
    this.bitrate,
    this.audioChannels,
    this.audioCodec,
    this.videoCodec,
    this.container,
    this.sampleRate,
    this.bitDepth,
    this.width,
    this.height,
  });

  /// Parses one `<Media>` node from a [PlexMetadata] entry.
  factory PlexMedia.fromJson(Map<String, Object?> json) => PlexMedia(
    id: asInt(json['id']),
    durationMs: asInt(json['duration']),
    bitrate: asInt(json['bitrate']),
    audioChannels: asInt(json['audioChannels']),
    audioCodec: asString(json['audioCodec']),
    videoCodec: asString(json['videoCodec']),
    container: asString(json['container']),
    sampleRate: asInt(json['audioSampleRate']),
    bitDepth: asInt(json['audioBitDepth']) ?? asInt(json['bitDepth']),
    width: asInt(json['width']),
    height: asInt(json['height']),
    parts: asObjectList(json['Part'], PlexPart.fromJson),
    raw: json,
  );
}

/// One `<Part>` node — a single file backing a [PlexMedia].
///
/// {@category Library}
final class PlexPart {
  /// Per-server part id.
  final int? id;

  /// Relative streaming key, e.g. `/library/parts/123/.../file.flac`.
  final String? key;

  /// Part runtime in milliseconds.
  final int? durationMs;

  /// Absolute filesystem path as Plex sees it.
  final String? file;

  /// File size in bytes.
  final int? size;

  /// File container short name.
  final String? container;

  /// Audio/video/subtitle/lyrics streams inside this part.
  final List<PlexStream> streams;

  /// Full raw JSON for fields not lifted above.
  final Map<String, Object?> raw;

  /// Creates a part record; only [streams] and [raw] are required.
  const PlexPart({
    required this.streams,
    required this.raw,
    this.id,
    this.key,
    this.durationMs,
    this.file,
    this.size,
    this.container,
  });

  /// Parses one `<Part>` node from a [PlexMedia].
  factory PlexPart.fromJson(Map<String, Object?> json) => PlexPart(
    id: asInt(json['id']),
    key: asString(json['key']),
    durationMs: asInt(json['duration']),
    file: asString(json['file']),
    size: asInt(json['size']),
    container: asString(json['container']),
    streams: asObjectList(json['Stream'], PlexStream.fromJson),
    raw: json,
  );
}

/// `streamType`: 1 video, 2 audio, 3 subtitle, 4 lyrics.
///
/// {@category Library}
final class PlexStream {
  /// Per-server stream id.
  final int? id;

  /// `streamType`: `1` video, `2` audio, `3` subtitle, `4` lyrics.
  final int? streamType;

  /// Codec short name (e.g. `flac`, `aac`, `h264`).
  final String? codec;

  /// Audio channel count (audio streams only).
  final int? channels;

  /// Stream bitrate in kbps.
  final int? bitrate;

  /// Audio sampling rate in Hz.
  final int? samplingRate;

  /// Audio bit depth in bits per sample.
  final int? bitDepth;

  /// Language display name as Plex reports it.
  final String? language;

  /// ISO language code (e.g. `eng`, `ita`).
  final String? languageCode;

  /// Optional stream title (e.g. subtitle track name).
  final String? title;

  /// Relative path used to download the stream (subtitles, lyrics, …).
  final String? key;

  /// True when this stream is the currently selected one for its type
  /// (Plex's `selected` flag; applicable mainly to audio streams).
  final bool selected;

  /// True when this stream is the file default (Plex's `default` flag).
  /// Distinct from [selected]: a stream can be the file default without
  /// being the one currently selected for playback.
  final bool isDefault;

  /// Track gain in dB (`gain`) — what to apply for track-level
  /// normalisation. Present on analysed audio streams.
  ///
  /// These loudness fields come from the server's own analysis of the
  /// file, so they survive a transcode that drops the file's ReplayGain
  /// tags: read them from the original stream and apply the gain to the
  /// transcoded audio.
  final double? gain;

  /// Album gain in dB (`albumGain`), for album-level normalisation.
  final double? albumGain;

  /// Track peak amplitude, linear (`peak`; 1.0 is full scale).
  final double? peak;

  /// Album peak amplitude, linear (`albumPeak`).
  final double? albumPeak;

  /// Integrated loudness in LUFS (`loudness`).
  final double? loudness;

  /// Loudness range in LU (`lra`).
  final double? lra;

  /// Album loudness range (`albumRange`).
  final double? albumRange;

  /// Loudness of the track's start, for gapless crossfades (`startRamp`,
  /// the server's encoded ramp).
  final String? startRamp;

  /// Loudness of the track's end (`endRamp`).
  final String? endRamp;

  /// Whether the server can normalise this stream's loudness
  /// (`canNormalizeLoudness`).
  final bool canNormalizeLoudness;

  /// Channel layout of an audio stream (`audioChannelLayout`), e.g.
  /// `5.1(side)`, `stereo` — what [PlexFilter.audioLayout] filters on.
  final String? audioChannelLayout;

  /// The server's label for the stream (`displayTitle`), e.g. `English
  /// (AAC Stereo)`.
  final String? displayTitle;

  /// The longer label (`extendedDisplayTitle`).
  final String? extendedDisplayTitle;

  /// Full raw JSON for fields not lifted above.
  final Map<String, Object?> raw;

  /// Creates a stream record; only [raw] is required.
  const PlexStream({
    required this.raw,
    this.id,
    this.streamType,
    this.codec,
    this.channels,
    this.bitrate,
    this.samplingRate,
    this.bitDepth,
    this.language,
    this.languageCode,
    this.title,
    this.key,
    this.selected = false,
    this.isDefault = false,
    this.gain,
    this.albumGain,
    this.peak,
    this.albumPeak,
    this.loudness,
    this.lra,
    this.albumRange,
    this.startRamp,
    this.endRamp,
    this.canNormalizeLoudness = false,
    this.audioChannelLayout,
    this.displayTitle,
    this.extendedDisplayTitle,
  });

  /// Parses one `<Stream>` node from a [PlexPart].
  factory PlexStream.fromJson(Map<String, Object?> json) => PlexStream(
    id: asInt(json['id']),
    streamType: asInt(json['streamType']),
    codec: asString(json['codec']),
    channels: asInt(json['channels']),
    bitrate: asInt(json['bitrate']),
    samplingRate: asInt(json['samplingRate']),
    bitDepth: asInt(json['bitDepth']),
    language: asString(json['language']),
    languageCode: asString(json['languageCode']),
    title: asString(json['title']),
    key: asString(json['key']),
    selected: asBool(json['selected']),
    isDefault: asBool(json['default']),
    gain: asDouble(json['gain']),
    albumGain: asDouble(json['albumGain']),
    peak: asDouble(json['peak']),
    albumPeak: asDouble(json['albumPeak']),
    loudness: asDouble(json['loudness']),
    lra: asDouble(json['lra']),
    albumRange: asDouble(json['albumRange']),
    startRamp: asString(json['startRamp']),
    endRamp: asString(json['endRamp']),
    canNormalizeLoudness: asBool(json['canNormalizeLoudness']),
    audioChannelLayout: asString(json['audioChannelLayout']),
    displayTitle: asString(json['displayTitle']),
    extendedDisplayTitle: asString(json['extendedDisplayTitle']),
    raw: json,
  );

  /// True when [gain] or [albumGain] is known — the stream has been
  /// through the server's loudness analysis.
  bool get hasLoudness => gain != null || albumGain != null;

  /// True when this is an audio stream (`streamType == 2`).
  bool get isAudio => streamType == 2;

  /// True when this is a video stream (`streamType == 1`).
  bool get isVideo => streamType == 1;

  /// True when this is a subtitle stream (`streamType == 3`).
  bool get isSubtitle => streamType == 3;

  /// True when this is a lyrics stream (`streamType == 4`).
  bool get isLyrics => streamType == 4;
}

// ---------------------------------------------------------------------------
// Artwork
// ---------------------------------------------------------------------------

/// Helpers for PMS artwork paths.
///
/// {@category Images and hubs}
abstract final class PlexArtwork {
  /// The version PMS appends to an artwork path —
  /// `/library/metadata/123/thumb/1791659974` → `'1791659974'` — or
  /// `null` when [path] is null or carries none.
  ///
  /// The version is a Unix timestamp that changes with the image, so it
  /// belongs in any cache key for that image. Paths that are not
  /// `…/thumb/{n}`, `…/art/{n}`, `…/banner/{n}` or `…/theme/{n}` (an
  /// absolute URL from an agent, a `composite` path) give `null`.
  static String? versionOf(String? path) {
    if (path == null) return null;
    final uri = Uri.tryParse(path);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    if (segments.length < 2) return null;
    final kind = segments[segments.length - 2];
    final version = segments.last;
    const kinds = {'thumb', 'art', 'banner', 'theme', 'clearLogo'};
    if (!kinds.contains(kind)) return null;
    if (version.isEmpty || int.tryParse(version) == null) return null;
    return version;
  }
}
