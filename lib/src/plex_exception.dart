// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'plex_client.dart';
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
///   if (e.isAuthError) await reAuthenticate();
///   else if (e.isTransient) scheduleRetry();
///   else showError(e.message);
/// }
/// ```
///
/// {@category Errors and paging}
final class PlexException implements Exception {
  final String _message;
  final String? _path;

  /// Human-readable description. A secret in a URL it quotes
  /// (`X-Plex-Token`, `deviceJWT`, `pin`) reads `REDACTED`.
  String get message => _redact(_message);

  /// Semantic category for programmatic handling.
  final PlexErrorType type;

  /// HTTP status code, if the failure came from a server response.
  final int? statusCode;

  /// URL of the request that triggered the failure, if known, with the
  /// value of `X-Plex-Token`, `deviceJWT` and `pin` replaced by
  /// `REDACTED`.
  String? get path => _path == null ? null : _redact(_path);

  /// The underlying error, if any (the transport's `ClientException`, a
  /// `FormatException`, …).
  final Object? cause;

  /// How long the server asked the client to wait (`Retry-After`, on a
  /// `429` or `503`), when it said.
  final Duration? retryAfter;

  /// The body of the error answer as text, whole, when the server sent
  /// one ([message] holds at most its first 512 bytes). Kept so a refusal
  /// the package does not recognise can still be read, logged or shown.
  final String? body;

  /// The originating stack trace, when captured. Preserves the async stack
  /// across catch-and-rethrow so crash reporters can pinpoint the failure.
  final StackTrace? stackTrace;

  /// Construct an exception with a [message] and optional classification fields.
  const PlexException(
    String message, {
    this.type = PlexErrorType.unknown,
    this.statusCode,
    String? path,
    this.cause,
    this.stackTrace,
    this.retryAfter,
    this.body,
  }) : _message = message,
       _path = path;

  /// [text] with the value of every `X-Plex-Token`, `deviceJWT` and `pin`
  /// query parameter replaced by `REDACTED`.
  static String _redact(String text) => text.replaceAllMapped(
    _secret,
    (m) => '${m[1]}REDACTED',
  );

  static final RegExp _secret = RegExp(
    r'([?&;](?:x-plex-token|devicejwt|pin)=)[^&#\s]*',
    caseSensitive: false,
  );

  /// No answer from the server at all: the connection failed or timed out.
  /// The server may be down or unreachable — not the same as an answer that
  /// says no.
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

  /// The server refused playback or a transcode because the account needs
  /// a Plex Pass or a Remote Watch Pass ([PlexErrorType.passRequired]).
  /// The token is fine: do not sign the user out, tell them why.
  bool get isPassRequired => type == PlexErrorType.passRequired;

  /// A copy with [type] replaced, keeping everything else.
  PlexException withType(PlexErrorType type) => PlexException(
    _message,
    type: type,
    statusCode: statusCode,
    path: _path,
    cause: cause,
    stackTrace: stackTrace,
    retryAfter: retryAfter,
    body: body,
  );

  @override
  String toString() {
    final parts = <String>['PlexException($type)'];
    if (statusCode != null) parts.add('status=$statusCode');
    if (path != null) parts.add('path=$path');
    parts.add(message);
    return parts.join(' ');
  }
}
