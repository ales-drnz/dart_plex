// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The small XML reader for plex.tv's XML-only routes. The fixtures in
/// `test/fixtures/xml/` are real plex.tv answers (November 2026), with the
/// account, tokens and hosts replaced.
library;

import 'dart:io';

import 'package:dart_plex/dart_plex.dart';
import 'package:dart_plex/src/parsing/plex_json.dart';
import 'package:dart_plex/src/parsing/plex_xml.dart';
import 'package:test/test.dart';

Map<String, Object?> _fixture(String name) =>
    plexXmlToJson(File('test/fixtures/xml/$name.xml').readAsStringSync());

Map<String, Object?> _root(String xml, [String name = 'a']) =>
    plexXmlToJson(xml)[name]! as Map<String, Object?>;

void main() {
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
      for (final bad in [
        '',
        '  ',
        'text <a/>',
        '<a b=',
        '<a b',
        '<a',
        '<a<b/>',
        '<a b="1" b="2"/>',
        '<a b="&#x110000;"/>',
        '<a b="&#99999999999999999999;"/>',
        '<a>&#x110000;</a>',
        '<a><b></a></b>',
        '<a></b>',
        '<a></a',
        '<a></a b>',
        '<a><!-- open</a>',
        '<a><![CDATA[ open</a>',
      ]) {
        expect(() => plexXmlToJson(bad), throwsFormatException, reason: bad);
      }
    });

    test('a child named like an attribute is ignored, not an error', () {
      expect(_root('<a b="1"><b/><b c="2"/><b>text</b></a>'), {'b': '1'});
    });

    test('a child with text alone is a string, like an attribute', () {
      final a = _root('''
<a>
  <name> Ann &amp; Bob </name>
  <count>12</count>
  <flag>true</flag>
  <cdata><![CDATA[<b> & ]]>c</cdata>
  <empty></empty>
  <blank>  </blank>
  <typed type="datetime">2024-01-02</typed>
  <mixed>text<c/></mixed>
  <name>second</name>
</a>''');
      expect(a['name'], 'Ann & Bob');
      expect(asInt(a['count']), 12);
      expect(asBool(a['flag']), isTrue);
      expect(a['cdata'], '<b> & c');
      // Nothing to tell an empty element from one without attributes.
      expect(a['empty'], [<String, Object?>{}]);
      expect(a['blank'], [<String, Object?>{}]);
      expect(a['typed'], [
        {'type': 'datetime'},
      ]);
      expect(a['mixed'], [
        {
          'c': [<String, Object?>{}],
        },
      ]);
      // The object readers skip a string.
      expect(asObjectList(a['name'], (m) => m), isEmpty);
    });

    test('elements keep their name over a later text child', () {
      expect(_root('<a><b c="1"/><b>text</b><b c="2"/></a>')['b'], [
        {'c': '1'},
        {'c': '2'},
      ]);
      expect(_root('<a><b>text</b><b c="1"/></a>')['b'], 'text');
    });

    test('a root with text alone is an empty object', () {
      expect(plexXmlToJson('<a>text</a>'), {'a': <String, Object?>{}});
    });

    test('the closing tag may carry white space', () {
      expect(plexXmlToJson('<a b="1"><c></c\n></a >'), {
        'a': {
          'b': '1',
          'c': [<String, Object?>{}],
        },
      });
    });

    test('around the root: a BOM, a DTD, comments, nothing else', () {
      const empty = {'a': <String, Object?>{}};
      for (final ok in [
        '﻿<a/>',
        '<!DOCTYPE a><a/>',
        '<!DOCTYPE a [ <!ELEMENT a (b)> <!ENTITY c "d"> ]>\n<a/>',
        '<a/>\n<!-- bye --> <?pi ?>\n',
      ]) {
        expect(plexXmlToJson(ok), empty, reason: ok);
      }
      for (final bad in ['<a/><b/>', '<a/>text', '<a/><!DOCTYPE a>', '<a/><']) {
        expect(() => plexXmlToJson(bad), throwsFormatException, reason: bad);
      }
    });

    test('a comment before a CDATA section yields no phantom children', () {
      expect(
        _root('<a x="1"><!-- c --><![CDATA[ > <b/> <c d="1"/> ]]><e/></a>'),
        {
          'x': '1',
          'e': [<String, Object?>{}],
        },
      );
      expect(_root('<a><?pi ?><![CDATA[1 > <b/>]]></a>'), isEmpty);
    });

    test('absurd nesting is a FormatException, not a stack overflow', () {
      String nested(int depth) => '${'<a>' * depth}${'</a>' * depth}';
      expect(plexXmlToJson(nested(64)), contains('a'));
      expect(() => plexXmlToJson(nested(65)), throwsFormatException);
      expect(() => plexXmlToJson('<a>' * 200000), throwsFormatException);
    });
  });

  group('real plex.tv answers', () {
    test('GET /api/home/users', () {
      final users = asObjectList(
        mediaContainer(_fixture('plex_tv_home_users'))['User'],
        PlexHomeUser.fromJson,
      );
      final user = users.single;
      expect(user.id, 100000001);
      expect(user.uuid, '0123456789abcdef');
      expect(user.title, 'tester');
      expect(user.admin, isTrue);
      expect(user.restricted, isFalse);
      // hasPassword="true" is the account's password, not a PIN.
      expect(user.raw['hasPassword'], 'true');
      expect(user.protected, isFalse);
      expect(user.thumb, startsWith('https://plex.tv/users/'));
    });

    test('GET /api/users/ with nobody to list', () {
      final c = mediaContainer(_fixture('plex_tv_users'));
      expect(c['size'], '0');
      expect(asObjectList(c['User'], PlexAccountUser.fromJson), isEmpty);
    });

    // The shape of the home-user switch: `username` and `email` are both
    // attributes and children of `<user>`.
    test('the legacy <user> (GET /users/account)', () {
      final json = _fixture('plex_tv_user');
      final user = PlexUser.fromJson(json);
      expect(user.id, 100000001);
      expect(user.uuid, '0123456789abcdef');
      expect(user.username, 'tester');
      expect(user.email, 'tester@example.invalid');
      expect(user.title, 'tester');
      expect(user.authToken, 'FAKE-ACCOUNT-TOKEN-0');
      expect(user.hasPlexPass, isFalse);
      expect(user.home, isFalse);
      expect(user.restricted, isFalse);
      expect(user.subscriptionFeatures, hasLength(70));
      expect(user.subscriptionFeatures, contains('two-factor-authentication'));
      // The children without an attribute of their name.
      expect(user.raw['authentication-token'], 'FAKE-ACCOUNT-TOKEN-0');
      expect(user.raw['joined-at'], [
        {'type': 'datetime'},
      ]);
    });
  });
}
