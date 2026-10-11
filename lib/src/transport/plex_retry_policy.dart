// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:math';

import '../plex_exception.dart';

/// When and how often to resend a request that failed transiently.
///
/// Off by default ([none]). Pass one as `retryPolicy` to the client to turn
/// it on:
///
/// ```dart
/// final client = PlexClient(
///   credentials: credentials,
///   retryPolicy: const PlexRetryPolicy(),
/// );
/// ```
///
/// Only idempotent requests are resent — `GET` and `HEAD` — and only after
/// a failure that another attempt can fix: no answer (connection lost,
/// timeout), `502`, `503`, `504` or `429`. A `500` is not retried: it is
/// usually the server failing the same way every time. A `Retry-After`
/// header is honoured up to [maxDelay]. The wait between attempts grows
/// exponentially from [initialDelay] with full jitter, and a cancel token
/// cancels the wait too.
final class PlexRetryPolicy {
  /// How many times a request is sent at most, the first time included.
  /// `1` never retries.
  final int maxAttempts;

  /// The base of the backoff: attempt *n* waits a random time up to
  /// `initialDelay × 2^(n-1)`, capped at [maxDelay].
  final Duration initialDelay;

  /// The longest single wait, `Retry-After` included.
  final Duration maxDelay;

  /// Creates a policy; the defaults resend up to twice, waiting at most
  /// 0.3 s and then 0.6 s (plus jitter), never more than 5 s.
  const PlexRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 5),
  }) : assert(maxAttempts >= 1, 'maxAttempts counts the first attempt');

  /// Never retry.
  static const none = PlexRetryPolicy(maxAttempts: 1);

  static final Random _random = Random();

  /// The wait before attempt [attempt] + 1 after [error], or `null` when
  /// the request must not be resent.
  Duration? delayAfter(
    PlexException error, {
    required int attempt,
    required String method,
  }) {
    if (attempt >= maxAttempts) return null;
    final m = method.toUpperCase();
    if (m != 'GET' && m != 'HEAD') return null;
    final status = error.statusCode;
    final retriable = error.isNetworkFailure ||
        status == 502 ||
        status == 503 ||
        status == 504 ||
        status == 429;
    if (!retriable) return null;
    final hinted = error.retryAfter;
    if (hinted != null) return hinted > maxDelay ? maxDelay : hinted;
    // Capped exponent: 2^30 × any sane initial delay is past maxDelay, and
    // a larger power would overflow.
    final ceiling = initialDelay * pow(2, min(attempt - 1, 30)).toInt();
    final capped = ceiling > maxDelay ? maxDelay : ceiling;
    return Duration(
      microseconds: (_random.nextDouble() * capped.inMicroseconds).round(),
    );
  }
}
