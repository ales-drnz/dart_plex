// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:dart_plex/dart_plex.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

DioException _dio(
  DioExceptionType type, {
  int? statusCode,
  Object? error,
  String path = '/x',
}) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    type: type,
    error: error,
    response: statusCode == null
        ? null
        : Response<dynamic>(
            requestOptions: options,
            statusCode: statusCode,
          ),
  );
}

void main() {
  group('PlexException.fromDio', () {
    test('FormatException under unknown maps to parse', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: const FormatException('bad'),
      );
      expect(PlexException.fromDio(e).type, PlexErrorType.parse);
    });

    test('timeout variants map to timeout', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(PlexException.fromDio(_dio(t)).type, PlexErrorType.timeout);
      }
    });

    test('connectionError maps to connection', () {
      final e = _dio(DioExceptionType.connectionError);
      expect(PlexException.fromDio(e).type, PlexErrorType.connection);
    });

    test('badResponse maps status codes to error types', () {
      PlexErrorType typeFor(int status) => PlexException.fromDio(
            _dio(DioExceptionType.badResponse, statusCode: status),
          ).type;

      expect(typeFor(401), PlexErrorType.auth);
      expect(typeFor(403), PlexErrorType.auth);
      expect(typeFor(404), PlexErrorType.notFound);
      expect(typeFor(400), PlexErrorType.badRequest);
      expect(typeFor(429), PlexErrorType.badRequest);
      expect(typeFor(500), PlexErrorType.serverError);
      expect(typeFor(503), PlexErrorType.serverError);
    });

    test('cancel maps to cancelled', () {
      final e = _dio(DioExceptionType.cancel);
      expect(PlexException.fromDio(e).type, PlexErrorType.cancelled);
    });

    test('forwards the originating stackTrace', () {
      final st = StackTrace.current;
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
        stackTrace: st,
      );
      expect(PlexException.fromDio(e).stackTrace, same(st));
    });

    test('unknown without FormatException maps to unknown', () {
      final e = _dio(DioExceptionType.unknown, error: StateError('nope'));
      expect(PlexException.fromDio(e).type, PlexErrorType.unknown);
    });

    test('carries statusCode, path and cause through', () {
      final e = _dio(
        DioExceptionType.badResponse,
        statusCode: 404,
        path: '/library/sections',
      );
      final pe = PlexException.fromDio(e);
      expect(pe.statusCode, 404);
      expect(pe.path, '/library/sections');
      expect(pe.cause, same(e));
    });

    test('explicit path overrides requestOptions path', () {
      final e = _dio(DioExceptionType.unknown, path: '/from-options');
      final pe = PlexException.fromDio(e, path: '/override');
      expect(pe.path, '/override');
    });

    test('isAuthError / isRetriable shorthands track type', () {
      final auth = PlexException.fromDio(
        _dio(DioExceptionType.badResponse, statusCode: 401),
      );
      expect(auth.isAuthError, isTrue);
      expect(auth.isRetriable, isFalse);

      final timeout =
          PlexException.fromDio(_dio(DioExceptionType.receiveTimeout));
      expect(timeout.isRetriable, isTrue);
      expect(timeout.isAuthError, isFalse);
    });
  });
}
