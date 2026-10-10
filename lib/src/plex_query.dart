// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Query-string helpers shared by the sub-APIs. Not exported.
library;

import 'plex_error_type.dart';
import 'plex_exception.dart';
import 'plex_filter.dart';

/// Fold [filters] into [qp], one query parameter per condition.
///
/// Two conditions on the same field *and* operator cannot both be
/// expressed — one would overwrite the other and the call would come back
/// wider than asked for — so that is refused loudly instead.
void applyFilters(Map<String, dynamic> qp, List<PlexFilter> filters) {
  for (final filter in filters) {
    final name = filter.parameterName;
    if (qp.containsKey(name)) {
      throw PlexException(
        'Two filters both send the "$name" query parameter; only one '
        'would survive. Combine their values into a single PlexFilter.',
        type: PlexErrorType.state,
      );
    }
    qp[name] = filter.parameterValue;
  }
}

/// `X-Plex-Container-Start` and `-Size` for a page; empty when [size] is
/// `null` (the whole list).
///
/// Both always travel together. PMS 1.43.2 pages only when it gets *both*
/// (verified on `/children`, `/allLeaves`, `/all`, `/playlists/{id}/items`):
/// `X-Plex-Container-Size=50` on its own is ignored and the whole list
/// comes back — a silent widening. So [start] defaults to 0, and a [start]
/// with no [size] is refused rather than sent to be ignored.
Map<String, dynamic> containerPage({int? start, int? size}) {
  if (size == null) {
    if (start != null) {
      throw ArgumentError.value(
        start,
        'start',
        'Plex pages only with a size; pass size too',
      );
    }
    return <String, dynamic>{};
  }
  return {'X-Plex-Container-Start': start ?? 0, 'X-Plex-Container-Size': size};
}
