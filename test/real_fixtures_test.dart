// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The typed models against real, anonymised PMS 1.43.2 responses
/// (`test/fixtures/real/`, captured from the integration stack with the
/// token, machine identifier and account replaced). A field the server
/// renames or retypes fails here, offline.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

Map<String, Object?> _map(String name) =>
    jsonDecode(File('test/fixtures/real/$name.json').readAsStringSync())
        as Map<String, Object?>;

List<PlexMetadata> _items(String name) =>
    PlexMediaContainer.fromJson(_map(name), 'Metadata', PlexMetadata.fromJson)
        .items;

void main() {
  test('album detail carries counts, dates and artwork version', () {
    final album = _items('album_detail').single;
    expect(album.type, PlexMetadataType.album);
    expect(album.leafCount, 3);
    expect(album.librarySectionId, '1');
    expect(album.originallyAvailableAt, DateTime.utc(2020));
    expect(album.thumbVersion, isNotNull);
    expect(album.ultraBlurColors?.topLeft, isNotNull);
  });

  test('section listings, children, grandchildren, recently added', () {
    expect(_items('section_albums').single.type, PlexMetadataType.album);
    expect(_items('section_artists').single.type, PlexMetadataType.artist);
    final tracks = _items('album_children');
    expect(tracks.map((t) => t.index), [1, 2, 3]);
    expect(tracks.first.parentYear, 2020);
    expect(
      _items('artist_grandchildren').map((t) => t.ratingKey),
      tracks.map((t) => t.ratingKey),
    );
    expect(_items('recently_added').first.leafCount, 3);
  });

  test('track detail has its streams', () {
    final track = _items('track_detail').single;
    expect(track.audioStream?.codec, 'mp3');
    expect(track.media.single.parts.single.key, startsWith('/library/parts/'));
    expect(track.parentThumbVersion, isNotNull);
  });

  test('playlists and their entries', () {
    final entries = _items('playlist_items');
    expect(entries, hasLength(2));
    expect(entries.every((e) => e.playlistItemId != null), isTrue);
    expect(entries.map((e) => e.playlistItemId).toSet(), hasLength(2));
    expect(
      _items('playlists').any((p) => p.title == 'Fixture playlist'),
      isTrue,
    );
  });

  test('genre index, identity, server info, history, butler', () {
    final genres = PlexMediaContainer.fromJson(
      _map('genre_index'),
      'Directory',
      (j) => PlexTag.fromJson(j, field: 'genre'),
    ).items;
    expect(genres.every((g) => g.id != null), isTrue);
    final id = PlexServerIdentity.fromJson(
      _map('identity')['MediaContainer']! as Map<String, Object?>,
    );
    expect(id.machineIdentifier, hasLength(40));
    expect(id.claimed, isTrue);
    final info = PlexServerInfo.fromJson(
      _map('server_info')['MediaContainer']! as Map<String, Object?>,
    );
    expect(info.version, startsWith('1.43.'));
    expect(info.transcoderAudio, isTrue);
    final history = PlexMediaContainer.fromJson(
      _map('history'),
      'Metadata',
      PlexHistoryEntry.fromJson,
    );
    expect(history.items.every((e) => e.viewedAt != null), isTrue);
    final butler =
        (_map('butler')['ButlerTasks']! as Map)['ButlerTask']! as List;
    expect(
      butler
          .map((t) => PlexButlerTask.fromJson(t as Map<String, Object?>).name),
      contains('BackupDatabase'),
    );
  });
}
