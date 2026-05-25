// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Plain immutable DTOs for the Plex API.
///
/// All models are plain Dart classes (no freezed / json_serializable) so
/// the package stays codegen-free. `fromJson` factories accept either the
/// shape returned by `plex.tv/api/v2/*` (top-level object) or the shape
/// nested inside a `MediaContainer` envelope (PMS endpoints).
library;

import 'plex_exception.dart';
import 'plex_error_type.dart';

// ---------------------------------------------------------------------------
// Type tags
// ---------------------------------------------------------------------------

/// Top-level library category (the `type` field on a `<Directory>` returned
/// from `/library/sections`).
enum PlexLibraryType {
  /// Music library (Plex wire value `artist`).
  music('artist'),

  /// Movie library.
  movie('movie'),

  /// TV show library.
  show('show'),

  /// Photo library.
  photo('photo'),

  /// Unrecognised or missing type — fallback when the wire value doesn't
  /// match any known variant.
  unknown('');

  /// Raw Plex wire string for this variant (e.g. `artist` for music).
  final String wire;
  const PlexLibraryType(this.wire);

  /// Resolves a wire string to a [PlexLibraryType], returning [unknown]
  /// when `value` is null or unrecognised.
  static PlexLibraryType fromWire(String? value) {
    switch (value) {
      case 'artist':
        return PlexLibraryType.music;
      case 'movie':
        return PlexLibraryType.movie;
      case 'show':
        return PlexLibraryType.show;
      case 'photo':
        return PlexLibraryType.photo;
      default:
        return PlexLibraryType.unknown;
    }
  }
}

/// The integer type tag used on every `/library/metadata/{id}` response.
///
/// `type=1 movie, 2 show, 3 season, 4 episode, 5 trailer, 8 artist,
///  9 album, 10 track, 13 photoAlbum, 14 photo, 15 playlist, 18 collection`.
enum PlexMetadataType {
  /// Movie (`type=1`).
  movie(1, 'movie'),

  /// TV show / series root (`type=2`).
  show(2, 'show'),

  /// Season under a show (`type=3`).
  season(3, 'season'),

  /// Episode under a season (`type=4`).
  episode(4, 'episode'),

  /// Trailer (`type=5`).
  trailer(5, 'trailer'),

  /// Music artist (`type=8`).
  artist(8, 'artist'),

  /// Music album (`type=9`).
  album(9, 'album'),

  /// Music track (`type=10`).
  track(10, 'track'),

  /// Photo album (`type=13`).
  photoAlbum(13, 'photoAlbum'),

  /// Photo (`type=14`).
  photo(14, 'photo'),

  /// Playlist (`type=15`).
  playlist(15, 'playlist'),

  /// Collection (`type=18`).
  collection(18, 'collection'),

  /// Unrecognised or missing type — fallback used when the int / wire
  /// string doesn't match any known variant.
  unknown(0, 'unknown');

  /// Numeric `type` tag as used in Plex JSON.
  final int value;

  /// Lowercase wire string Plex sometimes uses in place of the numeric
  /// [value] (e.g. `track`, `episode`).
  final String wire;
  const PlexMetadataType(this.value, this.wire);

  /// Resolves a numeric `type` tag, returning [unknown] when null or
  /// unmatched.
  static PlexMetadataType fromValue(int? value) {
    for (final t in PlexMetadataType.values) {
      if (t.value == value) return t;
    }
    return PlexMetadataType.unknown;
  }

  /// Resolves a wire string variant, returning [unknown] when null or
  /// unmatched.
  static PlexMetadataType fromWire(String? value) {
    if (value == null) return PlexMetadataType.unknown;
    for (final t in PlexMetadataType.values) {
      if (t.wire == value) return t;
    }
    return PlexMetadataType.unknown;
  }
}

// ---------------------------------------------------------------------------
// MediaContainer envelope
// ---------------------------------------------------------------------------

/// Every PMS endpoint returns a `MediaContainer` envelope wrapping the
/// payload. This helper unwraps it and validates the basic shape.
class PlexMediaContainer<T> {
  /// Total number of records, when paginated (`totalSize`).
  final int totalSize;

