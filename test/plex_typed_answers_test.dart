// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The answers that were maps in 0.2 and are models in 0.3, the new
/// fields, lyrics, the sort and type vocabulary, and the plex.tv account
/// features — each against a canned answer (PMS 1.43.2's own where the
/// test server has one, the API document's otherwise).
library;

import 'dart:convert';

import 'package:dart_plex/dart_plex.dart';
import 'package:dart_plex/src/plex_xml.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

void main() {
  late CapturingAdapter adapter;
  late PlexClient plex;

  setUp(() {
    adapter = CapturingAdapter();
    plex = testClient(adapter);
  });

  void answer(Object? json) => adapter.responseBody = json;

  group('download queue (PMS 1.43.2 answers)', () {
    test('create and items', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'DownloadQueue': [
            {
              'id': 1,
              'owner': 1,
              'clientIdentifier': 'probe-cli',
              'itemCount': 0,
              'status': 'done',
            },
          ],
        },
      });
      final q = await plex.downloadQueue.create();
      expect(adapter.last!.method, 'POST');
      expect((q.id, q.itemCount, q.status), (1, 0, 'done'));
      answer({
        'MediaContainer': {
          'size': 1,
          'DownloadQueueItem': [
            {
              'id': 1,
              'queueId': 1,
              'key': '888',
              'status': 'error',
              'error': 'decisionError',
              'DecisionResult': {
                'generalDecisionCode': 2004,
                'generalDecisionText': 'Could not construct decision request',
              },
            },
          ],
        },
      });
      final items = await plex.downloadQueue.items(queueId: '1');
      expect(items.single.error, 'decisionError');
      expect(items.single.decision!.code, 2004);
      expect(items.single.decision!.isPlayable, isFalse);
      expect(
        plex.downloadQueue.itemMediaUrl(queueId: '1', itemId: '2'),
        'http://192.168.1.10:32400/downloadQueue/1/item/2/media?X-Plex-Token=tok',
      );
    });

    test('an answer without a queue is a parse error', () async {
      answer({'MediaContainer': <String, Object?>{}});
      await expectLater(
        plex.downloadQueue.get(queueId: '1'),
        throwsA(
          isA<PlexException>().having(
            (e) => e.type,
            'type',
            PlexErrorType.parse,
          ),
        ),
      );
    });
  });

  group('live TV and DVR', () {
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
      answer({
        'MediaContainer': {
          'size': 1,
          'MediaGrabber': [
            {
              'title': 'HDHomerun',
              'identifier': 'tv.plex.grabbers.hdhomerun',
              'protocol': 'livetv',
            },
          ],
        },
      });
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

    test('subscriptions and their template', () async {
      answer({
        'MediaContainer': {
          'SubscriptionTemplate': [
            {
              'MediaSubscription': [
                {
                  'title': 'Show',
                  'type': 2,
                  'airingsType': 'New Airings Only',
                  'Setting': [
                    {'id': 'minVideoQuality', 'value': 0},
                  ],
                  'MediaGrabOperation': [
                    {'id': 'g1', 'status': 'scheduled', 'percent': 0},
                  ],
                },
              ],
            },
          ],
        },
      });
      final subs = await plex.subscriptions.template(guid: 'plex://show/1');
      expect(subs.single.airingsType, 'New Airings Only');
      expect(subs.single.grabs.single.id, 'g1');
      expect(subs.single.settings.single['id'], 'minVideoQuality');
    });
  });

  group('server answers', () {
    test('updater status (PMS 1.43.2: checkedAt -1 is never)', () async {
      answer({
        'MediaContainer': {
          'size': 0,
          'canInstall': false,
          'checkedAt': -1,
          'status': 0,
        },
      });
      final s = await plex.updater.status();
      expect(s.canInstall, isFalse);
      expect(s.checkedAt, isNull);
      expect(s.releases, isEmpty);
    });

    test('providers (PMS 1.43.2 shape)', () async {
      answer({
        'MediaContainer': {
          'size': 1,
          'MediaProvider': [
            {
              'identifier': 'com.plexapp.plugins.library',
              'title': 'Library',
              'types': 'video,audio,photo',
              'protocols': 'stream,download',
              'Feature': [
                {'key': '/library/sections', 'type': 'content'},
                {
                  'flavor': 'universal',
                  'key': '/playlists',
                  'type': 'playlist',
                },
              ],
            },
          ],
        },
      });
      final p = (await plex.providers.list()).single;
      expect(p.types, ['video', 'audio', 'photo']);
      expect(p.features.map((f) => f.type), ['content', 'playlist']);
    });

    test('security resources and background jobs', () async {
      answer({
        'MediaContainer': {
          'Device': {
            'name': 'srv',
            'accessToken': 't',
            'Connection': [
              {'uri': 'https://a:32400', 'local': true},
            ],
          },
        },
      });
      final r = await plex.server.securityResources(source: 'server://x');
      expect(r.accessToken, 't');
      expect(r.connections.single.local, isTrue);
      answer({
        'MediaContainer': {
          'TranscodeJob': [
            {'title': 'Movie', 'progress': 42.5, 'generatorID': 3},
          ],
        },
      });
      final jobs = await plex.server.backgroundTasks();
      expect((jobs.single.progress, jobs.single.generatorId), (42.5, 3));
    });

    test('library tags (PMS 1.43.2) are filterable', () async {
      answer({
        'MediaContainer': {
          'Directory': [
            {'id': 5, 'filter': 'genre=5', 'tag': 'Rock', 'tagType': 1},
          ],
        },
      });
      final tags = await plex.library.tags(type: PlexMetadataType.album);
      expect(adapter.last!.queryParameters['type'], '9');
      expect(tags.single.title, 'Rock');
      expect(PlexFilter.of(tags.single).toString(), 'genre=5');
    });

    test('section details (PMS 1.43.2)', () async {
      answer({
        'MediaContainer': {
          'librarySectionID': 1,
          'title1': 'Music',
          'allowSync': false,
          'Directory': [
            {'key': 'all', 'title': 'All Artists'},
            {'secondary': true, 'key': 'genre', 'title': 'By Genre'},
            {
              'prompt': 'Search for Artists',
              'search': true,
              'key': 'search?type=8',
              'title': 'Search Artists...',
            },
          ],
        },
      });
      final d = await plex.library.sectionDetails(sectionId: '1');
      expect(d.title, 'Music');
      expect(d.views.map((v) => (v.key, v.secondary, v.search)), [
        ('all', false, false),
        ('genre', true, false),
        ('search?type=8', false, true),
      ]);
      expect(d.raw.containsKey('Directory'), isFalse);
    });

    test('person, generators, folder', () async {
      answer({
        'MediaContainer': {
          'Directory': [
            {'id': 9, 'tag': 'Someone', 'thumb': '/t'},
          ],
        },
      });
      expect((await plex.library.person(personId: '9'))!.name, 'Someone');
      answer({
        'MediaContainer': {
          'PlayQueueGenerator': [
            {'id': 4, 'playlistID': 2, 'uri': 'library://x'},
          ],
        },
      });
      final g = await plex.playlists.generators(playlistId: '2');
      expect((g.single.id, g.single.playlistId), (4, 2));
      answer({
        'MediaContainer': {
          'totalSize': 2,
          'Metadata': [
            {'key': '/library/sections/10/folder?parent=3706', 'title': 'A'},
            {'ratingKey': '98901', 'type': 'photo', 'title': 'root.jpg'},
          ],
        },
      });
      final page = await plex.library.folder(
        sectionId: '10',
        parent: '3706',
        size: 50,
      );
      expect(adapter.last!.uri.path, '/library/sections/10/folder');
      expect(adapter.last!.queryParameters['parent'], '3706');
      expect(page.items.first.key, contains('parent=3706'));
    });
  });

  group('metadata', () {
    test('markers, chapters, images, edition', () {
      final m = PlexMetadata.fromJson({
        'ratingKey': '1',
        'type': 'episode',
        'editionTitle': "Director's Cut",
        'Marker': [
          {
            'id': 1,
            'type': 'intro',
            'startTimeOffset': 1000,
            'endTimeOffset': 31000,
          },
          {
            'id': 2,
            'type': 'credits',
            'startTimeOffset': 1200000,
            'endTimeOffset': 1260000,
            'final': true,
          },
        ],
        'Chapter': [
          {
            'id': 5,
            'index': 1,
            'tag': 'Opening',
            'startTimeOffset': 0,
            'endTimeOffset': 60000,
          },
        ],
        'Image': [
          {'type': 'coverPoster', 'url': '/p'},
          {'type': 'backgroundSquare', 'url': '/sq'},
          {'type': 'clearLogo', 'url': '/logo'},
        ],
      });
      expect(m.editionTitle, "Director's Cut");
      expect(m.markers.first.type, PlexMarkerType.intro);
      expect(m.markers.first.end, const Duration(seconds: 31));
      expect(m.markersOf(PlexMarkerType.credits).single.isFinal, isTrue);
      expect(m.chapters.single.title, 'Opening');
      expect(m.squareArt, '/sq');
      expect(m.logo, '/logo');
    });

    test('item() asks for markers and chapters only when told', () async {
      answer({
        'MediaContainer': {
          'Metadata': [
            {'ratingKey': '1'},
          ],
        },
      });
      await plex.library.item(ratingKey: '1');
      expect(adapter.last!.uri.query, isEmpty);
      await plex.library.item(
        ratingKey: '1',
        includeMarkers: true,
        includeChapters: true,
      );
      expect(adapter.last!.queryParameters, {
        'includeMarkers': '1',
        'includeChapters': '1',
      });
    });

    test('loudness and layout fields of a stream', () {
      final s = PlexStream.fromJson({
        'streamType': 2,
        'canNormalizeLoudness': true,
        'albumRange': 4.5,
        'startRamp': 'db=-20;',
        'endRamp': 'db=-30;',
        'audioChannelLayout': '5.1(side)',
        'displayTitle': 'English (EAC3 5.1)',
      });
      expect(s.canNormalizeLoudness, isTrue);
      expect(s.albumRange, 4.5);
      expect(s.startRamp, 'db=-20;');
      expect(s.audioChannelLayout, '5.1(side)');
      expect(s.displayTitle, 'English (EAC3 5.1)');
    });
  });

  group('PlexFilter media fields (verified on PMS 1.43.2)', () {
    test('wire forms', () {
      expect(PlexFilter.atmos().toString(), 'atmos=1');
      expect(PlexFilter.dolbyVision(value: false).toString(), 'dovi=0');
      expect(PlexFilter.hdr().toString(), 'hdr=1');
      expect(
        PlexFilter.videoCodec(['hevc', 'av1']).toString(),
        'videoCodec=hevc,av1',
      );
      expect(
        PlexFilter.videoCodec(['h264'], exclude: true).toString(),
        'videoCodec!=h264',
      );
      expect(PlexFilter.audioCodec(['truehd']).toString(), 'audioCodec=truehd');
      expect(PlexFilter.subtitleCodec(['pgs']).toString(), 'subtitleCodec=pgs');
      expect(PlexFilter.audioLayout(['5.1']).toString(), 'audioLayout=5.1');
      expect(PlexFilter.audioLanguage(['ita']).toString(), 'audioLanguage=ita');
      expect(PlexFilter.inProgress().toString(), 'inProgress=1');
    });
  });

  group('PlexSort', () {
    test('directions and ties', () {
      expect(PlexSort.addedAt.desc, 'addedAt:desc');
      expect(PlexSort.addedAt.desc.asc, 'addedAt:asc');
      expect(
        PlexSort.titleSort.then(PlexSort.year.desc),
        'titleSort,year:desc',
      );
      expect(const PlexSort('mediaBitrate').desc.wire, 'mediaBitrate:desc');
    });

    test('travels as sort=', () async {
      answer({
        'MediaContainer': {'Metadata': <Object?>[]},
      });
      await plex.library.allByType(
        sectionId: '1',
        type: PlexMetadataType.album,
        sort: PlexSort.originallyAvailableAt.desc,
      );
      expect(
        adapter.last!.queryParameters['sort'],
        'originallyAvailableAt:desc',
      );
    });
  });

  group('PlexLyrics', () {
    test('LRC with tags, offset, repeated stamps and a plain line', () {
      final l = PlexLyrics.parse(
        '[ar:Artist]\n[ti:Title]\n[offset:+500]\n'
        '[00:12.00][01:00.50]Chorus\n'
        '[00:05.1]Intro\n'
        'not timed\n',
      );
      expect(l.metadata, {'ar': 'Artist', 'ti': 'Title', 'offset': '+500'});
      expect(l.isSynced, isTrue);
      expect(l.lines.map((x) => (x.start, x.text)), [
        (const Duration(milliseconds: 4600), 'Intro'),
        (const Duration(milliseconds: 11500), 'Chorus'),
        (const Duration(minutes: 1), 'Chorus'),
      ]);
      expect(l.toLrc(), '[00:04.60]Intro\n[00:11.50]Chorus\n[01:00.00]Chorus');
      expect(l.toPlainText(), 'Intro\nChorus\nChorus');
    });

    test('enhanced LRC word times', () {
      final l = PlexLyrics.parse(
        '[00:12.00]<00:12.00>Hello <00:12.40>world<00:13.10>',
      );
      final line = l.lines.single;
      expect(line.text, 'Hello world');
      expect(line.cues.map((c) => (c.position, c.endPosition, c.start)), [
        (0, 6, const Duration(seconds: 12)),
        (6, 11, const Duration(milliseconds: 12400)),
      ]);
      expect(l.hasCues, isTrue);
      expect(
        line.toLrcLine(enhanced: true),
        '[00:12.00]<00:12.00>Hello <00:12.40>world',
      );
    });

    test('plain text gives unsynced lines', () {
      final l = PlexLyrics.parse('one\n\ntwo');
      expect(l.isSynced, isFalse);
      expect(l.lines.map((x) => x.text), ['one', 'two']);
      expect(l.toLrc(), 'one\ntwo');
    });
  });

  group('plex.tv XML', () {
    test('elements become the Plex JSON shape', () {
      final json = plexXmlToJson('''
<?xml version="1.0" encoding="UTF-8"?>
<!-- comment -->
<MediaContainer friendlyName="myPlex" size="2">
  <User id="1" title="Admin &amp; co" admin="1" restricted="0"/>
  <User id="2" title="Kid" restricted="1" restrictionProfile="little_kid">
    <Server name="Home" machineIdentifier="m" numLibraries="3" allLibraries="0"/>
  </User>
</MediaContainer>''');
      final c = json['MediaContainer']! as Map<String, Object?>;
      expect(c['size'], '2');
      final users = c['User']! as List<Object?>;
      expect((users[0]! as Map)['title'], 'Admin & co');
      expect(((users[1]! as Map)['Server']! as List).single, {
        'name': 'Home',
        'machineIdentifier': 'm',
        'numLibraries': '3',
        'allLibraries': '0',
      });
    });

    test('malformed XML is a FormatException', () {
      expect(() => plexXmlToJson('<a b="1">'), throwsFormatException);
    });
  });

  group('plex.tv account features', () {
    CannedResponse xml(String body) =>
        CannedResponse(200, utf8.encode(body), contentType: 'text/xml');

    test('home users (XML), managed users', () async {
      adapter.respond = (_) => xml('''
<MediaContainer size="2">
  <User id="1" uuid="u1" title="Admin" username="admin" email="a@x" admin="1" guest="0" restricted="0" protected="1"/>
  <User id="2" uuid="u2" title="Kid" admin="0" guest="0" restricted="1" restrictionProfile="little_kid" protected="0"/>
</MediaContainer>''');
      final home = await plex.account.homeUsers();
      expect(adapter.last!.path, 'https://plex.tv/api/home/users');
      expect(home.map((u) => (u.id, u.admin, u.restricted, u.protected)), [
        (1, true, false, true),
        (2, false, true, false),
      ]);
      final managed = await plex.account.managedUsers();
      expect(managed.single.restrictionProfile, 'little_kid');
    });

    test('switchHomeUser posts the pin and returns the user token', () async {
      adapter.respond = (_) => xml(
        '<user id="2" uuid="u2" title="Kid" authenticationToken="kid-token" '
        'restricted="1" home="1"/>',
      );
      final user = await plex.account.switchHomeUser(userId: 2, pin: '1234');
      final r = adapter.last!;
      expect(r.method, 'POST');
      expect(r.path, 'https://plex.tv/api/home/users/2/switch');
      expect(r.queryParameters['pin'], '1234');
      expect(user.authToken, 'kid-token');
      expect(user.restricted, isTrue);
      plex.setAccountToken(user.authToken);
      expect(plex.accountToken, 'kid-token');
    });

    test('connected users with their shares (XML)', () async {
      adapter.respond = (_) => xml('''
<MediaContainer>
  <User id="7" title="Friend" username="friend" email="f@x" home="0" allowSync="1">
    <Server id="3" serverId="9" machineIdentifier="m" name="Home" numLibraries="2" allLibraries="0" owned="1" pending="0" lastSeenAt="1700000000"/>
  </User>
</MediaContainer>''');
      final users = await plex.account.connectedUsers();
      expect(adapter.last!.path, 'https://plex.tv/api/users/');
      final share = users.single.servers.single;
      expect(users.single.allowSync, isTrue);
      expect(
        (share.machineIdentifier, share.numLibraries, share.owned),
        ('m', 2, true),
      );
      expect(share.lastSeenAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
    });

    test('friends (JSON list or the documented object)', () async {
      answer([
        {'id': 1, 'uuid': 'a', 'title': 'Ann', 'username': 'ann'},
      ]);
      expect((await plex.account.friends()).single.username, 'ann');
      answer({
        'users': [
          {'id': 2, 'username': 'bob'},
        ],
      });
      expect((await plex.account.friends()).single.title, 'bob');
    });

    test('watchlist via the discover provider', () async {
      answer({
        'MediaContainer': {
          'totalSize': 1,
          'Metadata': [
            {'ratingKey': '5d77', 'guid': 'plex://movie/5d77', 'type': 'movie'},
          ],
        },
      });
      final page = await plex.account.watchlist(
        filter: PlexWatchlistFilter.released,
        sort: PlexSort.watchlistedAt.desc,
        type: PlexMetadataType.movie,
      );
      final r = adapter.last!;
      expect(
        r.path,
        'https://discover.provider.plex.tv/library/sections/watchlist/released',
      );
      expect(r.queryParameters, {
        'includeCollections': '1',
        'includeExternalMedia': '1',
        'sort': 'watchlistedAt:desc',
        'type': '1',
        'X-Plex-Container-Start': '0',
        'X-Plex-Container-Size': '50',
      });
      final key = PlexAccountApi.discoverKeyOf(page.items.single.guid!);
      await plex.account.addToWatchlist(ratingKey: key);
      expect(adapter.last!.method, 'PUT');
      expect(
        adapter.last!.uri.toString(),
        'https://discover.provider.plex.tv/actions/addToWatchlist?ratingKey=5d77',
      );
    });

    test('geoip, snake_case', () async {
      answer({
        'code': 'IT',
        'continent_code': 'EU',
        'country': 'Italy',
        'city': 'Rome',
        'time_zone': 'Europe/Rome',
        'postal_code': '00100',
        'coordinates': '41.9, 12.5',
        'european_union_member': true,
        'in_privacy_restricted_country': false,
      });
      final g = await plex.account.geoip(ipAddress: '1.2.3.4');
      expect(adapter.last!.queryParameters['ip_address'], '1.2.3.4');
      expect(
        (g.code, g.continentCode, g.timeZone),
        ('IT', 'EU', 'Europe/Rome'),
      );
      expect((g.latitude, g.longitude), (41.9, 12.5));
      expect(g.europeanUnionMember, isTrue);
    });
  });
}
