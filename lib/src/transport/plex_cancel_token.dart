// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import '../plex_client.dart';
import '../plex_error_type.dart';
import '../plex_exception.dart';

/// Cancels requests that are still in flight.
///
/// Pass one to [PlexClient.withCancelToken] to cancel every call made
/// through the returned view, or to a single [PlexClient.request].
/// A cancelled request throws a [PlexException] of type
/// [PlexErrorType.cancelled] — not a failure, so it is safe to ignore.
///
/// One token can cancel any number of requests, but only once: after
/// [cancel], every request that uses it fails immediately. Make a new token
/// for the next page, filter or search term.
///
/// ```dart
/// final token = PlexCancelToken();
/// final scoped = plex.withCancelToken(token);
/// final page = scoped.library.allByType(
///   sectionId: sectionId,
///   type: PlexMetadataType.album,
/// );
/// // The user left the page:
/// token.cancel();
/// ```
final class PlexCancelToken {
  final Completer<void> _cancelled = Completer<void>();
  Object? _reason;

  /// Creates a token that has not been cancelled yet.
  PlexCancelToken();

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled.isCompleted;

  /// The value passed to [cancel], if any.
  Object? get reason => _reason;

  /// Completes when [cancel] is called.
  Future<void> get whenCancelled => _cancelled.future;

  /// Cancels every request using this token. Later calls do nothing.
  void cancel([Object? reason]) {
    if (_cancelled.isCompleted) return;
    _reason = reason;
    _cancelled.complete();
  }
}
