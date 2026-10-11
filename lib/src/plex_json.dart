// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Lenient readers for the JSON PMS sends, shared by every model. Not
/// exported.
///
/// PMS is loose with types — a number can come back as a string, a flag as
/// `1` or `"1"` — so each reader takes whatever arrived and answers `null`
/// (or `false`, an empty list) for anything it cannot read.
library;

/// A string, or the [Object.toString] of anything else.
String? asString(Object? v) => v == null ? null : '$v';

/// An int, from an int, a double (truncated) or a numeric string.
int? asInt(Object? v) => switch (v) {
      int() => v,
      double() => v.toInt(),
      String() => int.tryParse(v),
      _ => null,
    };

/// A double, from a double, an int or a numeric string.
double? asDouble(Object? v) => switch (v) {
      double() => v,
      int() => v.toDouble(),
      String() => double.tryParse(v),
      _ => null,
    };

/// `true` for `true`, `1` and `"1"`.
bool asBool(Object? v) => v == true || v == 1 || v == '1';

/// An ISO-8601 timestamp, in UTC.
DateTime? asUtcDateTime(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toUtc() : null;

/// A `YYYY-MM-DD` calendar date as UTC midnight; tolerant of a full
/// timestamp.
DateTime? asCalendarDate(Object? v) {
  if (v is! String || v.isEmpty) return null;
  final d = DateTime.tryParse(v);
  if (d == null) return null;
  return d.isUtc ? d : DateTime.utc(d.year, d.month, d.day);
}

/// Seconds since the epoch, in UTC.
DateTime? asEpochSeconds(Object? v) {
  final s = asInt(v);
  return s == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);
}

/// The `tag` of each `{tag: …}` entry of a tag array (`Genre`, `Mood`,
/// `Role`, …).
List<String> tagNames(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is Map && e['tag'] is String) e['tag'] as String,
    ];
