// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

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
final class PlexException implements Exception {
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

  /// How long the server asked the client to wait (`Retry-After`, on a
  /// `429` or `503`), when it said.
  final Duration? retryAfter;

  /// The originating stack trace, when captured. Preserves the async stack
  /// across catch-and-rethrow so crash reporters can pinpoint the failure.
  final StackTrace? stackTrace;

  /// Construct an exception with a [message] and optional classification fields.
  const PlexException(
    this.message, {
    this.type = PlexErrorType.unknown,
    this.statusCode,
    this.path,
    this.cause,
    this.stackTrace,
    this.retryAfter,
  });

  /// No answer from the server at all: the connection failed or timed out.
  /// The server may be down or unreachable — not the same as an answer that
  /// says no. Same as [PlexErrorType.isRetriable].
  bool get isNetworkFailure =>
      type == PlexErrorType.connection || type == PlexErrorType.timeout;

  /// A failure that may pass if the same request is sent again later: a
  /// network failure, a 5xx (the server failed or is overloaded), or
  /// `429 Too Many Requests`. Not an auth error, another 4xx, a parse or
  /// state error, or a cancellation.
  bool get isTransient =>
      isNetworkFailure ||
      type == PlexErrorType.serverError ||
      statusCode == 429;

  /// The server answered `404`: what was asked for does not exist. For a
  /// read this is a confirmed absence, not a failure to answer.
  bool get isNotFound => type == PlexErrorType.notFound;

  /// The caller cancelled the request. Not a failure: ignore it rather
  /// than reporting it.
  bool get isCancelled => type == PlexErrorType.cancelled;

  /// Shorthand for [PlexErrorType.isAuthError] on [type] — token expired / invalid.
  bool get isAuthError => type.isAuthError;

  /// Shorthand for [PlexErrorType.isRetriable] on [type] — transient failure worth retrying.
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