  /// Items returned by this page (`size`).
  final int size;

  /// Caller-typed payload — what's inside the container.
  final List<T> items;

  /// The raw envelope, accessible for fields not lifted into [items].
  final Map<String, dynamic> raw;

  /// Creates a container with already-parsed [items] and a copy of the
  /// envelope in [raw].
  const PlexMediaContainer({
    required this.totalSize,
    required this.size,
    required this.items,
    required this.raw,
  });

  /// Decode the envelope at the top of [json], extract the array named
  /// [arrayKey], and map each entry with [parser].
  ///
  /// Plex responses use different array keys depending on the endpoint:
  /// `Metadata`, `Directory`, `Hub`, `Playlist`, `Pivot`, …
  factory PlexMediaContainer.fromJson(
    Map<String, dynamic> json,
    String arrayKey,
    T Function(Map<String, dynamic>) parser,
  ) {
    final container = json['MediaContainer'];
    if (container is! Map<String, dynamic>) {
      throw const PlexException(
        'Missing MediaContainer in response',
        type: PlexErrorType.parse,
      );
    }
    final raw = container[arrayKey];
    final list = raw is List ? raw : const <Object?>[];
    return PlexMediaContainer<T>(
      totalSize: _int(container['totalSize']) ?? _int(container['size']) ?? 0,
      size: _int(container['size']) ?? list.length,
      items: [
        for (final e in list)
          if (e is Map<String, dynamic>) parser(e),
      ],
      raw: container,
    );
  }
}

// ---------------------------------------------------------------------------
// plex.tv account
// ---------------------------------------------------------------------------

/// User profile returned by `/api/v2/user` and `/users/sign_in.json`.
class PlexUser {
  /// Numeric plex.tv account id.
  final int id;

  /// Stable account UUID.
  final String uuid;

  /// Plex username (handle).
  final String username;

  /// Account email address.
  final String email;

  /// Avatar URL, when the user has set one.
  final String? thumb;

  /// X-Plex-Token used to authenticate subsequent requests as this user.
  final String authToken;

  /// Whether the account currently has an active Plex Pass subscription.
  final bool hasPlexPass;

  /// Creates a user with the given fields; [thumb] is optional.
  const PlexUser({
    required this.id,
    required this.uuid,
    required this.username,
    required this.email,
    required this.authToken,
    required this.hasPlexPass,
    this.thumb,
  });

  /// Parses either the flat `/api/v2/user` shape or the legacy
  /// `{"user": {...}}` envelope returned by `/users/sign_in.json`.
  factory PlexUser.fromJson(Map<String, dynamic> json) {
    // Legacy /users/sign_in.json wraps it in {"user": {...}}; v2 returns flat.
    final src = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    final subs = src['subscription'];
    return PlexUser(
      id: _int(src['id']) ?? 0,
      uuid: _str(src['uuid']) ?? '',
      username: _str(src['username']) ?? '',
      email: _str(src['email']) ?? '',
      thumb: _str(src['thumb']),
      authToken: _str(src['authToken']) ?? _str(src['auth_token']) ?? '',
      hasPlexPass: subs is Map &&
          (subs['active'] == true || _str(subs['status']) == 'Active'),
    );
  }
}

/// One server entry from `plex.tv/api/v2/resources`.
///
/// `connections` is the list of candidate URIs to reach the server —
/// pick the best one with [bestConnection].
class PlexResource {
  /// Friendly display name of the resource (server or player).
  final String name;

  /// Stable per-install identifier (matches `X-Plex-Client-Identifier`).
  final String clientIdentifier;

  /// Product name, e.g. `Plex Media Server` or `Plex for iOS`.
  final String product;

  /// Product version string reported by the resource.
  final String productVersion;

  /// Host platform, e.g. `Linux`, `macOS`, `iOS`.
  final String platform;

  /// Optional device descriptor (model / form factor).
  final String? device;

  /// True when the resource is owned by the authenticated account.
  final bool owned;

  /// True when shared via Plex Home.
  final bool home;

  /// True when this is a synced/cloud resource.
  final bool synced;

  /// True when only reachable via Plex Relay (no direct path).
  final bool relay;

