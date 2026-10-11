// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'plex_error_type.dart';
import 'plex_exception.dart';
import 'plex_models.dart';

/// How a [PlexFilter] compares its values against its field.
///
/// Plex has no separate operator parameter. The operator is a suffix on
/// the query-parameter *name*, sitting between the field and the `=`
/// that introduces the value — `genre=6`, `year>>=2009`, `genre!=6`.
/// [wire] is that suffix.
///
/// Which operators a field accepts depends on the field's
/// [PlexFilterValueType]. The pinned spec gives the full set as
/// `=, !=, ==, !==, <=, >=, >>=, <<=` and notes that it "varies by
/// field type"; the variants below are the ones this package models.
enum PlexFilterOperator {
  /// `=` — is, on tag and numeric fields. On a free-text field such as
  /// `title` the server reads it as "contains".
  matches(''),

  /// `!=` — the negation of [matches].
  doesNotMatch('!'),

  /// `>>=` — strictly greater than. Numeric and date fields.
  greaterThan('>>'),

  /// `<<=` — strictly less than. Numeric and date fields.
  lessThan('<<'),

  /// `==` — whole-value equality on a free-text field, where [matches]
  /// would match a substring.
  isExactly('='),

  /// `!==` — the negation of [isExactly].
  isNotExactly('!=');

  /// Suffix appended to the field name to form the query-parameter
  /// name. Empty for [matches], whose parameter name is the bare field.
  final String wire;

  const PlexFilterOperator(this.wire);
}

/// One condition in a library filter.
///
/// Plex filters are ordinary query parameters named after the field
/// being filtered, with the operator baked into the name:
/// `?genre=6&year>>=2009` means "genre is tag 6 AND released after
/// 2009". There is no `filter` parameter — Plex silently ignores query
/// parameters it does not recognise, so a wrongly-named filter returns
/// 200 with the *unfiltered* result set.
///
/// Pass a list of these to [PlexLibraryApi.allByType] or
/// [PlexLibraryApi.countByType]. Conditions in the list are ANDed;
/// several [values] inside one condition are ORed.
///
/// ```dart
/// final genres = await plex.library.genres(
///   sectionId: musicLib.id,
///   type: PlexMetadataType.album,
/// );
/// final rock = genres.firstWhere((g) => g.title == 'Rock');
///
/// final page = await plex.library.allByType(
///   sectionId: musicLib.id,
///   type: PlexMetadataType.album,
///   filters: [PlexFilter.of(rock), PlexFilter.yearAfter(2009)],
/// );
/// ```
///
/// Which fields a section accepts is a property of the section, not of
/// this package — ask the server with [PlexLibraryApi.filters] and read
/// [PlexLibraryFilter.field].
final class PlexFilter {
  /// Field being filtered, exactly as Plex names it on the wire:
  /// `genre`, `year`, `unwatched`, `userRating`.
  final String field;

  /// How [values] is compared against [field].
  final PlexFilterOperator operator;

  /// Values for this condition. More than one means "any of" — they
  /// travel comma-separated, which Plex reads as OR.
  final List<String> values;

  /// Creates a condition directly.
  ///
  /// Prefer the named constructors below; reach for this one when the
  /// field you need is not among them (the vocabulary is per-section —
  /// see [PlexLibraryApi.filters]).
  const PlexFilter({
    required this.field,
    required this.values,
    this.operator = PlexFilterOperator.matches,
  });

  /// Condition selecting [tag] — the genre, mood or style row a user
  /// picked.
  ///
  /// Both the field name and the id come from the server, so neither is
  /// spelled by hand. This is the constructor to reach for after
  /// [PlexLibraryApi.genres] or [PlexLibraryApi.filterValues].
  ///
  /// Throws a [PlexException] of type [PlexErrorType.parse] when the
  /// tag carries no id the server would accept ([PlexTag.id] is null).
  factory PlexFilter.of(PlexTag tag) {
    final id = tag.id;
    if (id == null) {
      throw PlexException(
        'Tag "${tag.title}" carries no filterable id '
        '(key=${tag.key}, fastKey=${tag.fastKey}).',
        type: PlexErrorType.parse,
      );
    }
    return PlexFilter(field: tag.field, values: ['$id']);
  }

  /// Tag-valued field — `genre`, `mood`, `style`, `collection`,
  /// `label`, `country`.
  ///
  /// [tagIds] are ids as reported by [PlexTag.id]; passing several
  /// matches any of them. Set [exclude] to invert the condition.
  ///
  /// Tag fields are filtered by numeric id, never by display name.
  factory PlexFilter.tag(
    String field,
    List<int> tagIds, {
    bool exclude = false,
  }) =>
      PlexFilter(
        field: field,
        operator: exclude
            ? PlexFilterOperator.doesNotMatch
            : PlexFilterOperator.matches,
        values: [for (final id in tagIds) '$id'],
      );

