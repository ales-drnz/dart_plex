// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

({PlexStreamingApi api, BytesAdapter adapter}) _makeApi(
  List<int> bytes, {
  String? contentType,
}) {
  final adapter = BytesAdapter(bytes, contentType: contentType);
  final conn = testConnection(adapter)..token = 'tok';
  return (api: PlexStreamingApi(conn), adapter: adapter);
}

/// A synced-lyrics line with the accented capitals that vanish under a
/// Latin-1 read of UTF-8 bytes (`C3 88` becomes `Ã` plus U+0088, a C1
/// control that does not draw) next to the lowercase ones, which double
/// up into two visible characters instead.
const _lrc = '[00:12.00]È già mattina\n'
    '[00:15.30]À Ì Ò Ù É / è ì ò ù é\n';

const _bomUtf8 = [0xEF, 0xBB, 0xBF];

/// U+0088, the invisible half of what `È` turns into under Latin-1.
const _c1 = '\u0088';

/// U+FFFD, what a lenient UTF-8 decode leaves behind on a Latin-1 file.
const _replacement = '�';

Uint8List _utf16le(String s, {bool bom = true}) {
  final out = BytesBuilder();
  if (bom) out.add([0xFF, 0xFE]);
  for (final u in s.codeUnits) {
    out.add([u & 0xFF, (u >> 8) & 0xFF]);
  }
  return out.toBytes();
}

Uint8List _utf16be(String s, {bool bom = true}) {
  final out = BytesBuilder();
  if (bom) out.add([0xFE, 0xFF]);
  for (final u in s.codeUnits) {
    out.add([(u >> 8) & 0xFF, u & 0xFF]);
  }
  return out.toBytes();
}