  /// True when the resource is currently online / presencing.
  final bool presence;

  /// True when the server requires HTTPS for non-local traffic.
  final bool httpsRequired;

  /// Account-scoped access token to use when connecting to this resource.
  final String accessToken;

  /// Public (WAN) IP address last reported by the resource, if any.
  final String? publicAddress;

  /// Capabilities advertised by the resource (`server`, `player`,
  /// `controller`, …), split from Plex's comma-separated string.
  final List<String> provides;

  /// Candidate URIs to reach the resource — pass through [bestConnection]
  /// for the preferred one.
  final List<PlexServerConnection> connections;

  /// Creates a resource record; [device] and [publicAddress] are optional.
  const PlexResource({
    required this.name,
    required this.clientIdentifier,
    required this.product,
    required this.productVersion,
    required this.platform,
    required this.owned,
    required this.home,
    required this.synced,
    required this.relay,
    required this.presence,
    required this.httpsRequired,
    required this.accessToken,
    required this.provides,
    required this.connections,
    this.device,
    this.publicAddress,
  });

  /// Parses one resource entry from `plex.tv/api/v2/resources`, including
  /// its nested `connections` array.
  factory PlexResource.fromJson(Map<String, dynamic> json) {
    final conns = json['connections'];
    return PlexResource(
      name: _str(json['name']) ?? '',
      clientIdentifier: _str(json['clientIdentifier']) ?? '',
      product: _str(json['product']) ?? '',
      productVersion: _str(json['productVersion']) ?? '',
      platform: _str(json['platform']) ?? '',
      device: _str(json['device']),
      owned: json['owned'] == true,
      home: json['home'] == true,
      synced: json['synced'] == true,
      relay: json['relay'] == true,
      presence: json['presence'] == true,
      httpsRequired: json['httpsRequired'] == true,
      accessToken: _str(json['accessToken']) ?? '',
      publicAddress: _str(json['publicAddress']),
      provides: (_str(json['provides']) ?? '').split(','),
      connections: [
        if (conns is List)
          for (final c in conns)
            if (c is Map<String, dynamic>) PlexServerConnection.fromJson(c),
      ],
    );
  }

  /// Whether this resource is a Plex Media Server (vs. a player/client).
  bool get isServer => provides.contains('server');

  /// Pick the most desirable connection URI in this order:
  ///   1. local, non-relay
  ///   2. https, non-relay
  ///   3. any non-relay
  ///   4. relay (last resort)
  PlexServerConnection? bestConnection() {
    if (connections.isEmpty) return null;
    final localDirect = connections
        .where((c) => c.local && !c.relay)
        .toList(growable: false);
    if (localDirect.isNotEmpty) return localDirect.first;
    final httpsDirect = connections
        .where((c) => c.protocol == 'https' && !c.relay)
        .toList(growable: false);
    if (httpsDirect.isNotEmpty) return httpsDirect.first;
    final direct =
        connections.where((c) => !c.relay).toList(growable: false);
    if (direct.isNotEmpty) return direct.first;
    return connections.first;
  }
}

/// One candidate URI to reach a [PlexResource]. Roughly:
///   `https://192-168-0-2.{uuid}.plex.direct:32400` for local-https
///   `https://1-2-3-4.{uuid}.plex.direct:32400`     for remote-https
///   `https://relay-…plex.tv`                       for relay
class PlexServerConnection {
  /// `http` or `https`.
  final String protocol;

  /// Raw address (IP or hostname) advertised by the server.
  final String address;

  /// Listening port (typically `32400`).
  final int port;

  /// Full URI (`protocol://address:port`) ready to use.
  final String uri;

  /// True when this candidate is on the same LAN as the requesting client.
  final bool local;

  /// True when reachable only through Plex Relay.
  final bool relay;

  /// True when [address] is an IPv6 literal.
  final bool ipv6;

  /// Creates a connection candidate.
  const PlexServerConnection({
    required this.protocol,
    required this.address,
    required this.port,
    required this.uri,
    required this.local,
    required this.relay,
    required this.ipv6,
  });

