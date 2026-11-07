Build stream URLs for audio and video, manage transcode sessions, and read lyrics and loudness.

<img src="https://raw.githubusercontent.com/ales-drnz/dart_plex/main/imgs/diagrams/audio_transcode_sequence.png" width="100%" alt="Audio transcode: startAudioTranscode makes the decision and returns the URL; the player opens it; pingUniversal while paused; stopUniversal at the end">

The streaming calls return URLs; none of them fetches the media. Hand the
URL to your player (mpv, AVPlayer, ExoPlayer). The URL carries
`X-Plex-Token` in its query, so segment requests need no headers.
`PlexStreamingProtocol` names the protocol: `hls` (an `.m3u8` of MPEG-TS
segments), `dash` (an `.mpd` of fragmented MP4) or `http` (one stream).

## Audio transcode

```dart
final transcode = await plex.streaming.startAudioTranscode(
  ratingKey: track.ratingKey,
  session: 'my-uuid',   // one per playback session
  protocol: PlexStreamingProtocol.dash, // hls (default) or dash
  maxAudioBitrateKbps: 128,
);
if (transcode.decision.isPlayable) {
  print(transcode.url); // hand to the player
}
```

`startAudioTranscode()` asks the server for a decision for `session`,
then builds the `start` URL from the same parameters. It names a client
profile (`clientProfileName`, `'Generic'` by default), so it works from
any platform, and sends the transcode target and the bitrate cap the
server expects. `audioCodec` is `'aac'` by default; `offsetSeconds`,
`mediaIndex` and `partIndex` pick where and what to play. The cap cannot
go above the profile's own ceiling, 256 kbps AAC for `Generic`.

When `decision.isPlayable` is false the URL does not play either. Stop
each session you stop playing (see Transcode sessions below): while
other transcodes of the same client stay open, a new session's bitrate
cap may not apply. To make the decision yourself,
`PlexStreamingApi.musicProfileExtra()` builds the same profile value for
`decisionUniversal()`.

## Direct file URL

```dart
final (url, ext) = plex.streaming.directFileUrl(
  partKey: track.media.first.parts.first.key!,
);
```

