// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Tuner devices on the wire: what each call sends, and the devices and
/// channels read from the answers. The test server has no tuner, so the
/// populated answers follow the pinned API document; the empty ones are
/// what PMS 1.43.2 sends.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/wire_calls.dart';

const _device = {
  'id': 4,
  'key': '/media/grabbers/devices/4',
  'uuid': 'device://tv.plex.grabbers.hdhomerun/1053C0CA',
  'deviceIdentifier': '1053C0CA',
  'make': 'Silicondust',
  'model': 'HDHomeRun CONNECT',
  'modelNumber': 'HDHR4-2US',
  'protocol': 'livetv',
  'sources': 'Antenna,Cable',
  'state': 'enabled',
  'status': 'alive',
  'title': 'Living room',
  'tuners': '2',
  'uri': 'http://192.0.2.20:80',
  'thumb': '/media/grabbers/devices/4/thumb/3',
  'lastSeenAt': 1700000000,
  'ChannelMapping': [
    {
      'deviceIdentifier': '48.9',
      'channelKey': '48.9',
      'lineupIdentifier': '002',
      'enabled': '1',
    },
    {'deviceIdentifier': '49.1', 'channelKey': '49.1', 'enabled': '0'},
  ],
};

const _devices = {
  'MediaContainer': {
    'size': 1,
    'Device': [_device],
  },
};

