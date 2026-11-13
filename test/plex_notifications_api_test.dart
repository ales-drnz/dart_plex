// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

    test('a multi-byte character split across two chunks survives', () async {
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

      final received = await _pump(ctx, [
        bytes.sublist(0, at),
        bytes.sublist(at),
      ]);

      expect(_titleOf(received.single), _title);
      expect(_titleOf(received.single), isNot(contains(_replacement)));
    });

    test('every byte boundary in the frame is a safe place to split', () async {
      final frame = _frame(_title);
      final bytes = utf8.encode(frame);

      // Walk the cut across the whole frame rather than trusting one
      // hand-picked offset: the real stream splits wherever it likes.
      for (var at = 1; at < bytes.length; at++) {
        final ctx = _makeApi();
        final received = await _pump(ctx, [
          bytes.sublist(0, at),
          bytes.sublist(at),
        ]);
        expect(
          _titleOf(received.single),
          _title,
          reason: 'split at byte $at corrupted the payload',
        );
      }
    });

    test(
      'a frame spread over many single-byte chunks still assembles',
      () async {
        final ctx = _makeApi();
        final bytes = utf8.encode(_frame(_title));

        final oneByteEach = [
          for (final byte in bytes) <int>[byte],
        ];
        final received = await _pump(ctx, oneByteEach);

        expect(_titleOf(received.single), _title);
      },
    );

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
    test('GETs the eventsource route, the token in the header only', () async {
      final ctx = _makeApi();
      await _pump(ctx, [utf8.encode(_frame(_title))]);

      final req = ctx.adapter.lastRequest!;
      expect(req.method, 'GET');
      expect(req.uri.path, '/:/eventsource/notifications');
      // The header authenticates; the URL stays free of the secret.
      expect(req.uri.queryParameters, isEmpty);
      expect(req.headers['X-Plex-Token'], 'tok');
      expect(req.headers['Accept'], 'text/event-stream');
    });

    test('the filter goes in the query', () async {
      final ctx = _makeApi();
      final sub = ctx.api.connectEventSource(filter: 'playing').listen((_) {});
      await ctx.adapter.fetched.future;

      expect(ctx.adapter.lastRequest!.uri.queryParameters, {
        'filter': 'playing',
      });
      await sub.cancel();
    });

    test('nothing is requested before the first listener', () async {
      final ctx = _makeApi();
      final stream = ctx.api.connectEventSource();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(ctx.adapter.requests, isEmpty);
      expect(ctx.api.isEventSourceConnected, isTrue);

      final sub = stream.listen((_) {});
      await ctx.adapter.fetched.future;
      expect(ctx.adapter.requests, hasLength(1));
      await sub.cancel();
    });
  });

  group('PlexNotificationsApi.connectEventSource frames as PMS sends them', () {
    // Captured from PMS 1.43.2 during a library scan: the type is the
    // `event:` name, the body has no NotificationContainer and holds one
    // bare entry, and a `ping` event comes every 10 seconds.
    final capture = File(
      'test/fixtures/notifications/eventsource_scan.txt',
    ).readAsStringSync();

    test('the type comes from the event line and pings are dropped', () async {
      final received = await _pump(_makeApi(), [
        utf8.encode(capture),
      ], expected: 4);

      expect(received.map((n) => n.type), [
        'activity',
        'status',
        'progress',
        'activity',
      ]);
    });

    test('frames come out in the WebSocket shape and decode', () async {
      final received = await _pump(_makeApi(), [
        utf8.encode(capture),
      ], expected: 4);

      final started = received.first;
      expect(started.raw['type'], 'activity');
      expect(started.raw['ActivityNotification'], isA<List<Object?>>());
      expect(started.size, isNull);

      final events = received.expand((n) => n.events).toList();
      expect(
        events[0],
        isA<PlexActivityEvent>()
            .having((e) => e.event, 'event', 'started')
            .having((e) => e.activityType, 'type', 'library.update.section')
            .having((e) => e.isLibraryScan, 'isLibraryScan', isTrue),
      );
      expect(
        events[1],
        isA<PlexStatusEvent>()
            .having((e) => e.title, 'title', 'Scanning the "Music" section')
            .having((e) => e.notificationName, 'name', 'LIBRARY_UPDATE'),
      );
      expect(
        events[2],
        isA<PlexUnknownEvent>().having((e) => e.type, 'type', 'progress'),
      );
      expect(
        events[3],
        isA<PlexActivityEvent>()
            .having((e) => e.isEnded, 'isEnded', isTrue)
            .having((e) => e.librarySectionId, 'section', '1'),
      );
    });

    test('CRLF line endings frame the same', () async {
      final received = await _pump(_makeApi(), [
        utf8.encode(capture.replaceAll('\n', '\r\n')),
      ], expected: 4);

      expect(received, hasLength(4));
      expect(received.last.events.single, isA<PlexActivityEvent>());
    });

    test('a body with its own type keeps it', () async {
      final received = await _pump(_makeApi(), [
        utf8.encode('event: other\ndata: {"type":"playing","size":2}\n\n'),
      ]);

      expect(received.single.type, 'playing');
      expect(received.single.size, 2);
    });
  });

  group('PlexNotificationsApi.connectEventSource malformed frames', () {
    test('are dropped and counted, and the stream goes on', () async {
      final ctx = _makeApi();
      final errors = <Object>[];
      final received = <PlexNotification>[];
      final got = Completer<void>();
      final sub = ctx.api.connectEventSource().listen((n) {
        received.add(n);
        got.complete();
      }, onError: errors.add);
      await ctx.adapter.fetched.future;

      ctx.adapter
        ..emit(utf8.encode('event: playing\ndata: {not json\n\n'))
        ..emit(utf8.encode('event: playing\ndata: [1, 2]\n\n'))
        ..emit(utf8.encode(_frame(_title)));
      await got.future.timeout(const Duration(seconds: 5));

      expect(received.single.type, 'playing');
      expect(errors, isEmpty);
      expect(ctx.api.malformedFrameCount, 2);
      await sub.cancel();
    });
  });

  group('PlexNotificationsApi.connectEventSource failing to open', () {
    test('the error reaches a listener that subscribes late', () async {
      final adapter = CapturingAdapter()
        ..respond = (_) => CannedResponse(401, utf8.encode('Unauthorized'));
      final api = PlexNotificationsApi(testConnection(adapter)..token = 'tok');
      final stream = api.connectEventSource();
      // A broadcast stream drops what nobody listens to: opening at once
      // would lose the failure during this gap.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final errors = <Object>[];
      final done = Completer<void>();
      stream.listen((_) {}, onError: errors.add, onDone: done.complete);
      await done.future.timeout(const Duration(seconds: 5));

      expect(
        errors.single,
        isA<PlexException>()
            .having((e) => e.type, 'type', PlexErrorType.auth)
            .having((e) => e.statusCode, 'statusCode', 401),
      );
      expect(api.isEventSourceConnected, isFalse);
    });
  });

  group('PlexNotificationsApi.connectEventSource idle watchdog', () {
    test('a silent connection errors with timeout and ends', () async {
      final ctx = _makeApi();
      final errors = <Object>[];
      final done = Completer<void>();
      ctx.api
          .connectEventSource(idleTimeout: const Duration(milliseconds: 60))
          .listen((_) {}, onError: errors.add, onDone: done.complete);
      await ctx.adapter.fetched.future;

      await done.future.timeout(const Duration(seconds: 5));

      expect(
        errors.single,
        isA<PlexException>().having(
          (e) => e.type,
          'type',
          PlexErrorType.timeout,
        ),
      );
      expect(ctx.api.isEventSourceConnected, isFalse);
    });

    test('the server pings keep it open', () async {
      final ctx = _makeApi();
      final errors = <Object>[];
      final received = <PlexNotification>[];
      final sub = ctx.api
          .connectEventSource(idleTimeout: const Duration(milliseconds: 300))
          .listen(received.add, onError: errors.add);
      await ctx.adapter.fetched.future;

      // Twice the timeout in total, never 300 ms without a byte.
      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        ctx.adapter.emit(utf8.encode('event: ping\ndata: {}\n\n'));
      }

      expect(errors, isEmpty);
      expect(received, isEmpty, reason: 'pings are not notifications');
      expect(ctx.api.isEventSourceConnected, isTrue);
      expect(ctx.api.malformedFrameCount, 0);
      await sub.cancel();
    });

    test('null never times out', () async {
      final ctx = _makeApi();
      final errors = <Object>[];
      final sub = ctx.api
          .connectEventSource(idleTimeout: null)
          .listen((_) {}, onError: errors.add);
      await ctx.adapter.fetched.future;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(errors, isEmpty);
      expect(ctx.api.isEventSourceConnected, isTrue);
      await sub.cancel();
    });
  });

  group('PlexNotificationsApi.connectEventSource lifecycle', () {
    test('a second connect while one is open is a state error', () async {
      final ctx = _makeApi();
      ctx.api.connectEventSource();

      expect(
        ctx.api.connectEventSource,
        throwsA(
          isA<PlexException>().having(
            (e) => e.type,
            'type',
            PlexErrorType.state,
          ),
        ),
      );
      await ctx.api.closeEventSource();
      expect(ctx.api.isEventSourceConnected, isFalse);
    });

    test('only the last subscription cancelling closes it', () async {
      final ctx = _makeApi();
      final stream = ctx.api.connectEventSource();
      final first = stream.listen((_) {});
      final second = stream.listen((_) {});
      await ctx.adapter.fetched.future;

      await first.cancel();
      expect(ctx.api.isEventSourceConnected, isTrue);
      await second.cancel();
      expect(ctx.api.isEventSourceConnected, isFalse);
    });

    test('the server ending the body ends the stream', () async {
      final ctx = _makeApi();
      final done = Completer<void>();
      ctx.api.connectEventSource().listen((_) {}, onDone: done.complete);
      await ctx.adapter.fetched.future;

      await ctx.adapter.finish();
      await done.future.timeout(const Duration(seconds: 5));

      expect(ctx.api.isEventSourceConnected, isFalse);
    });

    test('PlexClient.close() closes it', () async {
      final adapter = StreamingAdapter();
      final plex = testClient(adapter);
      final done = Completer<void>();
      plex.notifications.connectEventSource().listen(
        (_) {},
        onDone: done.complete,
      );
      await adapter.fetched.future;

      plex.close();
      await done.future.timeout(const Duration(seconds: 5));

      expect(plex.notifications.isEventSourceConnected, isFalse);
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