The original file, with no transcode. Use it for downloads (see
[Events and downloads](https://pub.dev/documentation/dart_plex/latest/topics/Events%20and%20downloads-topic.html))
and for players that decode whatever the file contains. `ext` is the
file's extension.

The server sends an MP3 without its ID3v2 tag, so a downloaded MP3 has no
embedded tags or cover and is a little shorter than `PlexPart.size`. Take
metadata and artwork from the server.

## Transcode sessions

```dart
await plex.streaming.pingUniversal(session: sessionId); // keep alive
await plex.streaming.stopUniversal(session: sessionId); // tear down
```

The same calls serve audio and video sessions. The server drops a
session after about 2 minutes without requests: ping every 30 s while
the player is paused, and stop the session when the user leaves.
`pingUniversal()` throws a `PlexException` of type `notFound` once the
session is gone. `stopUniversal()` returns normally when the session no
longer exists, or never started: the server creates a DASH session with
its first segment.

## Video transcode

```dart
final transcode = await plex.streaming.startVideoTranscode(
  ratingKey: movie.ratingKey,
  session: 'my-uuid',
  protocol: PlexStreamingProtocol.hls, // hls, dash or http
  maxVideoBitrateKbps: 8000,
  videoResolution: '1920x1080',
);
if (transcode.decision.isPlayable) {
  print(transcode.url); // start.m3u8, start.mpd or start.mkv
}
```

The video counterpart of `startAudioTranscode()`: a decision for
`session`, then the `start` URL with the same parameters. PMS 1.43.2
answers "no conversion profile found" (decision code 4005) unless the
client profile names a target, so the call sends
`X-Plex-Client-Profile-Name` (`Generic` by default) and a `videoProfile`
target for the protocol (`PlexStreamingApi.videoProfileExtra()`:
`videoCodec` `h264` and `audioCodec` `aac` by default, in MPEG-TS, MP4 or
Matroska). Verified for all three protocols on PMS 1.43.2.
`directStream` (on by default) lets the server copy what it need not
re-encode.

## Video decision

To make the decision yourself, call `decisionUniversal()`. The server
weighs the source against your client profile and answers with
`generalDecisionCode`: 1xxx means playback can succeed; 2xxx (general),
3xxx (direct play) and 4xxx (transcode) are errors.

```dart
final decision = await plex.streaming.decisionUniversal(
  params: {
    'path': '/library/metadata/$ratingKey',
    'mediaIndex': 0,
    'partIndex': 0,
    'protocol': PlexStreamingProtocol.hls.wire,
    'directPlay': 0,
    'directStream': 1,
    'videoResolution': '1920x1080',
    'maxVideoBitrate': 8000,
    'session': 'my-uuid',
    'X-Plex-Client-Profile-Name': 'Generic',
  },
  extraHeaders: {
    'X-Plex-Client-Profile-Extra': PlexStreamingApi.videoProfileExtra(
      protocol: PlexStreamingProtocol.hls,
    ),
  },
);

if (decision.isDirect) {
  // direct play or direct stream
} else if (decision.isTranscode) {
  // the server transcodes
} else {
  print(decision.text); // why not: bandwidth, codec, the remote pass
}
```

`transcodeType` is `'video'` by default; `'music'` and `'photo'` reach
the other transcoders. `isDirect` and `isTranscode` read
`directPlayDecisionCode` and `transcodeDecisionCode`; `text` is the
server's own explanation and the whole answer is in `raw`.

## Remote playback and the pass

Since April 2025 Plex requires a Plex Pass (on the server owner's
account) or a Remote Watch Pass (on the viewer's) to stream personal
video to a device outside the server's network. `plex.connectionKind`
says how the client reaches the server (`local`, `remote` or `relay`,
known after `connectToResource` or `connectTo`).

A refusal for that reason is a `PlexException` of type
`PlexErrorType.passRequired` (`isPassRequired`), with the server's whole
answer in `body`. It is not an auth error: the token works, do not sign
the user out. PMS documents no code for it, so the decision calls
(`decisionUniversal`, `startVideoTranscode`, `startAudioTranscode`)
recognise it from:

- the text of a 4xx error answer other than `401`, `404` and `498`, or
  of a decision's `generalDecisionText`, `transcodeDecisionText` or
  `directPlayDecisionText`, naming "Plex Pass" or "Remote Watch", or
  remote playback as requiring a subscription or not allowed. An HTML
  page does not count: a site's pages can name the Plex Pass anywhere.

`startAudioTranscode()` and `startVideoTranscode()` throw for such a
decision; `decisionUniversal()` returns it, with `isPassRequired` true.

A bare `403` stays an auth error on any connection: it is also how a
server refuses a token. The rule could not be checked against a real
refusal for this release.
A refusal they miss stays the error it was (an auth or bad-request
error, or an unplayable decision): when in doubt, read `connectionKind`
and `body`. Music is not covered by the requirement.

## Transcoder URLs

`plex.transcoder` builds the raw transcoder URLs:

```dart
final cover = plex.transcoder.imageUrl(
  sourceUrl: album.thumb!,
  width: 600,
  height: 600,
  blur: 20,
  format: 'png',
);
final subtitles = plex.transcoder.subtitlesUrl(
  transcodeType: 'video',
  params: {'session': 'my-uuid'},
);
```

`imageUrl()` exposes every option of the photo transcoder (`quality`,
`blur`, `saturation`, `opacity`, `rotate`, `background`, `blendColor`).
`startUrl()` builds a `start.{extension}` URL from your own parameters,
and `triggerFallback()` asks the server for a full transcode after
direct play failed.

## Lyrics

```dart
final full = await plex.library.item(ratingKey: track.ratingKey);
final lyricsStream = full!.media.first.parts.first.streams
    .firstWhere((s) => s.isLyrics);
final lyrics = await plex.streaming.lyrics(streamKey: lyricsStream.key!);
for (final line in lyrics?.lines ?? const <PlexLyricLine>[]) {
  print('${line.start} ${line.text}');
}
```

The lyrics are a stream of the full item (`isLyrics`, stream type 4).
`lyrics()` returns `PlexLyrics`, or `null` when there is none: `text` is
the file as decoded, `lines` its lines read as LRC. A line has `start`
(`null` when unsynced), `text` and, for enhanced LRC, word `cues`
(`position`, `endPosition`, `start`, `end`), the shape of dart_jellyfin's
`JellyfinLyricLine`. Several `[mm:ss.xx]` on one line repeat it, the LRC
ID tags (`ar`, `ti`, `al`, `au`, `by`, `length`, `offset`, `re`, `ve`,
`#`) go to `metadata`, and `[offset:±ms]` is applied to every time. Any
other bracketed line, such as `[Chorus: Jay-Z]`, is text.
`toLrc()` (with `enhanced: true` for word times) and `toPlainText()` write
it back.

The file is decoded whatever its encoding: a byte-order mark first
(removed, so the first `[mm:ss.xx]` still starts its line), then the
response's `charset`, then UTF-8 with Latin-1 as the fallback.

## Loudness

```dart
final full = await plex.library.item(ratingKey: track.ratingKey);
final audio = full?.audioStream;
if (audio != null && audio.hasLoudness) {
  print('track gain ${audio.gain} dB, album gain ${audio.albumGain} dB, '
      'peak ${audio.peak}, ${audio.loudness} LUFS');
}
```

An analysed audio stream carries `gain`, `albumGain`, `peak`,
`albumPeak`, `albumRange`, `loudness` (LUFS), `lra` (LU), `startRamp` and
`endRamp`, from the server's own analysis, and `canNormalizeLoudness`
says whether the server can level it. They survive a transcode that drops the file's ReplayGain tags:
read them from the original stream and apply the gain to the transcoded
audio. `audioStream` is the selected audio stream of the first part.
