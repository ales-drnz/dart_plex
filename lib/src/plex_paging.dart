// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Walk a paged endpoint page by page.
///
/// ```dart
/// final tracks = PlexPaging.items(
///   (start, size) => plex.library.grandchildren(
///     ratingKey: artistKey,
///     start: start,
///     size: size,
///   ),
/// );
/// ```
abstract final class PlexPaging {
  /// Pages of a list endpoint, fetched one after the other as the stream
  /// is listened to.
  ///
  /// [fetch] reads one page: the rows from [start], at most `size` of
  /// them. Paging stops at the first page shorter than [pageSize] (the
  /// server has no more), or once [limit] rows have been delivered.
  /// Cancelling the subscription stops it before the next request; pair
  /// it with a cancel token to drop the request in flight too.
  ///
  /// Each call costs one request; nothing is fetched ahead. When the
  /// total is an exact multiple of [pageSize] the last request comes back
  /// empty: a page cannot tell that it was the last one.
  static Stream<List<T>> pages<T>(
    Future<List<T>> Function(int start, int size) fetch, {
    int pageSize = 100,
    int start = 0,
    int? limit,
  }) async* {
    if (pageSize <= 0) {
      throw ArgumentError.value(pageSize, 'pageSize', 'must be positive');
    }
    var offset = start;
    var delivered = 0;
    while (limit == null || delivered < limit) {
      final want = limit == null
          ? pageSize
          : (limit - delivered < pageSize ? limit - delivered : pageSize);
      final page = await fetch(offset, want);
      if (page.isEmpty) return;
      yield page;
      delivered += page.length;
      offset += page.length;
      if (page.length < want) return;
    }
  }

  /// Every row of a list endpoint, one by one; see [pages].
  static Stream<T> items<T>(
    Future<List<T>> Function(int start, int size) fetch, {
    int pageSize = 100,
    int start = 0,
    int? limit,
  }) =>
      pages(fetch, pageSize: pageSize, start: start, limit: limit)
          .expand((page) => page);
}
