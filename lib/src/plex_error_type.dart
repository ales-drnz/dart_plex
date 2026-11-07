// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'plex_client.dart';
import 'plex_exception.dart';
import 'transport/plex_cancel_token.dart';

/// Semantic categories for failures coming out of [PlexClient].
///
/// Used by [PlexException.type] so callers can decide whether to retry,
/// re-authenticate, or surface the error to the user.
///
/// {@category Errors and paging}
enum PlexErrorType {
  /// Transport-level failure (DNS resolution, TCP reset, broken pipe, no
  /// route to host). Usually retriable after a backoff.
  connection,

  /// The request did not complete within the configured timeout.
  timeout,

  /// The server replied with `401 Unauthorized`, `403 Forbidden` or
  /// `498` (plex.tv's "token expired", for a JWT), or a sign-in answered
  /// without a token. Callers should refresh the JWT or re-run the PIN or
  /// sign-in flow.
  auth,

  /// Playback or a transcode was refused because the account needs a
  /// Plex Pass or a Remote Watch Pass: since April 2025 a server owner
  /// without one cannot stream personal video to devices outside the
  /// server's network, and those devices' users cannot either unless
  /// they hold the pass themselves.
  ///
  /// Recognised by the streaming calls only, from what the answer says;
  /// PMS has no documented code for it, so the detection is a heuristic
  /// (see `PlexStreamingApi` and the Streaming topic). [PlexException.body]
  /// keeps the whole answer. Not an auth error: the token still works.
  passRequired,

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

  /// The request was cancelled by the caller via a [PlexCancelToken]
  /// before it completed. Not an error condition — distinct from [unknown] so callers
  /// can ignore cancellations instead of logging them as failures.
  cancelled,

  /// Anything else.
  unknown;

  /// Whether the error means the saved token is no longer valid.
  bool get isAuthError => this == PlexErrorType.auth;

  /// Classify an HTTP status code.
  static PlexErrorType fromHttpStatus(int status) {
    if (status == 401 || status == 403 || status == 498) {
      return PlexErrorType.auth;
    }
    if (status == 404) return PlexErrorType.notFound;
    if (status >= 500) return PlexErrorType.serverError;
    if (status >= 400) return PlexErrorType.badRequest;
    return PlexErrorType.unknown;
  }
}
