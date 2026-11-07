// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// The small XML reader for plex.tv's XML-only routes.
library;

import 'package:dart_plex/src/plex_xml.dart';
import 'package:test/test.dart';

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
        '<a b=',
        '<a b',
        '<a',
        '<a b="1"><b/></a>',
        '<a b="1" b="2"/>',
        '<a b="&#x110000;"/>',
        '<a b="&#99999999999999999999;"/>',
      ]) {
        expect(() => plexXmlToJson(bad), throwsFormatException, reason: bad);
      }
    });
  });
}
