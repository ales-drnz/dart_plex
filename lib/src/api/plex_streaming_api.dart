// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:meta/meta.dart';

import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_credentials.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';
import '../plex_json.dart';
import '../plex_models.dart';
import '../plex_urls.dart';
import '../plex_vocabulary.dart';
import '../transport/plex_response.dart';

/// Transcode decisions and streaming URLs.
///
/// [startAudioTranscode] and [startVideoTranscode] ask the server for a
/// decision and build the URL to play; [directFileUrl] is the file as it
/// is. The URLs carry the X-Plex-Token as a query parameter so a player
/// (mpv, AVPlayer, ExoPlayer, …) and its segment requests need no custom
/// headers: do not log them. Building one before [PlexClient.connect]
/// throws a `state` [PlexException].
///
/// ## The remote-streaming pass
///
/// Since April 2025 Plex requires a Plex Pass (on the server owner's
/// account) or a Remote Watch Pass (on the viewer's) to stream personal
/// video to a device outside the server's network. A refusal for that
/// reason is thrown as [PlexErrorType.passRequired], with the server's
/// whole answer in [PlexException.body]. PMS documents no code for it, so
/// the decision calls recognise it heuristically, from:
///
/// * the text of a 4xx error answer other than `401`, `404` and `498`
///   (an HTML page does not count), or of a decision's
///   `generalDecisionText` / `transcodeDecisionText` /
///   `directPlayDecisionText`, naming "Plex Pass", "Remote Watch", or
///   remote playback as requiring a subscription or not allowed.
///
/// A bare `403` stays an auth error, whatever the connection: it is also
/// what a server answers to a token it does not accept.
///
/// A false negative stays the error it was (an auth or bad-request error,
/// or an unplayable [PlexTranscodeDecision]); check
/// [PlexClient.connectionKind] and [PlexException.body] when in doubt.
/// Music is not covered by the requirement.
///
/// {@category Streaming}
class PlexStreamingApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.streaming].
  PlexStreamingApi(this._http);

  /// Starts a server-side audio transcode the way PMS accepts it, and
  /// returns the URL to play.
  ///
  /// One request: `/music/:/transcode/universal/decision` for [session],
  /// then the `start` URL is built with the very same parameters. What PMS
  /// 1.43.2 was measured to require, and this method does:
  ///
  /// * **a decision first** — a client that has never asked for a
  ///   decision gets 400 ("session lacking decision") on `start`. The
  ///   requirement is per client, not per session (a client that decided
  ///   once could start new sessions without one), but asking every time
  ///   is what makes the URL match the decision returned here;
  /// * **a client profile** — the base profile is picked from
  ///   `X-Plex-Platform`, and there is none for `Linux` or `macOS` (400,
  ///   "Unable to find client profile"); [clientProfileName] (`Generic`
  ///   by default) names one explicitly, so any platform works;
  /// * **a transcode target** in `X-Plex-Client-Profile-Extra`
  ///   (`add-transcode-target(type=musicProfile&…&audioCodec=…)`);
  /// * **the bitrate cap as a profile limitation** — [maxAudioBitrateKbps]
  ///   becomes `add-limitation(…name=audio.bitrate…)`: 96 gave a 96 kbps
  ///   stream. A plain `maxAudioBitrate` query parameter has no effect.
  ///   The cap cannot go above the profile's own ceiling (256 kbps AAC for
  ///   `Generic`).
  ///
  /// The URL carries the token and the client identity in its query, since
  /// the player opens it without this client's headers: do not log it.
  /// [protocol] is
  /// [PlexStreamingProtocol.hls] (an `.m3u8`, default) or
  /// [PlexStreamingProtocol.dash] (an `.mpd`). HTTP is not offered for
  /// music: [PlexStreamingProtocol.http] throws an [ArgumentError]. Keep
  /// [session] for [pingUniversal] and [stopUniversal].
  ///
  /// Check [PlexAudioTranscode.decision]: when it is not playable the URL
  /// will not work either.
  ///
  /// Stop sessions you no longer play ([stopUniversal]): PMS ties one
  /// client's transcodes together, and in the integration suite a new
  /// session's bitrate cap was not applied while other transcodes of the
  /// same client were still open.
  Future<PlexAudioTranscode> startAudioTranscode({
    required String ratingKey,
    required String session,
    PlexStreamingProtocol protocol = PlexStreamingProtocol.hls,
    String audioCodec = 'aac',
    int? maxAudioBitrateKbps,
    int offsetSeconds = 0,
    int mediaIndex = 0,
    int partIndex = 0,
    String? clientProfileName = 'Generic',
  }) async {
    _http.requireConnected();
    final container = switch (protocol) {
      PlexStreamingProtocol.hls => 'mpegts',
      PlexStreamingProtocol.dash => 'mp4',
      PlexStreamingProtocol.http => throw ArgumentError.value(
        protocol,
        'protocol',
        'hls or dash',
      ),
    };
    final creds = _http.credentials;
    final qp = <String, String>{
      'path': '/library/metadata/$ratingKey',
      'mediaIndex': '$mediaIndex',
      'partIndex': '$partIndex',
      'protocol': protocol.wire,
      'directPlay': '0',
      'directStream': '0',
      'fastSeek': '1',
      'offset': '$offsetSeconds',
      'session': session,
      'X-Plex-Client-Identifier': creds.clientIdentifier,
      'X-Plex-Product': creds.product,
      'X-Plex-Version': creds.version,
      'X-Plex-Platform': creds.platform,
      'X-Plex-Device': creds.device,
      'X-Plex-Device-Name': creds.deviceName,
      'X-Plex-Client-Profile-Name': ?clientProfileName,
      'X-Plex-Client-Profile-Extra': musicProfileExtra(
        protocol: protocol.wire,
        container: container,
        audioCodec: audioCodec,
        maxAudioBitrateKbps: maxAudioBitrateKbps,
      ),
    };
    final decision = await decisionUniversal(
      params: qp,
      transcodeType: 'music',
    );
    _throwIfPassRequired(decision);
    final url = _http.signedUrl(
      '/music/:/transcode/universal/start.${protocol.extension}',
      qp,
    );
    return PlexAudioTranscode(decision: decision, url: url, session: session);
  }

  /// Starts a server-side video transcode the way PMS accepts it, and
  /// returns the URL to play — the video counterpart of
  /// [startAudioTranscode].
  ///
  /// One request: `/video/:/transcode/universal/decision` for [session],
  /// then the `start` URL with the same parameters. As for music, PMS
  /// 1.43.2 answers "no conversion profile found" (decision code 4005)
  /// unless the client profile names a target, so the request carries
  /// `X-Plex-Client-Profile-Name` ([clientProfileName], `Generic` by
  /// default) and a `videoProfile` transcode target for [protocol] in
  /// `X-Plex-Client-Profile-Extra` ([videoProfileExtra]). Verified on PMS
  /// 1.43.2 for all three protocols: HLS (`start.m3u8`), DASH (`start.mpd`)
  /// and HTTP (`start.mkv`, one Matroska stream).
  ///
  /// [maxVideoBitrateKbps] and [videoResolution] (`'1280x720'`) cap the
  /// output; [directStream] lets the server copy streams it need not
  /// re-encode. Check [PlexVideoTranscode.decision]: when it is not
  /// playable the URL will not work either.
  ///
  /// Throws a [PlexException] of type [PlexErrorType.passRequired] when
  /// the server refuses remote playback for want of a Plex Pass or Remote
  /// Watch Pass (see the class documentation for how that is recognised),
  /// and one of type `state` before [PlexClient.connect]. The URL carries
  /// the token: do not log it.
  Future<PlexVideoTranscode> startVideoTranscode({
    required String ratingKey,
    required String session,
    PlexStreamingProtocol protocol = PlexStreamingProtocol.hls,
    String videoCodec = 'h264',
    String audioCodec = 'aac',
    int? maxVideoBitrateKbps,
    String? videoResolution,
    bool directStream = true,
    int offsetSeconds = 0,
    int mediaIndex = 0,
    int partIndex = 0,
    String? clientProfileName = 'Generic',
  }) async {
    _http.requireConnected();
    final creds = _http.credentials;
    final qp = <String, String>{
      'path': '/library/metadata/$ratingKey',
      'mediaIndex': '$mediaIndex',
      'partIndex': '$partIndex',
      'protocol': protocol.wire,
      'directPlay': '0',
      'directStream': directStream ? '1' : '0',
      'fastSeek': '1',
      'offset': '$offsetSeconds',
      'session': session,
      'maxVideoBitrate': ?maxVideoBitrateKbps?.toString(),
      'videoResolution': ?videoResolution,
      'X-Plex-Client-Identifier': creds.clientIdentifier,
      'X-Plex-Product': creds.product,
      'X-Plex-Version': creds.version,
      'X-Plex-Platform': creds.platform,
      'X-Plex-Device': creds.device,
      'X-Plex-Device-Name': creds.deviceName,
      'X-Plex-Client-Profile-Name': ?clientProfileName,
      'X-Plex-Client-Profile-Extra': videoProfileExtra(
        protocol: protocol,
        videoCodec: videoCodec,
        audioCodec: audioCodec,
      ),
    };
    final decision = await decisionUniversal(params: qp);
    _throwIfPassRequired(decision);
    final url = _http.signedUrl(
      '/video/:/transcode/universal/start.${protocol.extension}',
      qp,
    );
    return PlexVideoTranscode(
      decision: decision,
      url: url,
      session: session,
      protocol: protocol,
    );
  }

  /// The `X-Plex-Client-Profile-Extra` value that asks for a video
  /// transcode to [videoCodec] / [audioCodec] over [protocol], in the
  /// protocol's container (see [startVideoTranscode]).
  static String videoProfileExtra({
    required PlexStreamingProtocol protocol,
    String videoCodec = 'h264',
    String audioCodec = 'aac',
  }) =>
      'add-transcode-target(type=videoProfile&context=streaming'
      '&protocol=${protocol.wire}&container=${protocol.videoContainer}'
      '&videoCodec=$videoCodec&audioCodec=$audioCodec&subtitleCodec=)';

  /// The `X-Plex-Client-Profile-Extra` value that asks for a music
  /// transcode to [audioCodec] in [container] over [protocol], capped at
  /// [maxAudioBitrateKbps] when given (see [startAudioTranscode]).
  static String musicProfileExtra({
    required String protocol,
    required String container,
    required String audioCodec,
    int? maxAudioBitrateKbps,
  }) {
    final target =
        'add-transcode-target(type=musicProfile&context=streaming'
        '&protocol=$protocol&container=$container&audioCodec=$audioCodec)';
    if (maxAudioBitrateKbps == null) return target;
    return '$target+add-limitation(scope=musicCodec&scopeName=$audioCodec'
        '&type=upperBound&name=audio.bitrate&value=$maxAudioBitrateKbps'
        '&isRequired=false)';
  }

  /// Build the direct-file download URL — best quality, no transcode.
  ///
  /// PMS 1.43.2 serves an MP3 part *without its ID3v2 tag* (verified: the
  /// body was the file minus its first 137 bytes, exactly the tag), so a
  /// downloaded file carries no embedded tags or cover, and is a little
  /// shorter than [PlexPart.size]. Take metadata and artwork from the
  /// server, not from the downloaded file.
  ///
  /// [partKey] is the metadata-supplied `Part.key`, which already carries
  /// the partId, the required `{changestamp}` cache-busting segment, and
  /// the real filename — e.g. `/library/parts/872/1348327790/file.mkv`.
  /// The spec download endpoint (`getMediaPart`) is
  /// `/library/parts/{partId}/{changestamp}/{filename}`, so the key is
  /// used verbatim rather than reconstructing those segments.
  ///
  /// Returns `(url, ext)` where `ext` is derived from the filename in
  /// [partKey] (the substring after the last `.`, empty if none).
  ///
  /// The URL carries the token: do not log it. Throws a `state`
  /// [PlexException] before [PlexClient.connect].
  (String url, String extension) directFileUrl({
    required String partKey,
    bool download = true,
  }) {
    final url = _http.signedUrl(partKey, {if (download) 'download': '1'});
    final dot = partKey.lastIndexOf('.');
    final slash = partKey.lastIndexOf('/');
    final ext = dot > slash ? partKey.substring(dot + 1) : '';
    return (url, ext);
  }

  /// Build a `/video/:/transcode/universal/start.{ext}` URL.
  ///
  /// Pre-flight with [decisionUniversal] for proper direct-play /
  /// direct-stream / transcode negotiation; the URL itself does not
  /// drive that decision, it follows whatever the server already
  /// decided (or its defaults).
  ///
  /// - [protocol]: HLS (MPEG-TS segments), DASH (fMP4 segments), or HTTP
  ///   (one stream).
  /// - [container]: the *target* container the server should produce;
  ///   `null` takes the protocol's ([PlexStreamingProtocol.videoContainer]).
  ///
  /// Prefer [startVideoTranscode]: PMS 1.43.2 refuses a start without a
  /// decision and a client profile.
  /// - [maxVideoBitrateKbps] / [maxAudioBitrateKbps] cap the output, in
  ///   kbps. Pass `null` to let the server pick.
  /// - [videoResolution]: e.g. `'1920x1080'`, `'1280x720'`.
  ///
  /// The URL carries the token: do not log it. Throws a `state`
  /// [PlexException] before [PlexClient.connect].
  @Deprecated('Use startVideoTranscode instead. Will be removed in 0.4.0.')
  String universalVideoUrl({
    required String ratingKey,
    PlexStreamingProtocol protocol = PlexStreamingProtocol.hls,
    String? container,
    String? videoResolution,
    int? maxVideoBitrateKbps,
    int? maxAudioBitrateKbps,
    String? videoCodec,
    String? audioCodec,
    int? subtitleSize,
    int offsetSeconds = 0,
    String? session,
    bool directPlay = false,
    bool directStream = true,
    int audioBoost = 100,
    bool fastSeek = true,
  }) {
    final ext = protocol == PlexStreamingProtocol.http && container != null
        ? container
        : protocol.extension;
    return _http.signedUrl('/video/:/transcode/universal/start.${seg(ext)}', {
      'path': '/library/metadata/$ratingKey',
      'mediaIndex': '0',
      'partIndex': '0',
      'protocol': protocol.wire,
      'directPlay': directPlay ? '1' : '0',
      'directStream': directStream ? '1' : '0',
      'fastSeek': fastSeek ? '1' : '0',
      'offset': '$offsetSeconds',
      'audioBoost': '$audioBoost',
      'container': container ?? protocol.videoContainer,
      'videoResolution': ?videoResolution,
      'maxVideoBitrate': ?maxVideoBitrateKbps,
      'maxAudioBitrate': ?maxAudioBitrateKbps,
      'videoCodec': ?videoCodec,
      'audioCodec': ?audioCodec,
      'subtitleSize': ?subtitleSize,
      'session': ?session,
    });
  }

  /// Call `/{transcodeType}/:/transcode/universal/decision`.
  ///
  /// Plex inspects the supplied media + client capabilities and decides
  /// whether to direct-play (no transcoding), direct-stream (re-mux
  /// only), or full transcode (re-encode). The same endpoint serves
  /// audio, video, and photo — set [transcodeType] (`'video'` by
  /// default, or `'music'` / `'photo'`) and pass the relevant
  /// `audioCodec`/`videoCodec` hints in [params].
  ///
  /// Returns a [PlexTranscodeDecision]:
  ///   - `generalDecisionCode` in [1000, 2000) means playback can
  ///     succeed (direct-play, direct-stream, or transcode)
  ///   - 2xxx is a general error (e.g. insufficient bandwidth), 3xxx a
  ///     direct-play error, 4xxx a transcode error — all unplayable
  /// Whether the playable decision is direct or a transcode is read from
  /// the sibling `directPlayDecisionCode` / `transcodeDecisionCode`
  /// fields, not from `generalDecisionCode`.
  ///
  /// A 4xx answer that names the remote-streaming pass throws a
  /// [PlexException] of type [PlexErrorType.passRequired]; a decision that
  /// names it is returned as it is: check
  /// [PlexTranscodeDecision.isPassRequired].
  ///
  /// [extraHeaders] is how you pass `X-Plex-Client-Profile-Extra`
  /// (a per-call override of the global profile declared in
  /// [PlexCredentials.clientProfileExtra]).
  Future<PlexTranscodeDecision> decisionUniversal({
    required Map<String, Object?> params,
    String transcodeType = 'video',
    Map<String, String>? extraHeaders,
  }) async {
    final PlexResponse<Map<String, Object?>> res;
    try {
      res = await _http.request<Map<String, Object?>>(
        '/${seg(transcodeType)}/:/transcode/universal/decision',
        queryParameters: params,
        extraHeaders: extraHeaders,
      );
    } on PlexException catch (e) {
      throw classifyPassRequired(e);
    }
    return PlexTranscodeDecision.fromJson(mediaContainer(res.data));
  }

  /// Tell the server a transcode session can be stopped
  /// (`/video/:/transcode/universal/stop`, which also stops music
  /// sessions — verified on PMS 1.43.2).
  ///
  /// A session that no longer exists — already stopped, timed out, or a
  /// DASH session whose segments were never fetched (PMS creates it
  /// lazily) — answers 404; that is the state asked for, so it returns
  /// normally.
  Future<void> stopUniversal({required String session}) async {
    try {
      await _http.request<void>(
        '/video/:/transcode/universal/stop',
        queryParameters: {'session': session},
      );
    } on PlexException catch (e) {
      if (!e.isNotFound) rethrow;
    }
  }

  /// Keep a transcode session alive while the player buffers. Throws a
  /// [PlexException] of type [PlexErrorType.notFound] when the session is
  /// gone (PMS logs "ping without a valid session ID").
  Future<void> pingUniversal({required String session}) async {
    await _http.request<void>(
      '/video/:/transcode/universal/ping',
      queryParameters: {'session': session},
    );
  }

  /// Fetch synced lyrics or plain text. Plex stores the lyrics as a
  /// stream of type 4 under the track's metadata; `streamKey` is the
  /// stream's `key` field (e.g. `/library/streams/12345`).
  ///
  /// The body is fetched as bytes and decoded here, because a `.lrc` is
  /// a file on disk that the server hands back verbatim and its encoding
  /// is not fixed. The codec is chosen in this order:
  ///
  ///  1. A byte-order mark — UTF-8 (`EF BB BF`), UTF-16 LE (`FF FE`) or
  ///     UTF-16 BE (`FE FF`). The mark is evidence carried inside the
  ///     file, so it outranks the response header, and it is consumed
  ///     rather than returned: a leading U+FEFF would push the first
  ///     `[mm:ss.xx]` off the start of the line, and every LRC parser
  ///     that anchors the timestamp there drops that line.
  ///  2. The `charset` of the response's `Content-Type`, when Plex sends
  ///     one naming a codec we can honour. It ranks below the BOM but
  ///     above sniffing: it is the only signal that can separate a
  ///     genuinely Latin-1 file from a UTF-8 one when the bytes are
  ///     valid as both. A charset we do not recognise — or none at all,
  ///     which is what these usually come back with — falls through to
  ///     the next step rather than guessing on the server's behalf.
  ///  3. A *strict* UTF-8 decode, falling back to Latin-1 when it throws.
  ///     Strict on purpose: `allowMalformed` would hide a genuinely
  ///     Latin-1 file behind a row of U+FFFD instead of reading it,
  ///     while a Latin-1 read of UTF-8 bytes is what used to corrupt
  ///     every accented character — asymmetrically, since `È` (`C3 88`)
  ///     became `Ã` plus an invisible C1 control while `è` (`C3 A8`)
  ///     became two visible characters.
  ///
  /// A declared `charset=utf-8` the bytes contradict still degrades to
  /// Latin-1 rather than throwing, so a mislabelled file stays readable
  /// whichever way round it is mislabelled.
  ///
  /// Returns null if the stream key is empty or the server has no
  /// lyrics for the item; otherwise the text read as LRC
  /// ([PlexLyrics.lines]) and kept whole ([PlexLyrics.text]). Throws
  /// [PlexException] for transport errors.
  Future<PlexLyrics?> lyrics({required String streamKey}) async {
    if (streamKey.isEmpty) return null;
    final res = await _http.request<List<int>>(
      streamKey,
      responseType: PlexResponseType.bytes,
      extraHeaders: const {'Accept': '*/*'},
    );
    final data = res.data;
    if (data == null || data.isEmpty) return null;
    return PlexLyrics.parse(
      _decodeTextBody(data, contentType: res.contentType),
    );
  }

  /// Throws [PlexErrorType.passRequired] for a decision that says the
  /// pass is missing.
  void _throwIfPassRequired(PlexTranscodeDecision decision) {
    if (!decision.isPassRequired) return;
    throw PlexException(
      'Playback refused: ${decision.text ?? 'a Plex Pass or Remote Watch '
              'Pass is required'}',
      type: PlexErrorType.passRequired,
      statusCode: 200,
      body: jsonEncode(decision.raw),
    );
  }

  /// [e] retyped as [PlexErrorType.passRequired] when it looks like the
  /// remote-streaming pass refusal: a 4xx other than `401`, `404` and
  /// `498` whose text says so. An HTML page does not count: a site's
  /// pages can name the Plex Pass anywhere. Otherwise [e] unchanged.
  @internal
  static PlexException classifyPassRequired(PlexException e) {
    final status = e.statusCode;
    if (status == null ||
        status < 400 ||
        status >= 500 ||
        status == 401 ||
        status == 404 ||
        status == 498) {
      return e;
    }
    final text = e.body ?? e.message;
    if (_looksLikeHtml(text) || !mentionsPass(text)) return e;
    return e.withType(PlexErrorType.passRequired);
  }

  static bool _looksLikeHtml(String text) {
    final head = text.trimLeft().toLowerCase();
    return head.startsWith('<!doctype html') || head.startsWith('<html');
  }

  /// Whether [text] says playback needs a Plex Pass or Remote Watch Pass.
  @internal
  static bool mentionsPass(String text) => _passPattern.hasMatch(text);

  static final RegExp _passPattern = RegExp(
    r'plex\s*pass|remote\s*watch|remote\s+(?:play(?:back)?|stream(?:ing)?|'
    r'access)[^.]{0,60}(?:requir|subscri|not\s+(?:allowed|available|'
    r'permitted))|subscription\s+(?:is\s+)?required',
    caseSensitive: false,
  );
}