  /// Parses one `<Connection>` entry from a `/api/v2/resources` payload.
  factory PlexServerConnection.fromJson(Map<String, dynamic> json) =>
      PlexServerConnection(
        protocol: _str(json['protocol']) ?? '',
        address: _str(json['address']) ?? '',
        port: _int(json['port']) ?? 0,
        uri: _str(json['uri']) ?? '',
        local: json['local'] == true,
        relay: json['relay'] == true,
        ipv6: json['IPv6'] == true || json['ipv6'] == true,
      );
}

/// PIN flow state returned by `POST /api/v2/pins` and `GET /api/v2/pins/{id}`.
///
/// The 4-character [code] is what the user types at <https://plex.tv/link>.
/// Poll [PlexAccountApi.pollPin] until [authToken] is non-null, or until
/// [expiresAt] passes.
class PlexPin {
  /// Server-assigned pin id used to poll for completion.
  final int id;

  /// 4-character code the user types at <https://plex.tv/link>.
  final String code;

  /// Client identifier the pin was created with (must match on poll).
  final String clientIdentifier;

  /// X-Plex-Token, populated once the user has linked the pin; null until
  /// then.
  final String? authToken;

  /// Pin creation timestamp (UTC).
  final DateTime createdAt;

  /// Pin expiry timestamp (UTC); after this the pin can no longer be
  /// completed.
  final DateTime expiresAt;

  /// Creates a pin state snapshot.
  const PlexPin({
    required this.id,
    required this.code,
    required this.clientIdentifier,
    required this.createdAt,
    required this.expiresAt,
    this.authToken,
  });

  /// True once the user has approved the pin and an [authToken] is present.
  bool get isAuthenticated => authToken != null && authToken!.isNotEmpty;

  /// True when [expiresAt] is in the past.
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  /// Parses the response of `POST /api/v2/pins` or `GET /api/v2/pins/{id}`.
  factory PlexPin.fromJson(Map<String, dynamic> json) => PlexPin(
        id: _int(json['id']) ?? 0,
        code: _str(json['code']) ?? '',
        clientIdentifier: _str(json['clientIdentifier']) ?? '',
        authToken: _str(json['authToken']),
        createdAt: _dt(json['createdAt']) ?? DateTime.now().toUtc(),
        expiresAt: _dt(json['expiresAt']) ?? DateTime.now().toUtc(),
      );
}

// ---------------------------------------------------------------------------
// Library sections
// ---------------------------------------------------------------------------

/// One library section from `/library/sections`.
class PlexLibrarySection {
  /// `key` field — the numeric/string id used in `/library/sections/{id}/all`.
  final String id;

  /// User-facing library name (e.g. `Movies`, `Music`).
  final String title;

  /// Coarse library kind (movies, music, …).
  final PlexLibraryType type;

  /// Metadata agent identifier (e.g. `tv.plex.agents.movie`).
  final String agent;

  /// Scanner identifier (e.g. `Plex Movie Scanner`).
  final String scanner;

  /// Preferred metadata language as a BCP-47 code.
  final String language;

  /// Stable section UUID, when present.
  final String? uuid;

  /// Last scan time (UTC), null if never scanned.
  final DateTime? scannedAt;

  /// Library creation time (UTC).
  final DateTime? createdAt;

  /// Filesystem paths backing this section.
  final List<String> locations;

  /// Full raw JSON of the section for fields not lifted above.
  final Map<String, dynamic> raw;

  /// Creates a section record.
  const PlexLibrarySection({
    required this.id,
    required this.title,
    required this.type,
    required this.agent,
    required this.scanner,
    required this.language,
    required this.locations,
    required this.raw,
    this.uuid,
    this.scannedAt,
    this.createdAt,
  });

  /// Parses one `<Directory>` entry from `/library/sections`.
  factory PlexLibrarySection.fromJson(Map<String, dynamic> json) {
    final locs = json['Location'];
    final out = <String>[];
    if (locs is List) {
      for (final l in locs) {
        if (l is Map && l['path'] is String) out.add(l['path'] as String);
      }
    }
    return PlexLibrarySection(
      id: _str(json['key']) ?? '',
      title: _str(json['title']) ?? '',
      type: PlexLibraryType.fromWire(_str(json['type'])),
      agent: _str(json['agent']) ?? '',
      scanner: _str(json['scanner']) ?? '',
      language: _str(json['language']) ?? '',
      uuid: _str(json['uuid']),
      scannedAt: _epochSec(json['scannedAt']),
      createdAt: _epochSec(json['createdAt']),
      locations: out,
      raw: json,
    );
  }
}

