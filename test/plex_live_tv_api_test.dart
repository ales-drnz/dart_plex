// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Live TV and DVR answers: DVRs, grabbers, EPG languages.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/fixtures.dart';

void main() {
  group('live TV and DVR', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    test('dvrs reads Dvr and DVR, with devices and channel mappings', () async {
      for (final key in ['Dvr', 'DVR']) {
        answer({
          'MediaContainer': {
            key: [
              {
                'key': '/livetv/dvrs/7',
                'uuid': 'u',
                'lineup': 'lu',
                'Device': [
                  {
                    'id': 3,
                    'make': 'Silicondust',
                    'enabled': '1',
                    'tuners': '2',
                    'ChannelMapping': [
                      {'channelKey': 'c', 'enabled': '1'},
                    ],
                  },
                ],
              },
            ],
          },
        });
        final dvrs = await plex.liveTv.dvrs();
        expect(dvrs.single.key, '/livetv/dvrs/7');
        final device = dvrs.single.devices.single;
        expect(
          (device.make, device.enabled, device.tuners),
          ('Silicondust', true, 2),
        );
        expect(device.channelMappings.single.enabled, isTrue);
      }
    });

    test('grabbers (PMS 1.43.2) and EPG languages', () async {
      answer(realFixture('media_grabbers'));
      expect((await plex.devices.grabbers()).single.protocol, 'livetv');
      answer({
        'MediaContainer': {
          'Language': [
            {'code': 'aar', 'title': 'Afar'},
          ],
        },
      });
      expect((await plex.epg.languages()).single.code, 'aar');
    });

    test('the spec fields: lineupType, signal, and raw everywhere', () {
      final device = PlexTunerDevice.fromJson(const {
        'lineupType': 'cable',
        'ChannelMapping': [
          {'channelKey': 'c', 'extra': 1},
        ],
      });
      expect(device.lineupType, 'cable');
      expect(device.channelMappings.single.raw['extra'], 1);
      final channel = PlexEpgChannel.fromJson(const {
        'signalQuality': 80,
        'signalStrength': '90',
      });
      expect((channel.signalQuality, channel.signalStrength), (80, 90));
      expect(channel.raw['signalQuality'], 80);
      for (final raw in [
        PlexMediaGrabber.fromJson(const {'x': 1}).raw,
        PlexDeviceChannel.fromJson(const {'x': 1}).raw,
        PlexEpgLanguage.fromJson(const {'x': 1}).raw,
        PlexRelease.fromJson(const {'x': 1}).raw,
        PlexSectionView.fromJson(const {'x': 1}).raw,
        PlexImage.fromJson(const {'x': 1}).raw,
      ]) {
        expect(raw, {'x': 1});
      }
    });
  });
}
