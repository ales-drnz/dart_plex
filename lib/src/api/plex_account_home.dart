// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of 'plex_account_api.dart';

/// Plex Home, shared users, the watchlist and GeoIP. Mixed into [PlexAccountApi].
mixin _PlexAccountHome {
  Future<T> _plexTv<T>(
    String url,
    T Function(Object? json) parse, {
    String method = 'GET',
    Map<String, Object?>? query,
    String? token,
  });

  // -------------------------------------------------------------------------
  // Plex Home, friends and sharing
  // -------------------------------------------------------------------------

  /// The members of the account's Plex Home (`GET plex.tv/api/home/users`,
  /// as python-plexapi reads it; plex.tv answers it in XML).
  Future<List<PlexHomeUser>> homeUsers() => _plexTv(
    '$_plexTvLegacy/api/home/users',
    (json) => _list(json, 'User', PlexHomeUser.fromJson),
  );

  /// The managed users of the Home: [homeUsers] that are
  /// [PlexHomeUser.restricted].
  Future<List<PlexHomeUser>> managedUsers() async => [
    for (final u in await homeUsers())
      if (u.restricted) u,
  ];

  /// Switch to the Home member [userId]
  /// (`POST plex.tv/api/home/users/{id}/switch`), with their [pin] when
  /// they have one.
  ///
  /// Returns that user, whose [PlexUser.authToken] is their own plex.tv
  /// token — a legacy token, as far as is known: python-plexapi reads it
  /// from the same route. Apply it with [PlexClient.setAccountToken] (and
  /// fetch the servers again: they come with that user's tokens).
  Future<PlexUser> switchHomeUser({required int userId, String? pin}) async {
    final user = await _plexTv(
      '$_plexTvLegacy/api/home/users/$userId/switch',
      (json) => PlexUser.fromJson(_object(json)),
      method: 'POST',
      query: {'pin': ?pin},
    );
    if (user.authToken.isEmpty) {
      throw const PlexException(
        'The switch answered no token for the user',
        type: PlexErrorType.auth,
      );
    }
    return user;
  }

  /// The users the account shares servers with, or shares a Home with,
  /// each with the servers shared (`GET plex.tv/api/users/`, python-plexapi's
  /// `MyPlexAccount.users()`; XML).
  Future<List<PlexAccountUser>> connectedUsers() => _plexTv(
    '$_plexTvLegacy/api/users/',
    (json) => _list(json, 'User', PlexAccountUser.fromJson),
  );

  /// The account's friends (`GET plex.tv/api/v2/friends`).
  ///
  /// plex.tv removed this endpoint: it answers `410 Gone`, as do
  /// `plex.tv/api/friends/all` and `clients.plex.tv/api/v2/friends`
  /// (verified in November 2026), so this throws a [PlexException] with
  /// that status. No REST route lists friends any more; the closest is
  /// [connectedUsers], the users the account shares servers or a Home
  /// with.
  @Deprecated(
    'plex.tv removed this endpoint (410 Gone): use connectedUsers() for '
    'the users servers are shared with. Will be removed in 0.4.0.',
  )
  Future<List<PlexFriend>> friends() => _plexTv(
    '$_v2/friends',
    (json) => switch (json) {
      final List<Object?> list => asObjectList(list, PlexFriend.fromJson),
      _ => _list(json, 'users', PlexFriend.fromJson),
    },
  );

  // -------------------------------------------------------------------------
  // Watchlist (discover provider)
  // -------------------------------------------------------------------------

  /// The user's watchlist, from Plex's online metadata
  /// (`GET discover.provider.plex.tv/library/sections/watchlist/{filter}`).
  ///
  /// The items are plex.tv metadata, not a server's: their
  /// [PlexMetadata.guid] (`plex://movie/…`) finds the same item on a
  /// server (`PlexFilter.text('guid', guid)`), and [PlexAccountApi.discoverKeyOf] gives
  /// the key [addToWatchlist] takes. [sort] takes
  /// [PlexSort.watchlistedAt], [PlexSort.titleSort],
  /// [PlexSort.originallyAvailableAt] or [PlexSort.rating]; [type] narrows
  /// to [PlexMetadataType.movie] or [PlexMetadataType.show].
  Future<PlexMediaContainer<PlexMetadata>> watchlist({
    PlexWatchlistFilter filter = PlexWatchlistFilter.all,
    PlexSort? sort,
    PlexMetadataType? type,
    int start = 0,
    int size = 50,
  }) async => _plexTv(
    '$_discover/library/sections/watchlist/${filter.name}',
    (json) => PlexMediaContainer.fromJson(
      _object(json),
      'Metadata',
      PlexMetadata.fromJson,
    ),
    query: {
      'includeCollections': 1,
      'includeExternalMedia': 1,
      'sort': ?sort,
      'type': ?type?.value,
      ...containerPage(start: start, size: size),
    },
  );

  /// Add the item with discover key [ratingKey] to the watchlist
  /// (`PUT discover.provider.plex.tv/actions/addToWatchlist`, as
  /// python-plexapi sends it). See [PlexAccountApi.discoverKeyOf].
  Future<void> addToWatchlist({required String ratingKey}) => _plexTv<void>(
    '$_discover/actions/addToWatchlist',
    (_) {},
    method: 'PUT',
    query: {'ratingKey': ratingKey},
  );

  /// Remove it (`PUT …/actions/removeFromWatchlist`).
  Future<void> removeFromWatchlist({required String ratingKey}) =>
      _plexTv<void>(
        '$_discover/actions/removeFromWatchlist',
        (_) {},
        method: 'PUT',
        query: {'ratingKey': ratingKey},
      );

  // -------------------------------------------------------------------------
  // GeoIP
  // -------------------------------------------------------------------------

  /// Where [ipAddress] is (`GET plex.tv/api/v2/geoip`), or where this
  /// device's public address is when it is omitted.
  Future<PlexGeoLocation> geoip({String? ipAddress}) => _plexTv(
    '$_v2/geoip',
    (json) => PlexGeoLocation.fromJson(_object(json)),
    query: {'ip_address': ?ipAddress},
  );
}