// ---------------------------------------------------------------------------
// Metadata items (artists, albums, tracks, movies, episodes, …)
// ---------------------------------------------------------------------------

/// A single item under `/library/metadata/{ratingKey}` (or as an entry in
/// any list response). Generic across types — the [type] tag tells you
/// which fields are meaningful.
class PlexMetadata {
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

  /// Full raw map — keep around for fields not lifted onto strongly
  /// typed properties yet.
  final Map<String, dynamic> raw;

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
  });

  /// Parses one `<Video>` / `<Track>` / `<Directory>` metadata entry. The
  /// input is the inner item map — caller is responsible for unwrapping the
  /// `MediaContainer` envelope first.
  factory PlexMetadata.fromJson(Map<String, dynamic> json) {
    return PlexMetadata(
      ratingKey: _str(json['ratingKey']) ?? '',
      key: _str(json['key']) ?? '',
      guid: _str(json['guid']),
      type: PlexMetadataType.fromWire(_str(json['type'])),
      title: _str(json['title']) ?? '',
      titleSort: _str(json['titleSort']),
      originalTitle: _str(json['originalTitle']),
      summary: _str(json['summary']),
      year: _int(json['year']),
      parentRatingKey: _str(json['parentRatingKey']),
      parentKey: _str(json['parentKey']),
      parentTitle: _str(json['parentTitle']),
      parentThumb: _str(json['parentThumb']),
      parentIndex: _int(json['parentIndex']),
      grandparentRatingKey: _str(json['grandparentRatingKey']),
      grandparentKey: _str(json['grandparentKey']),
      grandparentTitle: _str(json['grandparentTitle']),
      grandparentThumb: _str(json['grandparentThumb']),
      thumb: _str(json['thumb']),
      art: _str(json['art']),
      index: _int(json['index']),
      durationMs: _int(json['duration']),
      userRating: _double(json['userRating']),
      rating: _double(json['rating']),
      viewCount: _int(json['viewCount']),
      viewOffsetMs: _int(json['viewOffset']),
      lastViewedAt: _epochSec(json['lastViewedAt']),
      addedAt: _epochSec(json['addedAt']),
      updatedAt: _epochSec(json['updatedAt']),
      media: [
        if (json['Media'] is List)
          for (final m in json['Media'] as List)
            if (m is Map<String, dynamic>) PlexMedia.fromJson(m),
      ],
      genres: _tagList(json['Genre']),
      moods: _tagList(json['Mood']),
      styles: _tagList(json['Style']),
      raw: json,
    );
  }

  /// True when [userRating] indicates a favourite (>= 10 on Plex's 0..10
  /// scale).
  bool get isFavorite => (userRating ?? 0) >= 10;
}

/// One `<Media>` node under a [PlexMetadata]. Tracks/movies usually have
/// exactly one; some items have alternate versions and produce several.
class PlexMedia {
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
  final Map<String, dynamic> raw;

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
  factory PlexMedia.fromJson(Map<String, dynamic> json) => PlexMedia(
        id: _int(json['id']),
        durationMs: _int(json['duration']),
        bitrate: _int(json['bitrate']),
        audioChannels: _int(json['audioChannels']),
        audioCodec: _str(json['audioCodec']),
        videoCodec: _str(json['videoCodec']),
        container: _str(json['container']),
        sampleRate: _int(json['audioSampleRate']),
        bitDepth: _int(json['audioBitDepth']) ?? _int(json['bitDepth']),
        width: _int(json['width']),
        height: _int(json['height']),
        parts: [
          if (json['Part'] is List)
            for (final p in json['Part'] as List)
              if (p is Map<String, dynamic>) PlexPart.fromJson(p),
        ],
        raw: json,
      );
}

