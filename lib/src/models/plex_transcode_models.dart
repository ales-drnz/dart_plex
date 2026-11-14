// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// What a transcode decision says and the transcodes it starts.
library;

import '../api/plex_streaming_api.dart';
import '../plex_json.dart';
import '../plex_vocabulary.dart';

/// Outcome of [PlexStreamingApi.decisionUniversal].
///
/// Plex returns `generalDecisionCode` inside `MediaContainer`. Per the
/// spec it is the *overall* decision and follows the convention
/// "1xxx = playback can succeed, 2xxx = a general error (such as
/// insufficient bandwidth), 3xxx = errors in direct play, 4xxx = errors
/// in transcodes" — so a successful transcode lives in the 1xxx range,
/// not 2xxx. The 1xxx code alone does not say *how* playback succeeds;
/// that is read from the sibling `directPlayDecisionCode` /
/// `transcodeDecisionCode` fields (same 1xxx-means-success convention),
/// which [PlexStreamingApi.decisionUniversal] preserves in [raw].
///
/// {@category Streaming}
final class PlexTranscodeDecision {
  /// The numeric `generalDecisionCode` from the response. Null when
  /// the response shape was unexpected.
  final int? code;

  /// The raw `MediaContainer` for fields not promoted here.
  final Map<String, Object?> raw;

  /// Wraps a transcode decision response with its numeric [code] and [raw] container.
  const PlexTranscodeDecision({required this.code, required this.raw});

  /// Reads a decision: a `MediaContainer`, or a `DecisionResult`.
  factory PlexTranscodeDecision.fromJson(Map<String, Object?> json) =>
      PlexTranscodeDecision(
        code: asInt(json['generalDecisionCode']),
        raw: json,
      );

  /// `true` when the decision call returned a success code (1xxx).
  /// `false` (and so unplayable) for 2xxx/3xxx/4xxx error bands.
  bool get isPlayable => code != null && code! >= 1000 && code! < 2000;

  /// `true` when Plex agreed to direct-play / direct-stream, i.e.
  /// playback succeeds and `directPlayDecisionCode` is in the 1xxx band.
  bool get isDirect {
    if (!isPlayable) return false;
    final dp = _subCode('directPlayDecisionCode');
    return dp != null && dp >= 1000 && dp < 2000;
  }

  /// `true` when Plex requires a transcoded session, i.e. playback
  /// succeeds, `transcodeDecisionCode` is in the 1xxx band, and it is
  /// not a direct-play decision.
  bool get isTranscode {
    if (!isPlayable || isDirect) return false;
    final tc = _subCode('transcodeDecisionCode');
    return tc != null && tc >= 1000 && tc < 2000;
  }

  int? _subCode(String key) => asInt(raw[key]);

  /// The general, transcode and direct-play texts, those present.
  Iterable<String> get _texts => [
    raw['generalDecisionText'],
    raw['transcodeDecisionText'],
    raw['directPlayDecisionText'],
  ].whereType<String>().where((t) => t.isNotEmpty);

  /// The decision's own words: `generalDecisionText`, else the transcode
  /// or direct-play text.
  String? get text => _texts.firstOrNull;

  /// Whether the decision refuses playback and its texts say a Plex Pass
  /// or Remote Watch Pass is required (a heuristic: see
  /// [PlexStreamingApi]).
  bool get isPassRequired =>
      !isPlayable && PlexStreamingApi.mentionsPass(_texts.join(' '));
}

/// A started video transcode: the server's [decision] and the [url] to
/// play (see [PlexStreamingApi.startVideoTranscode]).
///
/// {@category Streaming}
final class PlexVideoTranscode {
  /// What the server decided for the session.
  final PlexTranscodeDecision decision;

  /// The `start` URL to hand to the player. Valid while [session] lives.
  final String url;

  /// The session id, for `pingUniversal` / `stopUniversal`.
  final String session;

  /// The protocol the URL speaks.
  final PlexStreamingProtocol protocol;

  /// Wraps a started transcode.
  const PlexVideoTranscode({
    required this.decision,
    required this.url,
    required this.session,
    required this.protocol,
  });
}

/// A started audio transcode: the server's [decision] and the [url] to
/// play (see [PlexStreamingApi.startAudioTranscode]).
///
/// {@category Streaming}
final class PlexAudioTranscode {
  /// What the server decided for the session.
  final PlexTranscodeDecision decision;

  /// The `start` URL to hand to the player. Valid while [session] lives.
  final String url;

  /// The session id, for `pingUniversal` / `stopUniversal`.
  final String session;

  /// Wraps a started transcode.
  const PlexAudioTranscode({
    required this.decision,
    required this.url,
    required this.session,
  });
}