void main() {
  _stopUniversalTests();

  group('PlexStreamingApi.lyrics decoding', () {
    test('UTF-8 bytes round-trip unchanged', () async {
      final ctx = _makeApi(utf8.encode(_lrc));

      final lyrics = await ctx.api.lyrics(streamKey: '/library/streams/12345');

      expect(lyrics, _lrc);
      // The two halves of the reported asymmetry, spelled out: an accented
      // capital must not become `Ã` plus an invisible C1 control, and an
      // accented lowercase must not become two visible characters.
      expect(lyrics, contains('È già'));
      expect(lyrics, isNot(contains('Ã')));
      expect(lyrics, isNot(contains(_c1)));
    });

    test('a UTF-8 BOM is stripped, not handed to the LRC parser', () async {
      final ctx = _makeApi([..._bomUtf8, ...utf8.encode(_lrc)]);

      final lyrics = await ctx.api.lyrics(streamKey: '/library/streams/12345');

      expect(lyrics, _lrc);
      expect(lyrics!.codeUnitAt(0), isNot(0xFEFF));
      // A leading U+FEFF pushes the first timestamp off position 0, and
      // every LRC parser that anchors `[mm:ss.xx]` at the line start drops
      // the first line because of it.
      expect(lyrics.startsWith('[00:12.00]'), isTrue);
    });

    test(
      'UTF-16 LE with a BOM decodes instead of coming back full of NUL',
      () async {
        final ctx = _makeApi(_utf16le(_lrc));

        final lyrics =
            await ctx.api.lyrics(streamKey: '/library/streams/12345');

        expect(lyrics, _lrc);
        expect(lyrics, isNot(contains('\u0000')));
      },
    );

    test('UTF-16 BE with a BOM decodes too', () async {
      final ctx = _makeApi(_utf16be(_lrc));

      final lyrics = await ctx.api.lyrics(streamKey: '/library/streams/12345');

      expect(lyrics, _lrc);
      expect(lyrics, isNot(contains('\u0000')));
    });

    test(
      'bytes that are not UTF-8 fall back to Latin-1, without U+FFFD',
      () async {
        // `È` is a bare 0xC8 here; as UTF-8 that opens a two-byte sequence
        // and the following space is not a continuation byte, so a strict
        // decode has to fail and a lenient one would litter the line with
        // U+FFFD.
        final bytes = latin1.encode(_lrc);
        expect(() => utf8.decode(bytes), throwsFormatException);

        final ctx = _makeApi(bytes);
        final lyrics =
            await ctx.api.lyrics(streamKey: '/library/streams/12345');

        expect(lyrics, _lrc);
        expect(lyrics, isNot(contains(_replacement)));
      },
    );

    test('an empty body is no lyrics', () async {
      final ctx = _makeApi(const <int>[]);

      expect(await ctx.api.lyrics(streamKey: '/library/streams/12345'), isNull);
    });

    test(
      'an empty stream key returns null without calling the server',
      () async {
        final ctx = _makeApi(utf8.encode(_lrc));

        expect(await ctx.api.lyrics(streamKey: ''), isNull);
        expect(ctx.adapter.lastRequest, isNull);
      },
    );
  });

  group('PlexStreamingApi.lyrics Content-Type charset', () {
    test('an explicit iso-8859-1 is honoured over the UTF-8 guess', () async {
      // These bytes are valid UTF-8 *and* valid Latin-1, so only the header
      // can settle which of the two the server meant.
      final bytes = utf8.encode('[00:12.00]È già');
      final ctx = _makeApi(
        bytes,
        contentType: 'text/plain; charset=iso-8859-1',
      );

      final lyrics = await ctx.api.lyrics(streamKey: '/library/streams/12345');

      expect(lyrics, latin1.decode(bytes));
    });

    test('a BOM outranks a contradicting charset', () async {
      final ctx = _makeApi(
        [..._bomUtf8, ...utf8.encode(_lrc)],
        contentType: 'text/plain; charset=iso-8859-1',
      );

      final lyrics = await ctx.api.lyrics(streamKey: '/library/streams/12345');

      expect(lyrics, _lrc);
    });

    test('a body that contradicts its own charset=utf-8 still reads', () async {
      final ctx = _makeApi(
        latin1.encode(_lrc),
        contentType: 'text/plain; charset=utf-8',
      );

      final lyrics = await ctx.api.lyrics(streamKey: '/library/streams/12345');

      expect(lyrics, _lrc);
      expect(lyrics, isNot(contains(_replacement)));
    });

    test('an unrecognised charset falls through to sniffing', () async {
      final ctx = _makeApi(
        utf8.encode(_lrc),
        contentType: 'text/plain; charset=windows-1252',
      );

      final lyrics = await ctx.api.lyrics(streamKey: '/library/streams/12345');

      expect(lyrics, _lrc);
    });
  });

  group('PlexStreamingApi.lyrics request', () {
    test('GETs the stream key verbatim on the connected server', () async {
      final ctx = _makeApi(utf8.encode(_lrc));
      await ctx.api.lyrics(streamKey: '/library/streams/12345');

      final req = ctx.adapter.lastRequest!;
      expect(req.method, 'GET');
      expect(
        req.uri.toString(),
        'http://192.168.1.10:32400/library/streams/12345',
      );
      expect(req.headers['Accept'], '*/*');
    });
  });
}

void _stopUniversalTests() {
  group('stopUniversal', () {
    Future<void> stopWith(int status) {
      final adapter = CapturingAdapter()
        ..respond = (_) => CannedResponse(status, const []);
      return PlexStreamingApi(testConnection(adapter))
          .stopUniversal(session: 's1');
    }

    test('a session that is already gone (404) is not an error', () async {
      await stopWith(404);
    });

    test('any other failure is still thrown', () async {
      for (final status in [400, 401, 500, 503]) {
        await expectLater(
          stopWith(status),
          throwsA(
            isA<PlexException>().having((e) => e.statusCode, 'status', status),
          ),
          reason: '$status',
        );
      }
    });
  });
}
