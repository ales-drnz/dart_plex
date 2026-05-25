// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Semantic categories for failures coming out of [PlexClient].
///
/// Used by [PlexException.type] so callers can decide whether to retry,
/// re-authenticate, or surface the error to the user.
enum PlexErrorType {
  /// Transport-level failure (DNS resolution, TCP reset, broken pipe, no
  /// route to host). Usually retriable after a backoff.
  connection,

  /// The request did not complete within the configured timeout.
  timeout,

  /// The server replied with `401 Unauthorized` / `403 Forbidden`, or the
  /// PIN flow returned an authToken-less response past its `expiresAt`.
  /// Callers should re-run the PIN/sign-in flow.
  auth,

  /// The server replied with `404 Not Found` — the resource (rating key,
  /// playlist, section) does not exist on this server.
  notFound,

  /// The server replied with a 4xx other than 401/403/404.
  badRequest,

  /// The server replied with 5xx.
  serverError,

  /// The response body could not be decoded (invalid JSON, missing
  /// `MediaContainer`, unexpected schema).
  parse,

  /// A precondition for the call was not met locally (e.g. calling a PMS
  /// endpoint before [PlexClient.connect]).
  state,

  /// Anything else.
  unknown;

  /// Whether the error is likely to succeed on retry.
  bool get isRetriable =>
      this == PlexErrorType.connection || this == PlexErrorType.timeout;

  /// Whether the error means the saved token is no longer valid.
  bool get isAuthError => this == PlexErrorType.auth;

  /// Classify an HTTP status code.
  static PlexErrorType fromHttpStatus(int status) {
    if (status == 401 || status == 403) return PlexErrorType.auth;
    if (status == 404) return PlexErrorType.notFound;
    if (status >= 500) return PlexErrorType.serverError;
    if (status >= 400) return PlexErrorType.badRequest;
    return PlexErrorType.unknown;
  }
}
