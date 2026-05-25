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
  music('artist'),
  movie('movie'),
  show('show'),
  photo('photo'),
  unknown('');

  final String wire;
  const PlexLibraryType(this.wire);

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
  movie(1, 'movie'),
  show(2, 'show'),
  season(3, 'season'),
  episode(4, 'episode'),
  trailer(5, 'trailer'),
  artist(8, 'artist'),
  album(9, 'album'),
  track(10, 'track'),
  photoAlbum(13, 'photoAlbum'),
  photo(14, 'photo'),
  playlist(15, 'playlist'),
  collection(18, 'collection'),
  unknown(0, 'unknown');

  final int value;
  final String wire;
  const PlexMetadataType(this.value, this.wire);

  static PlexMetadataType fromValue(int? value) {
    for (final t in PlexMetadataType.values) {
      if (t.value == value) return t;
    }
    return PlexMetadataType.unknown;
  }

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
  final int id;
  final String uuid;
  final String username;
  final String email;
  final String? thumb;
  final String authToken;
  final bool hasPlexPass;

  const PlexUser({
    required this.id,
    required this.uuid,
    required this.username,
    required this.email,
    required this.authToken,
    required this.hasPlexPass,
    this.thumb,
  });

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
  final String name;
  final String clientIdentifier;
  final String product;
  final String productVersion;
  final String platform;
  final String? device;
  final bool owned;
  final bool home;
  final bool synced;
  final bool relay;
  final bool presence;
  final bool httpsRequired;
  final String accessToken;
  final String? publicAddress;
  final List<String> provides;
  final List<PlexServerConnection> connections;

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
  final String protocol;
  final String address;
  final int port;
  final String uri;
  final bool local;
  final bool relay;
  final bool ipv6;

  const PlexServerConnection({
    required this.protocol,
    required this.address,
    required this.port,
    required this.uri,
    required this.local,
    required this.relay,
    required this.ipv6,
  });

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
  final int id;
  final String code;
  final String clientIdentifier;
  final String? authToken;
  final DateTime createdAt;
  final DateTime expiresAt;

  const PlexPin({
    required this.id,
    required this.code,
    required this.clientIdentifier,
    required this.createdAt,
    required this.expiresAt,
    this.authToken,
  });

  bool get isAuthenticated => authToken != null && authToken!.isNotEmpty;
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

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
  final String title;
  final PlexLibraryType type;
  final String agent;
  final String scanner;
  final String language;
  final String? uuid;
  final DateTime? scannedAt;
  final DateTime? createdAt;
  final List<String> locations;
  final Map<String, dynamic> raw;

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

  final String? guid;
  final PlexMetadataType type;
  final String title;
  final String? titleSort;
  final String? originalTitle;
  final String? summary;
  final int? year;

  /// Parent (album for tracks, artist for albums, season for episodes).
  final String? parentRatingKey;
  final String? parentKey;
  final String? parentTitle;
  final String? parentThumb;
  final int? parentIndex;

  /// Grandparent (artist for tracks, show for episodes).
  final String? grandparentRatingKey;
  final String? grandparentKey;
  final String? grandparentTitle;
  final String? grandparentThumb;

  final String? thumb;
  final String? art;

  /// Track / episode index within its parent.
  final int? index;

  /// Duration, in milliseconds (Plex uses ms, not 100ns ticks).
  final int? durationMs;

  /// User rating, 0..10 (used for favorites — `userRating == 10` means
  /// "favourite" in the music UI).
  final double? userRating;
  final double? rating;
  final int? viewCount;
  final int? viewOffsetMs;
  final DateTime? lastViewedAt;
  final DateTime? addedAt;
  final DateTime? updatedAt;

  /// Audio/video container/codec metadata. Empty for items where Plex
  /// hasn't surfaced any `<Media>` nodes (e.g. artist roots).
  final List<PlexMedia> media;

  /// Genres, tags, moods, …
  final List<String> genres;
  final List<String> moods;
  final List<String> styles;

  /// Full raw map — keep around for fields not lifted onto strongly
  /// typed properties yet.
  final Map<String, dynamic> raw;

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

  bool get isFavorite => (userRating ?? 0) >= 10;
}

/// One `<Media>` node under a [PlexMetadata]. Tracks/movies usually have
/// exactly one; some items have alternate versions and produce several.
class PlexMedia {
  final int? id;
  final int? durationMs;
  final int? bitrate;
  final int? audioChannels;
  final String? audioCodec;
  final String? videoCodec;
  final String? container;
  final int? sampleRate;
  final int? bitDepth;
  final int? width;
  final int? height;
  final List<PlexPart> parts;
  final Map<String, dynamic> raw;

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
  final int? id;
  final String? key;
  final int? durationMs;
  final String? file;
  final int? size;
  final String? container;
  final List<PlexStream> streams;
  final Map<String, dynamic> raw;

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
  final int? id;
  final int? streamType;
  final String? codec;
  final int? channels;
  final int? bitrate;
  final int? samplingRate;
  final int? bitDepth;
  final String? language;
  final String? languageCode;
  final String? title;
  final String? key;
  final bool selected;
  final Map<String, dynamic> raw;

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

  bool get isAudio => streamType == 2;
  bool get isVideo => streamType == 1;
  bool get isSubtitle => streamType == 3;
  bool get isLyrics => streamType == 4;
}

// ---------------------------------------------------------------------------
// Hubs (used by /hubs and /hubs/search)
// ---------------------------------------------------------------------------

class PlexHub {
  final String hubKey;
  final String hubIdentifier;
  final String title;
  final String? type;
  final int size;
  final bool more;
  final List<PlexMetadata> items;
  final Map<String, dynamic> raw;

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

  const PlexPlayQueue({
    required this.id,
    required this.shuffled,
    required this.items,
    required this.raw,
    this.selectedItemId,
    this.version,
  });

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

  final Map<String, dynamic> raw;

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

class PlexSessionPlayer {
  final String? title;
  final String? product;
  final String? platform;
  final String? device;
  final String? state; // playing | paused | buffering | stopped
  final bool local;
  final String? address;
  final Map<String, dynamic> raw;

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

class PlexSessionUser {
  final String id;
  final String title;
  final String? thumb;
  final Map<String, dynamic> raw;

  const PlexSessionUser({
    required this.id,
    required this.title,
    required this.raw,
    this.thumb,
  });

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
  final String? topLeft;
  final String? topRight;
  final String? bottomLeft;
  final String? bottomRight;
  final Map<String, dynamic> raw;

  const PlexUltraBlurColors({
    this.topLeft,
    this.topRight,
    this.bottomLeft,
    this.bottomRight,
    this.raw = const {},
  });

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