/// One `<Part>` node — a single file backing a [PlexMedia].
class PlexPart {
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
  final Map<String, dynamic> raw;

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
  factory PlexPart.fromJson(Map<String, dynamic> json) => PlexPart(
        id: _int(json['id']),
        key: _str(json['key']),
        durationMs: _int(json['duration']),
        file: _str(json['file']),
        size: _int(json['size']),
        container: _str(json['container']),
        streams: [
          if (json['Stream'] is List)
            for (final s in json['Stream'] as List)
              if (s is Map<String, dynamic>) PlexStream.fromJson(s),
        ],
        raw: json,
      );
}

/// `streamType`: 1 video, 2 audio, 3 subtitle, 4 lyrics.
class PlexStream {
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

  /// True when this stream is the currently selected one for its type.
  final bool selected;

  /// Full raw JSON for fields not lifted above.
  final Map<String, dynamic> raw;

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
  });

  /// Parses one `<Stream>` node from a [PlexPart].
  factory PlexStream.fromJson(Map<String, dynamic> json) => PlexStream(
        id: _int(json['id']),
        streamType: _int(json['streamType']),
        codec: _str(json['codec']),
        channels: _int(json['channels']),
        bitrate: _int(json['bitrate']),
        samplingRate: _int(json['samplingRate']),
        bitDepth: _int(json['bitDepth']),
        language: _str(json['language']),
        languageCode: _str(json['languageCode']),
        title: _str(json['title']),
        key: _str(json['key']),
        selected: json['selected'] == true || json['default'] == true,
        raw: json,
      );

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
// Hubs (used by /hubs and /hubs/search)
// ---------------------------------------------------------------------------

/// One `<Hub>` entry from `/hubs` or `/hubs/search` — a titled, optionally
/// paginated bucket of [PlexMetadata] items grouped by Plex.
class PlexHub {
  /// Relative URL to fetch the full contents of this hub.
  final String hubKey;

  /// Stable hub identifier (e.g. `home.continue`, `music.recent.played`).
  final String hubIdentifier;

  /// Display title of the hub.
  final String title;

  /// Optional sub-type, e.g. `clip`, `mixed`, `movie`.
  final String? type;

  /// Number of items returned in this slice.
  final int size;

  /// True when more items exist beyond what's in [items].
  final bool more;

  /// Items in this hub slice.
  final List<PlexMetadata> items;

  /// Full raw JSON for fields not lifted above.
  final Map<String, dynamic> raw;

  /// Creates a hub record; [type] is optional.
  const PlexHub({
    required this.hubKey,
    required this.hubIdentifier,
    required this.title,
    required this.size,
    required this.more,
    required this.items,
    required this.raw,
    this.type,
  });

  /// Parses one `<Hub>` entry from `/hubs` or `/hubs/search`.
  factory PlexHub.fromJson(Map<String, dynamic> json) => PlexHub(
        hubKey: _str(json['hubKey']) ?? '',
        hubIdentifier: _str(json['hubIdentifier']) ?? '',
        title: _str(json['title']) ?? '',
        type: _str(json['type']),
        size: _int(json['size']) ?? 0,
        more: json['more'] == true,
        items: [
          if (json['Metadata'] is List)
            for (final m in json['Metadata'] as List)
              if (m is Map<String, dynamic>) PlexMetadata.fromJson(m),
        ],
        raw: json,
      );
}

// ---------------------------------------------------------------------------
// Play queues (returned by /playQueues create + fetch)
// ---------------------------------------------------------------------------

/// Wraps the response of `POST /playQueues` (and friends).
///
/// Plex puts the queue identity on the MediaContainer envelope itself —
/// `playQueueID`, `playQueueSelectedItemID`, `playQueueShuffled`,
/// `playQueueVersion` — and the items in the `Metadata` array. This
/// DTO surfaces both so callers can pass [id] straight back to
/// [PlexPlayQueuesApi.items], [PlexPlayQueuesApi.addItems], …
class PlexPlayQueue {
  /// Server-assigned queue identifier. Use this with the rest of
  /// [PlexPlayQueuesApi].
  final int id;

  /// `playQueueSelectedItemID` — the per-item id (NOT a ratingKey) of
  /// the entry the server picked as "current". Useful when seeding from
  /// a multi-item URI: Plex picks one as the starting point.
  final int? selectedItemId;