void main() {
  group('device management', () {
    testWireCalls([
      (
        'grabbers (plain)',
        (p) => p.devices.grabbers(),
        'GET',
        '/media/grabbers',
        {},
      ),
      (
        'grabbers (of a protocol)',
        (p) => p.devices.grabbers(protocol: 'livetv'),
        'GET',
        '/media/grabbers',
        {'protocol': 'livetv'},
      ),
      ('list', (p) => p.devices.list(), 'GET', '/media/grabbers/devices', {}),
      (
        'add',
        (p) => p.devices.add(uri: 'http://192.0.2.20:5004/a?b=1&c=2'),
        'POST',
        '/media/grabbers/devices',
        {'uri': 'http://192.0.2.20:5004/a?b=1&c=2'},
      ),
      (
        'discover',
        (p) => p.devices.discover(),
        'POST',
        '/media/grabbers/devices/discover',
        {},
      ),
      (
        'details',
        (p) => p.devices.details(deviceId: '4'),
        'GET',
        '/media/grabbers/devices/4',
        {},
      ),
      (
        'remove',
        (p) => p.devices.remove(deviceId: '4'),
        'DELETE',
        '/media/grabbers/devices/4',
        {},
      ),
      (
        'setEnabled (on)',
        (p) => p.devices.setEnabled(deviceId: '4', enabled: true),
        'PUT',
        '/media/grabbers/devices/4',
        {'enabled': '1'},
      ),
      (
        'setEnabled (off)',
        (p) => p.devices.setEnabled(deviceId: '4', enabled: false),
        'PUT',
        '/media/grabbers/devices/4',
        {'enabled': '0'},
      ),
      (
        'setChannelMap (nothing to set)',
        (p) => p.devices.setChannelMap(deviceId: '4'),
        'PUT',
        '/media/grabbers/devices/4/channelmap',
        {},
      ),
      (
        'setChannelMap',
        (p) => p.devices.setChannelMap(
          deviceId: '4',
          channelMapping: {'46.3': '003', '48.9': '004'},
          channelMappingByKey: {'46.3': '5cc83d73af4a72001e9b16d7-a'},
          channelsEnabled: ['46.1', '46.3', '48.9'],
        ),
        'PUT',
        '/media/grabbers/devices/4/channelmap',
        {
          'channelMapping[46.3]': '003',
          'channelMapping[48.9]': '004',
          'channelMappingByKey[46.3]': '5cc83d73af4a72001e9b16d7-a',
          'channelsEnabled': '46.1,46.3,48.9',
        },
      ),
      (
        'setPreferences (nothing to set)',
        (p) => p.devices.setPreferences(deviceId: '4'),
        'PUT',
        '/media/grabbers/devices/4/prefs',
        {},
      ),
      (
        'setPreferences',
        (p) => p.devices.setPreferences(
          deviceId: '4',
          name: 'Attic & roof',
          prefs: {'transcodeDuringRecord': 1, 'country': 'ita'},
        ),
        'PUT',
        '/media/grabbers/devices/4/prefs',
        {
          'name': 'Attic & roof',
          'transcodeDuringRecord': '1',
          'country': 'ita',
        },
      ),
      (
        'startScan (plain)',
        (p) => p.devices.startScan(deviceId: '4'),
        'POST',
        '/media/grabbers/devices/4/scan',
        {},
      ),
      (
        'startScan (of a source)',
        (p) => p.devices.startScan(deviceId: '4', source: 'Cable'),
        'POST',
        '/media/grabbers/devices/4/scan',
        {'source': 'Cable'},
      ),
      (
        'stopScan',
        (p) => p.devices.stopScan(deviceId: '4'),
        'DELETE',
        '/media/grabbers/devices/4/scan',
        {},
      ),
      (
        'channels',
        (p) => p.devices.channels(deviceId: '4'),
        'GET',
        '/media/grabbers/devices/4/channels',
        {},
      ),
    ]);
  });

  group('answers', () {
    late CapturingAdapter adapter;
    late PlexClient plex;

    setUp(() {
      adapter = CapturingAdapter();
      plex = testClient(adapter);
    });

    void answer(Object? json) => adapter.responseBody = json;

    void expectDevice(PlexTunerDevice d) {
      expect(
        (d.id, d.key, d.uuid),
        (
          4,
          '/media/grabbers/devices/4',
          'device://tv.plex.grabbers.hdhomerun/1053C0CA',
        ),
      );
      expect(
        (d.deviceIdentifier, d.make, d.model, d.modelNumber),
        ('1053C0CA', 'Silicondust', 'HDHomeRun CONNECT', 'HDHR4-2US'),
      );
      expect(
        (d.protocol, d.sources, d.state, d.status),
        ('livetv', 'Antenna,Cable', 'enabled', 'alive'),
      );
      expect(
        (d.title, d.tuners, d.uri),
        ('Living room', 2, 'http://192.0.2.20:80'),
      );
      expect(d.thumb, '/media/grabbers/devices/4/thumb/3');
      expect(d.lastSeenAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect(
        d.channelMappings.map(
          (m) => (m.deviceIdentifier, m.channelKey, m.lineupIdentifier),
        ),
        [('48.9', '48.9', '002'), ('49.1', '49.1', null)],
      );
      expect(d.channelMappings.map((m) => m.enabled), [true, false]);
      expect(d.channelMappings.first.raw['lineupIdentifier'], '002');
    }

    test('list, add and discover read the devices', () async {
      answer(_devices);
      expectDevice((await plex.devices.list()).single);
      expectDevice(
        (await plex.devices.add(uri: 'http://192.0.2.20:80')).single,
      );
      expectDevice((await plex.devices.discover()).single);
    });

    test('details reads one device, or null when the answer holds '
        'none', () async {
      answer(_devices);
      expectDevice((await plex.devices.details(deviceId: '4'))!);
      answer({
        'MediaContainer': {'size': 0},
      });
      expect(await plex.devices.details(deviceId: '4'), isNull);
    });

    test('a server without tuners lists none (PMS 1.43.2 answers '
        '{"MediaContainer":{"size":0}})', () async {
      answer({
        'MediaContainer': {'size': 0},
      });
      expect(await plex.devices.list(), isEmpty);
      expect(await plex.devices.discover(), isEmpty);
      expect(await plex.devices.channels(deviceId: '4'), isEmpty);
    });

    test('channels reads the channels a device found', () async {
      answer({
        'MediaContainer': {
          'size': 2,
          'DeviceChannel': [
            {
              'key': '48.9',
              'identifier': '48.9',
              'name': 'KQED',
              'drm': false,
              'favorite': '1',
              'hd': true,
              'signalQuality': 90,
              'signalStrength': '85',
            },
            {'identifier': '49.1', 'name': 'Scrambled', 'drm': true},
          ],
        },
      });
      final channels = await plex.devices.channels(deviceId: '4');
      final first = channels.first;
      expect(
        (first.key, first.identifier, first.name),
        ('48.9', '48.9', 'KQED'),
      );
      expect((first.drm, first.favorite, first.hd), (false, true, true));
      expect((first.signalQuality, first.signalStrength), (90, 85));
      final second = channels.last;
      expect(
        (second.key, second.drm, second.favorite, second.hd),
        (null, true, false, false),
      );
      expect(second.signalQuality, isNull);
    });

    test('channels: a body that is not a container is a parse error', () async {
      answer(['x']);
      await expectLater(plex.devices.channels(deviceId: '4'), throwsParseError);
    });
  });

  test('thumbUrl points at the device thumb and its version', () {
    final url = testClient(
      CapturingAdapter(),
    ).devices.thumbUrl(deviceId: '4', version: '3');
    expect(Uri.parse(url).origin, 'http://192.168.1.10:32400');
    expect(pathAndToken(url), ('/media/grabbers/devices/4/thumb/3', 'tok'));
  });
}
