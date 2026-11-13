// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The programme guide on the wire: countries (a real PMS 1.43.2 answer),
/// regions, lineups, channels and channel maps. The server has no tuner,
/// so lineups and channel maps follow the pinned API document.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';
import '_helpers/fixtures.dart';
import '_helpers/wire_calls.dart';

const _lineupA = 'lineup://tv.plex.providers.epg.onconnect/USA-HI51418-X#A&B';
const _lineupB = 'lineup://tv.plex.providers.epg.onconnect/USA-OTA96779';

const _lineups = {
  'MediaContainer': {
    'size': 1,
    'Lineup': [
      {
        'key': 'USA-OTA96779',
        'uuid': _lineupB,
        'title': 'Local Over the Air Broadcast',
        'type': 'lineup',
        'identifier': 'USA-OTA96779',
        'lineupType': 0,
        'location': 'Kailua Kona, HI',
        'Channel': [
          {
            'key': '5cc83d73af4a72001e9b16d7-5cab3c634df507001fefcad0',
            'identifier': '10.1',
            'title': 'KHNLDT',
            'callSign': 'KHNLDT',
            'channelVcn': '10.1',
            'language': 'en',
            'thumb': 'https://example.com/logo.png',
            'hd': true,
            'drm': '0',
            'favorite': 1,
            'signalQuality': 88,
            'signalStrength': 92,
          },
        ],
      },
    ],
  },
};

