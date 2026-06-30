// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:test/test.dart';

import '_helpers/spec_coverage.dart';
import '_helpers/spec_watchdog.dart';

/// Two informational checks that run on every `dart test`:
///
/// 1. **Upstream drift**: compare the pinned Plex OpenAPI spec
///    against the community spec at
///    <https://github.com/LukeHagar/plex-api-spec>. Reports
///    added/removed endpoints.
/// 2. **Local coverage**: approximate static count of how many spec
///    paths the library references in `lib/src/api/`. Lossy by
///    design — a sudden drop is the signal worth investigating.
///
/// Upstream drift stays informational. Two floors are enforced: a
/// sanity floor on the pinned-spec op count (guards against a corrupted
/// or truncated `docs/plex-api-spec.yaml` silently parsing to zero ops)
/// and a local-coverage floor (fails the suite if a refactor removes a
/// meaningful chunk of the typed wrappers). Real correctness is still
/// enforced by the integration tests in
/// `test/integration/`, which exercise the library against a real Plex
/// Media Server in Docker.
void main() {
  test(
    'upstream Plex spec drift + local coverage (informational)',
    () async {
      final report = await runPlexSpecWatchdog();
      // ignore: avoid_print
      print(report.render());

      // Sanity floor: the pinned spec is read from disk unconditionally
      // (independent of network availability). If it ever parses to far
      // fewer ops than the vendored spec actually contains, the pinned
      // `docs/plex-api-spec.yaml` is likely corrupted, truncated, or its
      // structure changed — otherwise the watchdog would silently report
      // "up to date (0 ops)".
      expect(
        report.pinnedCount,
        greaterThan(200),
        reason: 'pinned Plex spec parsed to too few ops (have 241) — '
            'likely corrupted or schema changed',
      );

      final cov = computePlexLocalCoverage();
      final ratio = cov.total == 0 ? 0.0 : cov.matched / cov.total;
      final pct = ratio * 100;
      // ignore: avoid_print
      print(
        'ℹ Local static coverage: ${cov.matched}/${cov.total} spec paths '
        'referenced in lib/src/api/ (~${pct.toStringAsFixed(0)}%, approximate)',
      );

      // Local coverage is a real regression tripwire (not just printed):
      // removing a meaningful chunk of the typed wrappers drops this ratio
      // below the committed floor and fails CI — the "sudden drop is the
      // signal" mechanism the docstring promises.
      expect(
        ratio,
        greaterThan(plexLocalCoverageFloor),
        reason:
            'local static coverage (${cov.matched}/${cov.total}) fell below '
            'the $plexLocalCoverageFloor floor — typed API wrappers may have '
            'been removed; if intentional, update plexLocalCoverageFloor in '
            'test/_helpers/spec_coverage.dart',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
