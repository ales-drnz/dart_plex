// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

part of 'plex_account_api.dart';

/// The servers and devices of the account, and the connection that answers. Mixed into [PlexAccountApi].
mixin _PlexAccountDiscovery {
  PlexConnection get _http;
  Future<T> _plexTv<T>(
    String url,
    T Function(Object? json) parse, {
    String method = 'GET',
    Map<String, Object?>? query,
    String? token,
  });

  // -------------------------------------------------------------------------
  // Server discovery
  // -------------------------------------------------------------------------

  /// List the servers the account has access to
  /// (`GET plex.tv/api/v2/resources`).
  ///
  /// Pass `serverOnly = true` (default) to filter out player/client
  /// resources — i.e. keep only resources whose `provides` includes
  /// `'server'`. Use [PlexClient.connectToResource] to reach one.
  ///
  /// A resource's [PlexResource.accessToken] is the token for that server.
  /// For an owned server it can be the account token itself; what plex.tv
  /// hands out when the account token is a JWT is not documented — see
  /// [PlexClient.connectToResource] for the fallback when a server
  /// refuses it.
  Future<List<PlexResource>> fetchResources({
    bool includeHttps = true,
    bool includeRelay = true,
    bool includeIPv6 = true,
    bool serverOnly = true,
  }) async {
    final all = await _plexTv(
      '$_v2/resources',
      (json) => asObjectList(json, PlexResource.fromJson),
      query: {
        'includeHttps': includeHttps ? 1 : 0,
        'includeRelay': includeRelay ? 1 : 0,
        'includeIPv6': includeIPv6 ? 1 : 0,
      },
    );
    if (!serverOnly) return all;
    return all.where((r) => r.isServer).toList(growable: false);
  }

  /// The devices signed in to the account (`GET plex.tv/api/v2/devices`).
  ///
  /// Whether plex.tv lists a [PlexDevice.token] for each, and for which
  /// devices, is not documented; python-plexapi reads them from the older
  /// `plex.tv/devices.xml`. [PlexClient.connectToResource] uses this list
  /// as a fallback when a server refuses the token from [fetchResources].
  Future<List<PlexDevice>> devices() => _plexTv(
    '$_v2/devices',
    (json) => _list(json, 'Device', PlexDevice.fromJson),
  );

  /// The connection of [resource] to use: every one in
  /// [PlexResource.rankedConnections] is tried at once (`GET /identity`,
  /// which needs no token), and the best-ranked one that answers wins —
  /// without waiting for worse ones once it has. A connection counts only
  /// when its server reports the resource's machine identifier, so the
  /// token is never sent to another host that happens to answer.
  ///
  /// Returns `null` when none answers within [timeout]; when some
  /// answered but a better one was still pending, the best of those.
  Future<PlexServerConnection?> findConnection(
    PlexResource resource, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final ranked = resource.rankedConnections();
    if (ranked.isEmpty) return null;
    final cancel = PlexCancelToken();
    final answered = List<bool?>.filled(ranked.length, null);
    final done = Completer<PlexServerConnection?>();

    PlexServerConnection? best({required bool wait}) {
      for (var i = 0; i < ranked.length; i++) {
        final ok = answered[i];
        if (ok == true) return ranked[i];
        if (ok == null && wait) return null;
      }
      return null;
    }

    void settle() {
      if (done.isCompleted) return;
      final pick = best(wait: true);
      if (pick != null) {
        done.complete(pick);
      } else if (!answered.contains(null)) {
        done.complete(null);
      }
    }

    for (var i = 0; i < ranked.length; i++) {
      unawaited(
        _probe(ranked[i], resource.clientIdentifier, cancel).then((ok) {
          answered[i] = ok;
          settle();
        }),
      );
    }
    final timer = Timer(timeout, () {
      if (!done.isCompleted) done.complete(best(wait: false));
    });
    try {
      return await done.future;
    } finally {
      timer.cancel();
      cancel.cancel();
    }
  }

  Future<bool> _probe(
    PlexServerConnection connection,
    String machineIdentifier,
    PlexCancelToken cancel,
  ) async {
    try {
      final id = await _http.requestJson(
        '${connection.uri}/identity',
        _machineIdentifier,
        absoluteUrl: true,
        cancelToken: cancel,
        extraHeaders: const {'X-Plex-Token': ''},
      );
      return machineIdentifier.isEmpty || id == machineIdentifier;
    } on PlexException {
      return false;
    }
  }

  static String? _machineIdentifier(Object? json) {
    final id = mediaContainer(json)['machineIdentifier'];
    return id is String ? id : null;
  }

  /// The token [devices] lists for the server [machineIdentifier], or
  /// `null`.
  Future<String?> serverTokenFromDevices(String machineIdentifier) async {
    final all = await devices();
    for (final d in all) {
      if (d.clientIdentifier == machineIdentifier &&
          (d.token?.isNotEmpty ?? false)) {
        return d.token;
      }
    }
    return null;
  }
}
