// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The lenient readers every model goes through: whatever arrives, none
/// throws.
library;

import 'package:dart_plex/dart_plex.dart';
import 'package:dart_plex/src/plex_json.dart';
import 'package:test/test.dart';

void main() {
  test('asString', () {
    expect(asString(null), isNull);
    expect(asString('a'), 'a');
    expect(asString(''), '');
    expect(asString(7), '7');
    expect(asString(true), 'true');
  });

  test('asInt', () {
    expect(asInt(7), 7);
    expect(asInt(7.9), 7);
    expect(asInt(-7.9), -7);
    expect(asInt('7'), 7);
    expect(asInt('-7'), -7);
    expect(asInt(' 7 '), 7);
    expect(asInt('12.0'), 12);
    expect(asInt('12.7'), 12);
    expect(asInt('1e3'), 1000);
    for (final bad in <Object?>[
      null,
      '',
      'abc',
      '12abc',
      'NaN',
      'Infinity',
      '1e999',
      double.nan,
      double.infinity,
      double.negativeInfinity,
      true,
      <Object?>[7],
      <String, Object?>{},
    ]) {
      expect(asInt(bad), isNull, reason: '$bad');
    }
  });

  test('asDouble', () {
    expect(asDouble(7), 7.0);
    expect(asDouble(7.5), 7.5);
    expect(asDouble('7.5'), 7.5);
    expect(asDouble('7'), 7.0);
    for (final bad in <Object?>[null, '', 'abc', true, <Object?>[]]) {
      expect(asDouble(bad), isNull, reason: '$bad');
    }
  });

  test('asBool', () {
    for (final yes in <Object?>[true, 1, '1', 'true']) {
      expect(asBool(yes), isTrue, reason: '$yes');
    }
    for (final no in <Object?>[false, 0, 2, '0', 'false', 'yes', '', null]) {
      expect(asBool(no), isFalse, reason: '$no');
    }
  });

  group('asUtcDateTime', () {
    test('a zone is honoured', () {
      final at = DateTime.utc(2024, 1, 2, 3, 4, 5);
      expect(asUtcDateTime('2024-01-02T03:04:05Z'), at);
      expect(asUtcDateTime('2024-01-02T05:04:05+02:00'), at);
      expect(asUtcDateTime('2024-01-02T03:04:05.250Z')!.millisecond, 250);
      expect(asUtcDateTime('2024-01-02T03:04:05Z')!.isUtc, isTrue);
    });

    // Whatever the zone of the machine running the test.
    test('no zone is UTC, not local time', () {
      final at = asUtcDateTime('2024-01-02T03:04:05')!;
      expect(at.isUtc, isTrue);
      expect(at, DateTime.utc(2024, 1, 2, 3, 4, 5));
      expect(
        asUtcDateTime('2024-01-02 03:04:05.006007'),
        at.add(const Duration(milliseconds: 6, microseconds: 7)),
      );
      expect(asUtcDateTime('2024-01-02'), DateTime.utc(2024, 1, 2));
    });

    test("the legacy XML's `… UTC`", () {
      expect(
        asUtcDateTime('2024-01-02 03:04:05 UTC'),
        DateTime.utc(2024, 1, 2, 3, 4, 5),
      );
    });

    test('anything else is null', () {
      for (final bad in <Object?>[
        null,
        '',
        'yesterday',
        ' UTC',
        '2024-13-45T99:99:99Z junk',
        1704164645,
        <Object?>[],
      ]) {
        expect(asUtcDateTime(bad), isNull, reason: '$bad');
      }
    });
  });

  test('asCalendarDate', () {
    expect(asCalendarDate('2020-05-17'), DateTime.utc(2020, 5, 17));
    expect(asCalendarDate('2020-05-17 23:59:59'), DateTime.utc(2020, 5, 17));
    expect(
      asCalendarDate('2020-05-17T10:00:00Z'),
      DateTime.utc(2020, 5, 17, 10),
    );
    for (final bad in <Object?>[null, '', 'soon', 20200517]) {
      expect(asCalendarDate(bad), isNull, reason: '$bad');
    }
  });

  group('asEpochSeconds', () {
    test('ints, doubles and numeric strings', () {
      final at = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final s = at.millisecondsSinceEpoch ~/ 1000;
      expect(asEpochSeconds(s), at);
      expect(asEpochSeconds('$s'), at);
      expect(asEpochSeconds(s + 0.9), at);
      expect(asEpochSeconds(0), DateTime.utc(1970));
      expect(asEpochSeconds(-1), DateTime.utc(1969, 12, 31, 23, 59, 59));
      expect(asEpochSeconds(s)!.isUtc, isTrue);
    });

    test('out of range is null, not a RangeError', () {
      const limit = 8640000000000;
      expect(asEpochSeconds(limit), isNotNull);
      expect(asEpochSeconds(-limit), isNotNull);
      for (final bad in <Object?>[
        limit + 1,
        -limit - 1,
        '9999999999999999',
        // Milliseconds sent as seconds, far in the future.
        1704164645000000,
        1e300,
        double.nan,
        double.infinity,
        null,
        'soon',
      ]) {
        expect(asEpochSeconds(bad), isNull, reason: '$bad');
      }
    });

    test('an absurd date does not fail the item around it', () {
      final item = PlexMetadata.fromJson(const {
        'ratingKey': '1',
        'title': 'T',
        'type': 'track',
        'addedAt': 99999999999999999,
        'updatedAt': 1704164645,
      });
      expect(item.addedAt, isNull);
      expect(item.updatedAt, DateTime.utc(2024, 1, 2, 3, 4, 5));
    });
  });

  test('mediaContainer', () {
    const inner = {'size': 1};
    expect(mediaContainer(const {'MediaContainer': inner}), inner);
    expect(mediaContainer(inner), inner);
    expect(mediaContainer(const {'MediaContainer': 3}), {'MediaContainer': 3});
    for (final bad in <Object?>[null, 'x', 3, <Object?>[]]) {
      expect(mediaContainer(bad), isEmpty, reason: '$bad');
    }
  });

  test('asObjectList skips what is not an object', () {
    int id(Map<String, Object?> m) => asInt(m['id']) ?? -1;
    expect(
      asObjectList(const [
        {'id': 1},
        'x',
        null,
        3,
        <Object?>[],
        {'id': '2'},
      ], id),
      [1, 2],
    );
    for (final bad in <Object?>[null, 'x', 3, <String, Object?>{}]) {
      expect(asObjectList(bad, id), isEmpty, reason: '$bad');
    }
  });

  test('asObject: an object, or the first of a list of them', () {
    const m = {'id': 1};
    expect(asObject(m), m);
    expect(asObject(const [m, 'x']), m);
    for (final bad in <Object?>[
      null,
      'x',
      3,
      <Object?>[],
      const ['x', m],
    ]) {
      expect(asObject(bad), isNull, reason: '$bad');
    }
  });

  test('asCsv', () {
    expect(asCsv('server,player'), ['server', 'player']);
    expect(asCsv(' server , ,player,'), ['server', 'player']);
    expect(asCsv('one'), ['one']);
    expect(asCsv(7), ['7']);
    for (final empty in <Object?>[null, '', ' ', ',,']) {
      expect(asCsv(empty), isEmpty, reason: '$empty');
    }
  });

  test('tagNames', () {
    expect(
      tagNames(const [
        {'tag': 'Rock'},
        {'tag': 7},
        {'id': 1},
        'Pop',
        {'tag': 'Jazz'},
      ]),
      ['Rock', 'Jazz'],
    );
    expect(tagNames(null), isEmpty);
    expect(tagNames(const {'tag': 'Rock'}), isEmpty);
  });

  group('PlexTag.fromJson', () {
    test('a key that is not a URI, or does not decode, is no id', () {
      for (final key in [
        'http://[::1',
        '/library/sections/1/genre/%FF',
        '/library/sections/1/all?genre=%FF',
        '/library/sections/1/all?%FF=1',
      ]) {
        final tag = PlexTag.fromJson({'key': key, 'title': 'Rock'});
        expect(tag.id, isNull, reason: key);
        expect(tag.title, 'Rock');
        expect(tag.key, key);
      }
    });

    test('the three shapes still resolve', () {
      expect(
        PlexTag.fromJson(const {
          'fastKey': '/library/sections/3/all?genre=42&type=9',
        }).id,
        42,
      );
      expect(PlexTag.fromJson(const {'key': '42'}).id, 42);
      final byPath = PlexTag.fromJson(const {
        'key': '/library/sections/3/genre/42',
      });
      expect((byPath.id, byPath.field), (42, 'genre'));
    });
  });
}
