// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:dio/dio.dart';

import 'plex_error_type.dart';

/// Exception thrown by [PlexClient] for any failed operation.
///
/// The [message] is suitable for log lines but not for end users.
/// The [type] classifies the failure so callers can branch behaviour:
///
/// ```dart
/// try {
///   await plex.library.sections();
/// } on PlexException catch (e) {
///   if (e.type.isAuthError) await reAuthenticate();
///   else if (e.type.isRetriable) scheduleRetry();
///   else showError(e.message);
/// }
/// ```
class PlexException implements Exception {
  /// Human-readable description.
  final String message;

  /// Semantic category for programmatic handling.
  final PlexErrorType type;

  /// HTTP status code, if the failure came from a server response.
  final int? statusCode;

  /// Path of the request that triggered the failure, if known.
  final String? path;

  /// The underlying error, if any (DioException, FormatException, …).
  final Object? cause;

  const PlexException(
    this.message, {
    this.type = PlexErrorType.unknown,
    this.statusCode,
    this.path,
    this.cause,
  });

  /// Build a [PlexException] from a [DioException] — maps timeouts /
  /// connection errors / status codes onto [PlexErrorType].
  factory PlexException.fromDio(DioException e, {String? path}) {
    final code = e.response?.statusCode;
    final type = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        PlexErrorType.timeout,
      DioExceptionType.connectionError => PlexErrorType.connection,
      DioExceptionType.badResponse when code != null =>
        PlexErrorType.fromHttpStatus(code),
      DioExceptionType.cancel => PlexErrorType.unknown,
      _ => PlexErrorType.unknown,
    };
    return PlexException(
      e.message ?? 'Plex request failed',
      type: type,
      statusCode: code,
      path: path ?? e.requestOptions.path,
      cause: e,
    );
  }

  bool get isAuthError => type.isAuthError;
  bool get isRetriable => type.isRetriable;

  @override
  String toString() {
    final parts = <String>['PlexException($type)'];
    if (statusCode != null) parts.add('status=$statusCode');
    if (path != null) parts.add('path=$path');
    parts.add(message);
    return parts.join(' ');
  }
}
