// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// DVRs and live sessions on the wire: what each call sends, the DVR and
/// the sessions read from the answers, and the URLs of a live session.
/// The test server has no tuner: the empty answers are PMS 1.43.2's, the
/// populated ones follow the pinned API document.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/wire_calls.dart';

const _lineup =
    'lineup://tv.plex.providers.epg.onconnect/USA-HI51418-DEFAULT#Spectrum';

void main() {
  group('DVR management', () {
    testWireCalls([
      ('get', (p) => p.dvrs.get(dvrId: '28'), 'GET', '/livetv/dvrs/28', {}),
      (
        'delete',
        (p) => p.dvrs.delete(dvrId: '28'),
        'DELETE',
        '/livetv/dvrs/28',
        {},
      ),
      (
        'setPreferences (nothing to set)',
        (p) => p.dvrs.setPreferences(dvrId: '28'),
        'PUT',
        '/livetv/dvrs/28/prefs',
        {},
      ),
      (
        'setPreferences',
        (p) => p.dvrs.setPreferences(
          dvrId: '28',
          name: 'Den & attic',
          prefs: {'startOffsetMinutes': 2, 'xmltvRefreshIntervalHours': '24'},
        ),
        'PUT',
        '/livetv/dvrs/28/prefs',
        {
          'name': 'Den & attic',
          'startOffsetMinutes': '2',
          'xmltvRefreshIntervalHours': '24',
        },
      ),
      (
        'addLineup',
        (p) => p.dvrs.addLineup(dvrId: '28', lineup: _lineup),
        'PUT',
        '/livetv/dvrs/28/lineups',
        {'lineup': _lineup},
      ),
      (
        'deleteLineup',
        (p) => p.dvrs.deleteLineup(dvrId: '28', lineup: _lineup),
        'DELETE',
        '/livetv/dvrs/28/lineups',
        {'lineup': _lineup},
      ),
      (
        'reloadGuide',
        (p) => p.dvrs.reloadGuide(dvrId: '28'),
        'POST',
        '/livetv/dvrs/28/reloadGuide',
        {},
      ),
      (
        'stopReloadGuide',
        (p) => p.dvrs.stopReloadGuide(dvrId: '28'),
        'DELETE',
        '/livetv/dvrs/28/reloadGuide',
        {},
      ),
      (
        'tuneChannel',
        (p) => p.dvrs.tuneChannel(dvrId: '28', channel: '2.1'),
        'POST',
        '/livetv/dvrs/28/channels/2.1/tune',
        {},
      ),
      (
        'addDevice',
        (p) => p.dvrs.addDevice(dvrId: '28', deviceId: '4'),
        'PUT',
        '/livetv/dvrs/28/devices/4',
        {},
      ),
      (
        'removeDevice',
        (p) => p.dvrs.removeDevice(dvrId: '28', deviceId: '4'),
        'DELETE',
        '/livetv/dvrs/28/devices/4',
        {},
      ),
      ('liveTv.dvrs', (p) => p.liveTv.dvrs(), 'GET', '/livetv/dvrs', {}),
      (
        'liveTv.sessions',
        (p) => p.liveTv.sessions(),
        'GET',
        '/livetv/sessions',
        {},
      ),
      (
        'liveTv.dvrChannels',
        (p) => p.liveTv.dvrChannels(dvrKey: '/livetv/dvrs/28'),
        'GET',
        '/livetv/dvrs/28/channels',
        {},
      ),
      (
        'liveTv.liveSession',
        (p) => p.liveTv.liveSession(sessionId: 'abc-1'),
        'GET',
        '/livetv/sessions/abc-1',
        {},
      ),
    ]);

    test('the lineup URI travels percent-encoded, # included', () async {
      final adapter = CapturingAdapter();
      await testClient(adapter).dvrs.addLineup(dvrId: '28', lineup: _lineup);
      expect(adapter.last!.uri.fragment, isEmpty);
      expect(
        adapter.last!.uri.query,
        'lineup=${Uri.encodeQueryComponent(_lineup)}',
      );
    });
  });

  group('answers', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    test('get reads the DVR with its devices, under Dvr or DVR', () async {
      for (final key in ['Dvr', 'DVR']) {
        answer({
          'MediaContainer': {
            'size': 1,
            key: [
              {
                'key': '28',
                'uuid': 'dvr-uuid',
                'language': 'eng',
                'lineup': _lineup,
                'Device': [
                  {'id': 4, 'key': '/media/grabbers/devices/4', 'enabled': 1},
                ],
              },
            ],
          },
        });
        final dvr = (await plex.dvrs.get(dvrId: '28'))!;
        expect(
          (dvr.key, dvr.uuid, dvr.language, dvr.lineup),
          ('28', 'dvr-uuid', 'eng', _lineup),
        );
        expect((dvr.devices.single.id, dvr.devices.single.enabled), (4, true));
        expect(dvr.raw['uuid'], 'dvr-uuid');
      }
    });

    test('get is null when the answer holds no DVR', () async {
      answer({
        'MediaContainer': {'size': 0},
      });
      expect(await plex.dvrs.get(dvrId: '28'), isNull);
    });

    test('a server without Live TV has no DVR and no session (PMS 1.43.2 '
        'answers {"MediaContainer":{"size":0}})', () async {
      answer({
        'MediaContainer': {'size': 0},
      });
      expect(await plex.liveTv.dvrs(), isEmpty);
      expect(await plex.liveTv.sessions(), isEmpty);
      expect(await plex.liveTv.liveSession(sessionId: 'x'), isNull);
    });

    test('sessions, liveSession and dvrChannels read metadata', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'Metadata': [
            {
              'ratingKey': '55',
              'key': '/livetv/sessions/abc-1',
              'type': 'episode',
              'title': 'News at Nine',
              'grandparentTitle': 'News',
              'live': '1',
            },
          ],
        },
      });
      final session = (await plex.liveTv.sessions()).single;
      expect(
        (session.ratingKey, session.title, session.grandparentTitle),
        ('55', 'News at Nine', 'News'),
      );
      expect(session.type, PlexMetadataType.episode);
      expect(
        (await plex.liveTv.liveSession(sessionId: 'abc-1'))!.key,
        '/livetv/sessions/abc-1',
      );
      expect(
        (await plex.liveTv.dvrChannels(dvrKey: '/livetv/dvrs/28')).single.title,
        'News at Nine',
      );
    });

    test('sessions: a body that is not a container is a parse '
        'error', () async {
      answer('<html>');
      await expectLater(plex.liveTv.sessions(), throwsParseError);
    });
  });

  group('URLs of a live session', () {
    late PlexClient plex;

    setUp(() => plex = testClient(CapturingAdapter()));

    test('sessionPlaylistUrl', () {
      final url = plex.liveTv.sessionPlaylistUrl(
        sessionId: 'abc-1',
        consumerId: 'c9',
      );
      expect(Uri.parse(url).origin, 'http://192.168.1.10:32400');
      expect(pathAndToken(url), (
        '/livetv/sessions/abc-1/c9/index.m3u8',
        'tok',
      ));
    });

    test('sessionSegmentUrl', () {
      final url = plex.liveTv.sessionSegmentUrl(
        sessionId: 'abc-1',
        consumerId: 'c9',
        segmentId: '00042.ts',
      );
      expect(pathAndToken(url), ('/livetv/sessions/abc-1/c9/00042.ts', 'tok'));
    });
  });
}
