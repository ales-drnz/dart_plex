// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Lenient readers for the JSON PMS sends, shared by every model. Not
/// exported.
///
/// PMS is loose with types — a number can come back as a string, a flag as
/// `1` or `"1"` — so each reader takes whatever arrived and answers `null`
/// (or `false`, an empty list) for anything it cannot read. None throws.
library;

/// A string, or the [Object.toString] of anything else.
String? asString(Object? v) => v == null ? null : '$v';

/// An int, from an int, a finite double (truncated) or a numeric string
/// (`"12"`, and `"12.0"` as the double would be).
int? asInt(Object? v) => switch (v) {
  int() => v,
  double() => v.isFinite ? v.toInt() : null,
  String() => int.tryParse(v) ?? asInt(double.tryParse(v)),
  _ => null,
};

/// A double, from a double, an int or a numeric string.
double? asDouble(Object? v) => switch (v) {
  double() => v,
  int() => v.toDouble(),
  String() => double.tryParse(v),
  _ => null,
};

/// `true` for `true`, `1`, `"1"` and `"true"` (plex.tv's XML routes
/// write flags as words); `false` for anything else.
bool asBool(Object? v) => v == true || v == 1 || v == '1' || v == 'true';

/// An ISO-8601 timestamp, in UTC. One without a zone is read as UTC, not
/// as this device's local time: a server does not know the device's zone
/// (plex.tv's v2 routes write `Z`; its legacy XML writes
/// `2024-01-02 03:04:05 UTC`, read too).
DateTime? asUtcDateTime(Object? v) {
  if (v is! String) return null;
  var s = v.trim();
  if (s.endsWith(' UTC')) s = '${s.substring(0, s.length - 4)}Z';
  final d = DateTime.tryParse(s);
  if (d == null || d.isUtc) return d;
  return DateTime.utc(
    d.year,
    d.month,
    d.day,
    d.hour,
    d.minute,
    d.second,
    d.millisecond,
    d.microsecond,
  );
}

/// A `YYYY-MM-DD` calendar date as UTC midnight; tolerant of a full
/// timestamp.
DateTime? asCalendarDate(Object? v) {
  if (v is! String || v.isEmpty) return null;
  final d = DateTime.tryParse(v);
  if (d == null) return null;
  return d.isUtc ? d : DateTime.utc(d.year, d.month, d.day);
}

/// Seconds since the epoch, in UTC; `null` for a value outside
/// [DateTime]'s range.
DateTime? asEpochSeconds(Object? v) {
  final s = asInt(v);
  // DateTime holds 8.64e15 ms either side of the epoch.
  if (s == null || s.abs() > 8640000000000) return null;
  return DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);
}

/// The `MediaContainer` of [json], or [json] itself when it has none (a
/// plex.tv answer, an entry already unwrapped). Empty for anything that
/// is not a JSON object.
Map<String, Object?> mediaContainer(Object? json) {
  if (json is! Map<String, Object?>) return const {};
  final c = json['MediaContainer'];
  return c is Map<String, Object?> ? c : json;
}

/// The objects of a JSON array, each read by [parser]; anything else in it
/// is skipped.
List<T> asObjectList<T>(Object? v, T Function(Map<String, Object?>) parser) => [
  if (v is List)
    for (final e in v)
      if (e is Map<String, Object?>) parser(e),
];

/// [v] itself when it is a JSON object, its first element when it is a
/// list starting with one (the XML shape of a single child); else `null`.
Map<String, Object?>? asObject(Object? v) => switch (v) {
  final Map<String, Object?> m => m,
  [final Map<String, Object?> m, ...] => m,
  _ => null,
};

/// The entries of a comma-separated string (`"server,player"`), trimmed,
/// the empty ones dropped.
List<String> asCsv(Object? v) => (asString(v) ?? '')
    .split(',')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList(growable: false);

/// The `tag` of each `{tag: …}` entry of a tag array (`Genre`, `Mood`,
/// `Role`, …).
List<String> tagNames(Object? v) => [
  if (v is List)
    for (final e in v)
      if (e is Map && e['tag'] is String) e['tag'] as String,
];
