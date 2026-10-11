// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:dart_plex/dart_plex.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '_helpers/capturing_client.dart';

({PlexNotificationsApi api, StreamingAdapter adapter}) _makeApi() {
  final adapter = StreamingAdapter();
  final conn = testConnection(adapter)..token = 'tok';
  return (api: PlexNotificationsApi(conn), adapter: adapter);
}

/// U+FFFD, what a malformed UTF-8 sequence decodes to.
const _replacement = '�';

/// A track title with the accented characters that a per-chunk decode
/// destroys when the response happens to split inside one of them.
const _title = 'È già mattina (Perché no?)';

String _frame(String title) {
  final payload = jsonEncode({
    'NotificationContainer': {
      'type': 'playing',
      'size': 1,
      'PlaySessionStateNotification': [
        {'state': 'playing', 'title': title},
      ],
    },
  });
  return 'event: message\ndata: $payload\n\n';
}

/// The byte offset one byte into the UTF-8 encoding of [needle], i.e. a
/// split point that lands *between* the two bytes of a `C3 xx` sequence.
int _splitInsideChar(String text, String needle) {
  final at = text.indexOf(needle);
  expect(at, greaterThan(-1), reason: 'fixture must contain $needle');
  return utf8.encode(text.substring(0, at)).length + 1;
}

/// Open the SSE stream, feed it [chunks] in order, and collect whatever
/// notifications come out.
Future<List<PlexNotification>> _pump(
  ({PlexNotificationsApi api, StreamingAdapter adapter}) ctx,
  List<List<int>> chunks, {
  int expected = 1,
}) async {
  final received = <PlexNotification>[];
  final done = Completer<void>();
  final sub = ctx.api.connectEventSource().listen((notification) {
    received.add(notification);
    if (received.length >= expected && !done.isCompleted) done.complete();
  });

  await ctx.adapter.fetched.future;
  for (final chunk in chunks) {
    ctx.adapter.emit(chunk);
  }
  await ctx.adapter.finish();

  await done.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () => throw StateError(
      'expected $expected notification(s), got ${received.length}',
    ),
  );
  await sub.cancel();
  await ctx.api.closeEventSource();
  return received;
}

void main() {
  group('PlexNotificationsApi.connectEventSource decoding', () {
    test('a frame arriving in one chunk decodes', () async {
      final ctx = _makeApi();
      final bytes = utf8.encode(_frame(_title));

      final received = await _pump(ctx, [bytes]);

      expect(received.single.type, 'playing');
      expect(_titleOf(received.single), _title);
    });

    test(
      'a multi-byte character split across two chunks survives',
      () async {
        final ctx = _makeApi();
        final frame = _frame(_title);
        final bytes = utf8.encode(frame);
        // `È` is `C3 88`; cut between the two so the first chunk ends on an
        // incomplete sequence and the second opens on an orphaned
        // continuation byte. Decoding each chunk on its own turns both
        // halves into U+FFFD.
        final at = _splitInsideChar(frame, 'È');
        expect(bytes[at - 1], 0xC3);
        expect(bytes[at], 0x88);

        final received = await _pump(
          ctx,
          [bytes.sublist(0, at), bytes.sublist(at)],
        );

        expect(_titleOf(received.single), _title);
        expect(_titleOf(received.single), isNot(contains(_replacement)));
      },
    );

    test('every byte boundary in the frame is a safe place to split', () async {
      final frame = _frame(_title);
      final bytes = utf8.encode(frame);

      // Walk the cut across the whole frame rather than trusting one
      // hand-picked offset: the real stream splits wherever it likes.
      for (var at = 1; at < bytes.length; at++) {
        final ctx = _makeApi();
        final received = await _pump(
          ctx,
          [bytes.sublist(0, at), bytes.sublist(at)],
        );
        expect(
          _titleOf(received.single),
          _title,
          reason: 'split at byte $at corrupted the payload',
        );
      }
    });

    test('a frame spread over many single-byte chunks still assembles',
        () async {
      final ctx = _makeApi();
      final bytes = utf8.encode(_frame(_title));

      final oneByteEach = [
        for (final byte in bytes) <int>[byte],
      ];
      final received = await _pump(ctx, oneByteEach);

      expect(_titleOf(received.single), _title);
    });

    test('two frames in one chunk are both emitted', () async {
      final ctx = _makeApi();
      final bytes = [
        ...utf8.encode(_frame('Perché')),
        ...utf8.encode(_frame('Città')),
      ];

      final received = await _pump(ctx, [bytes], expected: 2);

      expect(received, hasLength(2));
      expect(_titleOf(received.first), 'Perché');
      expect(_titleOf(received.last), 'Città');
    });

    test('genuinely invalid bytes do not kill the stream', () async {
      final ctx = _makeApi();
      final frame = _frame(_title);
      final bytes = utf8.encode(frame);
      // A lone 0xFF is not valid UTF-8 under any split. It must degrade to
      // U+FFFD inside the frame rather than erroring the subscription and
      // taking every later notification with it.
      final corrupted = [0xFF, ...bytes];

      final received = await _pump(ctx, [corrupted]);

      expect(received.single.type, 'playing');
      expect(_titleOf(received.single), _title);
    });
  });

  group('PlexNotificationsApi.connectEventSource closing early', () {
    test('cancelling before the headers arrive aborts the request', () async {
      final client = _HeldClient();
      final api = PlexNotificationsApi(testConnection(client)..token = 'tok');
      final sub = api.connectEventSource().listen((_) {});
      await client.sent.future;
      await sub.cancel();
      expect(api.isEventSourceConnected, isFalse);
      await expectLater(client.aborted, completes);
      // The late answer is drained and released, not parsed: no stray
      // subscription keeping the socket open, no error.
      client.answer();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(client.released, isTrue);
      // And a new connection may be opened.
      final again = api.connectEventSource().listen((_) {});
      await again.cancel();
    });
  });

  group('PlexNotificationsApi.connectEventSource request', () {
    test('GETs the eventsource route with the token and Accept header',
        () async {
      final ctx = _makeApi();
      await _pump(ctx, [utf8.encode(_frame(_title))]);

      final req = ctx.adapter.lastRequest!;
      expect(req.method, 'GET');
      expect(req.uri.path, '/:/eventsource/notifications');
      expect(req.uri.queryParameters['X-Plex-Token'], 'tok');
      expect(req.headers['Accept'], 'text/event-stream');
    });
  });
}

String? _titleOf(PlexNotification notification) {
  final states = notification.raw['PlaySessionStateNotification'];
  if (states is! List || states.isEmpty) return null;
  final first = states.first;
  return first is Map ? first['title'] as String? : null;
}

/// Holds the response until [answer]; records the abort and whether the
/// body was released (its subscription cancelled).
class _HeldClient extends http.BaseClient {
  final sent = Completer<void>();
  final _response = Completer<http.StreamedResponse>();
  final _body = StreamController<List<int>>();
  late Future<void> aborted;
  bool released = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Only the first request is held; later ones never answer.
    if (sent.isCompleted) return Completer<http.StreamedResponse>().future;
    aborted = (request as http.Abortable).abortTrigger!;
    sent.complete();
    return _response.future;
  }

  void answer() {
    _body.onCancel = () => released = true;
    _response.complete(http.StreamedResponse(_body.stream, 200));
  }

  @override
  void close() => unawaited(_body.close());
}