  /// `playQueueShuffled` — whether the queue was created with shuffle
  /// already on.
  final bool shuffled;

  /// `playQueueVersion` — monotonically increasing version number,
  /// bumped on every queue mutation. Useful for optimistic concurrency.
  final int? version;

  /// Initial queue contents (the `Metadata` array of the response).
  final List<PlexMetadata> items;

  /// Raw MediaContainer envelope, for fields not promoted above.
  final Map<String, dynamic> raw;

  /// Creates a play queue snapshot.
  const PlexPlayQueue({
    required this.id,
    required this.shuffled,
    required this.items,
    required this.raw,
    this.selectedItemId,
    this.version,
  });

  /// Parses a `POST /playQueues` (or fetch) response, lifting the queue
  /// identity off the `MediaContainer` envelope and the items out of the
  /// nested `Metadata` array.
  factory PlexPlayQueue.fromJson(Map<String, dynamic> json) {
    final container = json['MediaContainer'];
    if (container is! Map<String, dynamic>) {
      throw const PlexException(
        'Missing MediaContainer in play queue response',
        type: PlexErrorType.parse,
      );
    }
    final metadata = container['Metadata'];
    return PlexPlayQueue(
      id: _int(container['playQueueID']) ?? 0,
      selectedItemId: _int(container['playQueueSelectedItemID']),
      shuffled: container['playQueueShuffled'] == true ||
          container['playQueueShuffled'] == 1,
      version: _int(container['playQueueVersion']),
      items: [
        if (metadata is List)
          for (final m in metadata)
            if (m is Map<String, dynamic>) PlexMetadata.fromJson(m),
      ],
      raw: container,
    );
  }
}

// ---------------------------------------------------------------------------
// Sessions (now playing on the server)
// ---------------------------------------------------------------------------

/// One entry from `/status/sessions` — a Plex metadata item enriched
/// with `User`, `Player` and (when transcoding) `TranscodeSession`
/// sub-nodes describing **who is playing** and **how**.
class PlexSession {
  /// The underlying metadata for the item being played.
  final PlexMetadata metadata;

  /// Current playback position, in milliseconds.
  final int? viewOffsetMs;

  /// `Player.title`, `Player.product`, `Player.device`, …
  final PlexSessionPlayer? player;

  /// `User.id`, `User.title`, `User.thumb` — who's streaming.
  final PlexSessionUser? user;

  /// `Session.id` — the **session identifier** (NOT the transcode
  /// session UUID). Use this with `PlexSessionsApi.terminate`.
  final String? sessionId;

  /// Bandwidth in kbps when known.
  final int? bandwidth;

  /// `TranscodeSession.key`, `videoDecision`, `audioDecision`,
  /// `protocol`, `progress`. Null on direct-play sessions.
  final Map<String, dynamic>? transcodeSession;

  /// Full raw JSON for fields not lifted above.
  final Map<String, dynamic> raw;

  /// Creates a session record.
  const PlexSession({
    required this.metadata,
    required this.raw,
    this.viewOffsetMs,
    this.player,
    this.user,
    this.sessionId,
    this.bandwidth,
    this.transcodeSession,
  });

  /// Parses one item from `/status/sessions` along with its nested
  /// `Player`, `User`, `Session` and `TranscodeSession` sub-nodes.
  factory PlexSession.fromJson(Map<String, dynamic> json) {
    final session = json['Session'];
    return PlexSession(
      metadata: PlexMetadata.fromJson(json),
      viewOffsetMs: _int(json['viewOffset']),
      player: json['Player'] is Map<String, dynamic>
          ? PlexSessionPlayer.fromJson(json['Player'] as Map<String, dynamic>)
          : null,
      user: json['User'] is Map<String, dynamic>
          ? PlexSessionUser.fromJson(json['User'] as Map<String, dynamic>)
          : null,
      sessionId: session is Map ? _str(session['id']) : null,
      bandwidth: session is Map ? _int(session['bandwidth']) : null,
      transcodeSession: json['TranscodeSession'] is Map<String, dynamic>
          ? json['TranscodeSession'] as Map<String, dynamic>
          : null,
      raw: json,
    );
  }
}