void main() {
  group('guide requests', () {
    testWireCalls([
      (
        'countries',
        (p) => p.epg.countries(),
        'GET',
        '/livetv/epg/countries',
        {},
      ),
      (
        'languages',
        (p) => p.epg.languages(),
        'GET',
        '/livetv/epg/languages',
        {},
      ),
      (
        'countryLineups (plain)',
        (p) => p.epg.countryLineups(
          country: 'usa',
          epgId: 'tv.plex.providers.epg.cloud',
        ),
        'GET',
        '/livetv/epg/countries/usa/tv.plex.providers.epg.cloud/lineups',
        {},
      ),
      (
        'countryLineups (postal code)',
        (p) => p.epg.countryLineups(
          country: 'usa',
          epgId: 'tv.plex.providers.epg.cloud',
          postalCode: '96779',
        ),
        'GET',
        '/livetv/epg/countries/usa/tv.plex.providers.epg.cloud/lineups',
        {'postalCode': '96779'},
      ),
      (
        'countryRegions',
        (p) => p.epg.countryRegions(
          country: 'and',
          epgId: 'tv.plex.providers.epg.cloud',
        ),
        'GET',
        '/livetv/epg/countries/and/tv.plex.providers.epg.cloud/regions',
        {},
      ),
      (
        'regionLineups',
        (p) => p.epg.regionLineups(
          country: 'and',
          epgId: 'tv.plex.providers.epg.cloud',
          region: 'ad-07',
        ),
        'GET',
        '/livetv/epg/countries/and/tv.plex.providers.epg.cloud/regions/ad-07/lineups',
        {},
      ),
      (
        'bestLineup',
        (p) => p.epg.bestLineup(
          device: 'device://tv.plex.grabbers.hdhomerun/1053C0CA',
          lineupGroup: 'USA-OTA96779',
        ),
        'GET',
        '/livetv/epg/lineup',
        {
          'device': 'device://tv.plex.grabbers.hdhomerun/1053C0CA',
          'lineupGroup': 'USA-OTA96779',
        },
      ),
      (
        'channelMap',
        (p) => p.epg.channelMap(
          device: 'device://tv.plex.grabbers.hdhomerun/1053C0CA',
          lineup: _lineupA,
        ),
        'GET',
        '/livetv/epg/channelmap',
        {
          'device': 'device://tv.plex.grabbers.hdhomerun/1053C0CA',
          'lineup': _lineupA,
        },
      ),
      (
        'channels',
        (p) => p.epg.channels(lineup: _lineupA),
        'GET',
        '/livetv/epg/channels',
        {'lineup': _lineupA},
      ),
    ]);

    test('lineupChannels repeats lineup once per URI', () async {
      final adapter = CapturingAdapter(const {
        'MediaContainer': <String, Object?>{},
      });
      await testClient(
        adapter,
      ).epg.lineupChannels(lineup: [_lineupA, _lineupB]);
      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.uri.path, '/livetv/epg/lineupchannels');
      expect(adapter.last!.queryParametersAll, {
        'lineup': [_lineupA, _lineupB],
      });
      expect(adapter.last!.uri.fragment, isEmpty);
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

    test('countries (PMS 1.43.2): code, language, flavor and the example '
        'postal code', () async {
      answer(realFixture('epg_countries'));
      final countries = await plex.epg.countries();
      expect(countries.map((c) => (c.code, c.title, c.flavor)), [
        ('and', 'Andorra', 2),
        ('ita', 'Italy', 1),
        ('usa', 'United States', 1),
      ]);
      final italy = countries[1];
      expect(italy.key, 'ita/tv.plex.providers.epg.cloud/lineups');
      expect(
        (italy.language, italy.languageTitle, italy.example),
        ('ita', 'Italiano', '00100'),
      );
      expect(countries.first.example, '');
      expect(italy.raw['type'], 'country');
    });

    test('countryRegions reads the regions as countries', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'Country': [
            {
              'key': 'and/tv.plex.providers.epg.cloud/regions/ad-07/lineups',
              'type': 'region',
              'title': 'Andorra la Vella',
            },
          ],
        },
      });
      final region = (await plex.epg.countryRegions(
        country: 'and',
        epgId: 'tv.plex.providers.epg.cloud',
      )).single;
      expect(
        (region.title, region.code, region.flavor),
        ('Andorra la Vella', null, null),
      );
      expect(region.key, endsWith('/regions/ad-07/lineups'));
    });

    test('the lineup calls read lineups and their channels', () async {
      answer(_lineups);
      for (final lineups in [
        await plex.epg.countryLineups(country: 'usa', epgId: 'e'),
        await plex.epg.regionLineups(country: 'usa', epgId: 'e', region: 'r'),
        await plex.epg.bestLineup(device: 'd', lineupGroup: 'g'),
        await plex.epg.lineupChannels(lineup: [_lineupB]),
      ]) {
        final lineup = lineups.single;
        expect(
          (lineup.key, lineup.uuid, lineup.title),
          ('USA-OTA96779', _lineupB, 'Local Over the Air Broadcast'),
        );
        expect(
          (lineup.type, lineup.identifier, lineup.lineupType),
          ('lineup', 'USA-OTA96779', 0),
        );
        expect(lineup.location, 'Kailua Kona, HI');
        final channel = lineup.channels.single;
        expect(
          (channel.identifier, channel.callSign, channel.channelVcn),
          ('10.1', 'KHNLDT', '10.1'),
        );
        expect(
          (channel.hd, channel.drm, channel.favorite),
          (true, false, true),
        );
        expect((channel.signalQuality, channel.signalStrength), (88, 92));
      }
    });

    test('channels reads the channels of a lineup', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'Channel': [
            {
              'key': 'k1',
              'identifier': '2.1',
              'title': 'Rai 1',
              'callSign': 'RAI1',
              'channelVcn': '1',
              'language': 'it',
              'thumb': 'https://example.com/rai1.png',
            },
          ],
        },
      });
      final c = (await plex.epg.channels(lineup: _lineupB)).single;
      expect(
        (c.key, c.identifier, c.title, c.callSign),
        ('k1', '2.1', 'Rai 1', 'RAI1'),
      );
      expect(
        (c.channelVcn, c.language, c.thumb),
        ('1', 'it', 'https://example.com/rai1.png'),
      );
      expect((c.hd, c.drm, c.favorite), (false, false, false));
    });

    test('channelMap reads PlexChannelMapping entries', () async {
      answer({
        'MediaContainer': {
          'size': 2,
          'ChannelMapping': [
            {
              'deviceIdentifier': '48.9',
              'channelKey': '48.9',
              'lineupIdentifier': '002',
              'enabled': '1',
            },
            {'deviceIdentifier': '49.1', 'favorite': true},
          ],
        },
      });
      final map = await plex.epg.channelMap(device: 'd', lineup: _lineupB);
      expect(
        map.map(
          (m) =>
              (m.deviceIdentifier, m.channelKey, m.lineupIdentifier, m.enabled),
        ),
        [('48.9', '48.9', '002', true), ('49.1', null, null, false)],
      );
      expect(map.last.raw['favorite'], isTrue);
    });

    test('an answer without entries is empty', () async {
      answer({
        'MediaContainer': {'size': 0},
      });
      expect(await plex.epg.countries(), isEmpty);
      expect(await plex.epg.channels(lineup: 'l'), isEmpty);
      expect(await plex.epg.channelMap(device: 'd', lineup: 'l'), isEmpty);
      expect(await plex.epg.bestLineup(device: 'd', lineupGroup: 'g'), isEmpty);
      expect(await plex.epg.lineupChannels(lineup: ['l']), isEmpty);
    });

    test('countries and channels: a body that is not a container is a '
        'parse error', () async {
      answer([]);
      await expectLater(plex.epg.countries(), throwsParseError);
      await expectLater(plex.epg.channels(lineup: 'l'), throwsParseError);
    });
  });
}
