// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

/// The decision PMS 1.43.2 answered for an HLS transcode of an h264 clip.
const _ok = {
  'MediaContainer': {
    'generalDecisionCode': 1001,
    'generalDecisionText': 'Direct play not available; Conversion OK.',
    'directPlayDecisionCode': 3000,
    'transcodeDecisionCode': 1001,
  },
};

PlexServerConnection _kind(PlexConnectionKind kind) =>
    PlexServerConnection.fromJson({
      'protocol': 'https',
      'address': '1.2.3.4',
      'port': 32400,
      'uri': 'https://1-2-3-4.x.plex.direct:32400',
      'local': kind == PlexConnectionKind.local,
      'relay': kind == PlexConnectionKind.relay,
    });

void main() {
  group('startVideoTranscode', () {
    for (final protocol in PlexStreamingProtocol.values) {
      test('${protocol.name}: decision, then a start.${protocol.extension} URL '
          'with the same parameters', () async {
        final adapter = CapturingAdapter(_ok);
        final plex = testClient(adapter);
        final t = await plex.streaming.startVideoTranscode(
          ratingKey: '888',
          session: 's1',
          protocol: protocol,
          maxVideoBitrateKbps: 2000,
          videoResolution: '640x480',
        );
        final decision = adapter.last!;
        expect(decision.uri.path, '/video/:/transcode/universal/decision');
        final q = decision.queryParameters;
        expect(q['protocol'], protocol.wire);
        expect(q['path'], '/library/metadata/888');
        expect(q['maxVideoBitrate'], '2000');
        expect(q['videoResolution'], '640x480');
        expect(q['X-Plex-Client-Profile-Name'], 'Generic');
        expect(
          q['X-Plex-Client-Profile-Extra'],
          'add-transcode-target(type=videoProfile&context=streaming'
          '&protocol=${protocol.wire}&container=${protocol.videoContainer}'
          '&videoCodec=h264&audioCodec=aac&subtitleCodec=)',
        );
        expect(t.decision.isPlayable, isTrue);
        expect(t.decision.isTranscode, isTrue);
        expect(t.protocol, protocol);
        final url = Uri.parse(t.url);
        expect(
          url.path,
          '/video/:/transcode/universal/start.${protocol.extension}',
        );
        expect(url.queryParameters['X-Plex-Token'], 'tok');
        expect(url.queryParameters['session'], 's1');
        expect(url.queryParameters['protocol'], protocol.wire);
      });
    }

    test('universalVideoUrl takes the protocol enum', () {
      final plex = testClient(CapturingAdapter());
      final url = Uri.parse(
        // ignore: deprecated_member_use_from_same_package
        plex.streaming.universalVideoUrl(
          ratingKey: '1',
          protocol: PlexStreamingProtocol.dash,
          maxVideoBitrateKbps: 4000,
          maxAudioBitrateKbps: 192,
        ),
      );
      expect(url.path, endsWith('start.mpd'));
      expect(url.queryParameters['container'], 'mp4');
      expect(url.queryParameters['maxVideoBitrate'], '4000');
      expect(url.queryParameters['maxAudioBitrate'], '192');
    });

    test('startAudioTranscode refuses HTTP', () {
      final plex = testClient(CapturingAdapter(_ok));
      expect(
        () => plex.streaming.startAudioTranscode(
          ratingKey: '1',
          session: 's',
          protocol: PlexStreamingProtocol.http,
        ),
        throwsArgumentError,
      );
    });
  });

  group('the remote-streaming pass', () {
    test('a decision that names the pass throws passRequired', () async {
      final adapter = CapturingAdapter({
        'MediaContainer': {
          'generalDecisionCode': 2000,
          'generalDecisionText':
              'Remote playback requires a Plex Pass or Remote Watch Pass',
        },
      });
      final plex = testClient(adapter);
      await expectLater(
        plex.streaming.startVideoTranscode(ratingKey: '1', session: 's'),
        throwsA(
          isA<PlexException>()
              .having((e) => e.isPassRequired, 'isPassRequired', isTrue)
              .having((e) => e.isAuthError, 'isAuthError', isFalse)
              .having((e) => e.body, 'body', contains('Remote Watch Pass')),
        ),
      );
    });

    test('an error body that names it is retyped, raw body kept', () async {
      const body = 'Plex Pass required for remote streaming';
      final adapter = CapturingAdapter()
        ..respond = (_) =>
            CannedResponse(403, utf8.encode(body), contentType: 'text/plain');
      final plex = testClient(adapter);
      await expectLater(
        plex.streaming.startVideoTranscode(ratingKey: '1', session: 's'),
        throwsA(
          isA<PlexException>()
              .having((e) => e.type, 'type', PlexErrorType.passRequired)
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.body, 'body', body),
        ),
      );
    });

    test('an HTML page that names the pass is not retyped', () async {
      const body =
          '<!DOCTYPE html><html><body>Get Plex Pass! Forbidden</body></html>';
      final adapter = CapturingAdapter()
        ..respond = (_) =>
            CannedResponse(403, utf8.encode(body), contentType: 'text/html');
      final plex = testClient(adapter);
      await expectLater(
        plex.streaming.decisionUniversal(params: const {'path': '/x'}),
        throwsA(
          isA<PlexException>().having(
            (e) => e.type,
            'type',
            PlexErrorType.auth,
          ),
        ),
      );
    });

    test('a bare 403 stays an auth error on any connection', () async {
      final adapter = CapturingAdapter()
        ..respond = (_) => CannedResponse(403, utf8.encode('Forbidden'));
      final plex = testClient(adapter);
      for (final kind in PlexConnectionKind.values) {
        plex.connectTo(_kind(kind), accessToken: 'tok');
        await expectLater(
          plex.streaming.decisionUniversal(params: const {'path': '/x'}),
          throwsA(
            isA<PlexException>().having(
              (e) => e.type,
              'type',
              PlexErrorType.auth,
            ),
          ),
          reason: '$kind',
        );
      }
    });

    test('a 401 or 498 is never retyped, whatever it says', () {
      for (final status in [401, 498]) {
        final e = PlexException(
          'HTTP $status',
          type: PlexErrorType.auth,
          statusCode: status,
          body: 'Plex Pass required',
        );
        expect(
          PlexStreamingApi.classifyPassRequired(e).type,
          PlexErrorType.auth,
        );
      }
    });

    test('the heuristics on their own', () {
      for (final text in [
        'Plex Pass required',
        'You need a Remote Watch Pass',
        'Remote streaming is not allowed for this server',
        'Remote playback requires an active subscription',
        'subscription required',
      ]) {
        expect(PlexStreamingApi.mentionsPass(text), isTrue, reason: text);
      }
      for (final text in [
        'Direct play not available; Conversion OK.',
        'Cannot convert this item. No conversion profile found for protocol hls.',
        'Unauthorized',
      ]) {
        expect(PlexStreamingApi.mentionsPass(text), isFalse, reason: text);
      }
      const unrelated = PlexException(
        'HTTP 401',
        type: PlexErrorType.auth,
        statusCode: 401,
      );
      expect(
        PlexStreamingApi.classifyPassRequired(unrelated).type,
        PlexErrorType.auth,
      );
    });
  });

  test('PlexTranscodeDecision.fromJson reads codes as numbers or text', () {
    final d = PlexTranscodeDecision.fromJson(const {
      'generalDecisionCode': '1000',
      'directPlayDecisionCode': 3000,
      'transcodeDecisionCode': '1001',
      'transcodeDecisionText': 'Transcode OK.',
    });
    expect(d.code, 1000);
    expect((d.isPlayable, d.isDirect, d.isTranscode), (true, false, true));
    expect(d.text, 'Transcode OK.');
    expect(d.isPassRequired, isFalse);
  });
}