  /// The `genre` field, by tag id — `?genre={tagId}`.
  ///
  /// The id is [PlexTag.id] from [PlexLibraryApi.genres], not the genre
  /// name.
  factory PlexFilter.genre(int tagId, {bool exclude = false}) =>
      PlexFilter.tag('genre', [tagId], exclude: exclude);

  /// Numeric field compared with [operator], which defaults to equality.
  factory PlexFilter.number(
    String field,
    num value, {
    PlexFilterOperator operator = PlexFilterOperator.matches,
  }) =>
      PlexFilter(field: field, operator: operator, values: ['$value']);

  /// Released in exactly [year] — `?year={year}`.
  factory PlexFilter.year(int year) => PlexFilter.number('year', year);

  /// Released after [year], exclusive — `?year>>={year}`.
  factory PlexFilter.yearAfter(int year) =>
      PlexFilter.number('year', year, operator: PlexFilterOperator.greaterThan);

  /// Released before [year], exclusive — `?year<<={year}`.
  factory PlexFilter.yearBefore(int year) =>
      PlexFilter.number('year', year, operator: PlexFilterOperator.lessThan);

  /// User rating strictly above [rating] on Plex's 0..10 scale —
  /// `?userRating>>={rating}`.
  factory PlexFilter.ratingAbove(num rating) => PlexFilter.number(
        'userRating',
        rating,
        operator: PlexFilterOperator.greaterThan,
      );

  /// Everything the user has rated at all — `?userRating>>=0`.
  ///
  /// Music UIs that treat a full 10 as "favourite" (see
  /// [PlexMetadata.isFavorite]) want `PlexFilter.ratingAbove(9)`
  /// instead.
  factory PlexFilter.rated() => PlexFilter.ratingAbove(0);

  /// Free-text field compared with [operator], which defaults to the
  /// server's substring match.
  factory PlexFilter.text(
    String field,
    String value, {
    PlexFilterOperator operator = PlexFilterOperator.matches,
  }) =>
      PlexFilter(field: field, operator: operator, values: [value]);

  /// Titles containing [text] — `?title={text}`.
  factory PlexFilter.titleContains(String text) =>
      PlexFilter.text('title', text);

  /// Titles equal to [text] — `?title=={text}`.
  factory PlexFilter.titleIs(String text) => PlexFilter.text(
        'title',
        text,
        operator: PlexFilterOperator.isExactly,
      );

  /// Titles starting with [character] — the A-Z scrubber bucket.
  ///
  /// [PlexLibraryApi.firstCharacters] lists the buckets a section has.
  factory PlexFilter.firstCharacter(String character) =>
      PlexFilter.text('firstCharacter', character);

  /// The `studio` field — `?studio={studio}`.
  factory PlexFilter.studio(String studio) => PlexFilter.text('studio', studio);

  /// The `contentRating` field, e.g. `PG-13`.
  factory PlexFilter.contentRating(String rating) =>
      PlexFilter.text('contentRating', rating);

  /// The `resolution` field, e.g. `1080`, `4k`.
  factory PlexFilter.resolution(String resolution) =>
      PlexFilter.text('resolution', resolution);

  /// Boolean field, sent as the `1` / `0` Plex uses for flags (the
  /// spec's `BoolInt`) rather than `true` / `false`.
  factory PlexFilter.flag(String field, {bool value = true}) =>
      PlexFilter(field: field, values: [value ? '1' : '0']);

  /// Items the user has never played — `?unwatched=1`.
  factory PlexFilter.unplayed() => PlexFilter.flag('unwatched');

  /// Items the user has played at least once — `?unwatched=0`.
  ///
  /// The pinned spec does not declare this flag on the browse route at
  /// all, so both sides of it rest on observed behaviour: against PMS
  /// 1.43.2 the two partition a section exactly, and marking one of
  /// three tracks played moves it from one bucket to the other.
  factory PlexFilter.played() => PlexFilter.flag('unwatched', value: false);

  /// Query-parameter name this condition sends — [field] followed by
  /// [PlexFilterOperator.wire].
  String get parameterName => '$field${operator.wire}';

  /// Query-parameter value this condition sends — [values] joined with
  /// `,`, which Plex reads as "any of".
  String get parameterValue => values.join(',');

  @override
  String toString() => '$parameterName=$parameterValue';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PlexFilter) return false;
    if (other.field != field || other.operator != operator) return false;
    if (other.values.length != values.length) return false;
    for (var i = 0; i < values.length; i++) {
      if (other.values[i] != values[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(field, operator, Object.hashAll(values));
}
