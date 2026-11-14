// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// An item's media: versions, parts and streams.
library;

import '../parsing/plex_json.dart';
import '../plex_filter.dart';
import 'plex_metadata_models.dart';

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