/// `Player` sub-node of a [PlexSession] — identifies the device that's
/// driving playback.
class PlexSessionPlayer {
  /// Friendly device name (`Living Room Apple TV`, …).
  final String? title;

  /// Product name (`Plex for tvOS`, …).
  final String? product;

  /// Host platform (`tvOS`, `iOS`, …).
  final String? platform;

  /// Device descriptor / form factor.
  final String? device;

  /// Playback state: `playing`, `paused`, `buffering`, `stopped`.
  final String? state; // playing | paused | buffering | stopped

  /// True when the player is on the same LAN as the server.
  final bool local;

  /// Player IP address as the server sees it.
  final String? address;

  /// Full raw JSON for fields not lifted above.
  final Map<String, dynamic> raw;

  /// Creates a player descriptor; only [raw] is required.
  const PlexSessionPlayer({
    required this.raw,
    this.title,
    this.product,
    this.platform,
    this.device,
    this.state,
    this.local = false,
    this.address,
  });

  /// Parses a `<Player>` sub-node.
  factory PlexSessionPlayer.fromJson(Map<String, dynamic> json) =>
      PlexSessionPlayer(
        title: _str(json['title']),
        product: _str(json['product']),
        platform: _str(json['platform']),
        device: _str(json['device']),
        state: _str(json['state']),
        local: json['local'] == true || json['local'] == '1',
        address: _str(json['address']),
        raw: json,
      );
}

/// `User` sub-node of a [PlexSession] — identifies the account streaming
/// the item.
class PlexSessionUser {
  /// Plex account id of the streaming user.
  final String id;

  /// Display name of the user.
  final String title;

  /// Avatar URL, when set.
  final String? thumb;

  /// Full raw JSON for fields not lifted above.
  final Map<String, dynamic> raw;

  /// Creates a session-user record.
  const PlexSessionUser({
    required this.id,
    required this.title,
    required this.raw,
    this.thumb,
  });

  /// Parses a `<User>` sub-node.
  factory PlexSessionUser.fromJson(Map<String, dynamic> json) =>
      PlexSessionUser(
        id: _str(json['id']) ?? '',
        title: _str(json['title']) ?? '',
        thumb: _str(json['thumb']),
        raw: json,
      );
}

// ---------------------------------------------------------------------------
// UltraBlur (`/services/ultrablur/colors`)
// ---------------------------------------------------------------------------

/// Four hex colours extracted from an image by the Plex server. Use
/// the same four values to ask `/services/ultrablur/image` for a
/// server-rendered gradient backdrop.
class PlexUltraBlurColors {
  /// Top-left swatch as a hex string (e.g. `#1a2b3c`).
  final String? topLeft;

  /// Top-right swatch as a hex string.
  final String? topRight;

  /// Bottom-left swatch as a hex string.
  final String? bottomLeft;

  /// Bottom-right swatch as a hex string.
  final String? bottomRight;

  /// Full raw JSON for fields not lifted above.
  final Map<String, dynamic> raw;

  /// Creates an UltraBlur colour quad; all swatches are optional.
  const PlexUltraBlurColors({
    this.topLeft,
    this.topRight,
    this.bottomLeft,
    this.bottomRight,
    this.raw = const {},
  });

  /// Parses the response of `/services/ultrablur/colors`.
  factory PlexUltraBlurColors.fromJson(Map<String, dynamic> json) =>
      PlexUltraBlurColors(
        topLeft: _str(json['topLeft']),
        topRight: _str(json['topRight']),
        bottomLeft: _str(json['bottomLeft']),
        bottomRight: _str(json['bottomRight']),
        raw: json,
      );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String? _str(Object? v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

int? _int(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _double(Object? v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

DateTime? _dt(Object? v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v)?.toUtc();
  return null;
}

DateTime? _epochSec(Object? v) {
  final s = _int(v);
  if (s == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);
}

List<String> _tagList(Object? v) {
  if (v is! List) return const [];
  final out = <String>[];
  for (final e in v) {
    if (e is Map && e['tag'] is String) out.add(e['tag'] as String);
  }
  return out;
}