/// Decode a whole text body Plex streamed off disk, picking the codec the
/// bytes — and, failing that, the response header — actually call for.
///
/// See [PlexStreamingApi.lyrics] for why the order is BOM, then declared
/// charset, then a strict UTF-8 attempt with a Latin-1 fallback.
String _decodeTextBody(List<int> bytes, {String? contentType}) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return _utf8OrLatin1(bytes.sublist(3));
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: false);
  }

  switch (_charsetOf(contentType)) {
    case 'utf-8' || 'utf8' || 'us-ascii' || 'ascii':
      return _utf8OrLatin1(bytes);
    case 'iso-8859-1' || 'iso8859-1' || 'iso_8859-1' || 'latin1' || 'latin-1':
      return latin1.decode(bytes);
    // No BOM to say otherwise, so RFC 2781's big-endian default applies
    // to a bare `utf-16`.
    case 'utf-16' || 'utf-16be' || 'utf16be':
      return _decodeUtf16(bytes, littleEndian: false);
    case 'utf-16le' || 'utf16le':
      return _decodeUtf16(bytes, littleEndian: true);
  }

  return _utf8OrLatin1(bytes);
}

/// The lowercased `charset` parameter of a `Content-Type`, or null when
/// the header is absent, carries no charset, or leaves it empty.
String? _charsetOf(String? contentType) {
  if (contentType == null) return null;
  for (final parameter in contentType.split(';').skip(1)) {
    final equals = parameter.indexOf('=');
    if (equals < 0) continue;
    if (parameter.substring(0, equals).trim().toLowerCase() != 'charset') {
      continue;
    }
    var value = parameter.substring(equals + 1).trim().toLowerCase();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    return value.isEmpty ? null : value;
  }
  return null;
}

/// Strict UTF-8, falling back to Latin-1 on the bytes that refuse it.
/// Latin-1 accepts every byte, so this always yields a string.
String _utf8OrLatin1(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

/// Decode UTF-16 code units, [littleEndian] or not, from [bytes] that
/// have already had their BOM removed. A trailing odd byte is dropped.
String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    final first = bytes[i];
    final second = bytes[i + 1];
    units.add(littleEndian ? first | (second << 8) : (first << 8) | second);
  }
  // Surrogate pairs survive: values at or below 0xFFFF are taken as UTF-16
  // code units, so a pair recombines into the one character it encodes.
  return String.fromCharCodes(units);
}
