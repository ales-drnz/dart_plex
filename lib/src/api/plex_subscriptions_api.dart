// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_client.dart';
import '../plex_connection.dart';

/// `/media/subscriptions/*` — DVR recording subscriptions.
///
/// Wraps the `Subscriptions` OpenAPI tag (10 operations). A
/// subscription is a recording rule: "record this show whenever it
/// airs", "record this single program", etc.
class PlexSubscriptionsApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.subscriptions].
  PlexSubscriptionsApi(this._http);

  /// `GET /media/subscriptions` — list every subscription.
  Future<Map<String, Object?>> list({
    bool includeGrabs = false,
    bool includeStorage = false,
  }) async {
    final res = await _http.request<Map<String, Object?>>(
      '/media/subscriptions',
      queryParameters: {
        'includeGrabs': includeGrabs ? 1 : 0,
        'includeStorage': includeStorage ? 1 : 0,
      },
    );
    return res.data ?? const {};
  }

  /// `POST /media/subscriptions` — create a new recording rule.
  ///
  /// [type] is the Plex metadata type to subscribe to (e.g. `2` for
  /// show/season), matching the spec's integer `type` parameter.
  /// [hints], [prefs] and [params] travel as `hints[key]=value` (and so
  /// on), the form PMS reads.
  Future<Map<String, Object?>> create({
    required int targetLibrarySectionID,
    int? targetSectionLocationID,
    int? type,
    Map<String, Object?>? hints,
    Map<String, Object?>? prefs,
    Map<String, Object?>? params,
  }) async {
    final qp = <String, Object?>{
      'targetLibrarySectionID': targetLibrarySectionID,
    };
    if (targetSectionLocationID != null) {
      qp['targetSectionLocationID'] = targetSectionLocationID;
    }
    if (type != null) qp['type'] = type;
    if (hints != null) qp['hints'] = hints;
    if (prefs != null) qp['prefs'] = prefs;
    if (params != null) qp['params'] = params;
    final res = await _http.request<Map<String, Object?>>(
      '/media/subscriptions',
      method: 'POST',
      queryParameters: qp,
    );
    return res.data ?? const {};
  }

  /// `POST /media/subscriptions/process` — re-evaluate every
  /// subscription against the current EPG (used after the guide
  /// reloads).
  Future<void> processAll() async {
    await _http.request<void>(
      '/media/subscriptions/process',
      method: 'POST',
    );
  }

  /// `GET /media/subscriptions/scheduled` — every recording the DVR
  /// plans to make, grouped by start time.
  Future<Map<String, Object?>> scheduledRecordings() async {
    final res = await _http.request<Map<String, Object?>>(
      '/media/subscriptions/scheduled',
    );
    return res.data ?? const {};
  }

  /// `GET /media/subscriptions/template?guid={guid}` — fetch the
  /// default subscription template for a program.
  Future<Map<String, Object?>> template({required String guid}) async {
    final res = await _http.request<Map<String, Object?>>(
      '/media/subscriptions/template',
      queryParameters: {'guid': guid},
    );
    return res.data ?? const {};
  }

  /// `GET /media/subscriptions/{subscriptionId}` — one subscription.
  Future<Map<String, Object?>> get(
    String subscriptionId, {
    bool includeGrabs = false,
    bool includeStorage = false,
  }) async {
    final res = await _http.request<Map<String, Object?>>(
      '/media/subscriptions/$subscriptionId',
      queryParameters: {
        'includeGrabs': includeGrabs ? 1 : 0,
        'includeStorage': includeStorage ? 1 : 0,
      },
    );
    return res.data ?? const {};
  }

  /// `PUT /media/subscriptions/{subscriptionId}?prefs[key]=value` — edit
  /// a subscription's preferences.
  Future<void> editPreferences({
    required String subscriptionId,
    Map<String, Object?>? prefs,
  }) async {
    final qp = <String, Object?>{};
    if (prefs != null) qp['prefs'] = prefs;
    await _http.request<void>(
      '/media/subscriptions/$subscriptionId',
      method: 'PUT',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// `DELETE /media/subscriptions/{subscriptionId}` — cancel a
  /// subscription (the recordings already on disk stay).
  Future<void> delete(String subscriptionId) async {
    await _http.request<void>(
      '/media/subscriptions/$subscriptionId',
      method: 'DELETE',
    );
  }

  /// `PUT /media/subscriptions/{subscriptionId}/move?after={otherId}`
  /// — reorder a subscription against its peers (order matters for
  /// conflict resolution).
  ///
  /// Pass [after] to place this subscription immediately after the
  /// subscription with that id. Omit it to insert at the beginning of
  /// the list.
  Future<void> reorder({
    required String subscriptionId,
    String? after,
  }) async {
    await _http.request<void>(
      '/media/subscriptions/$subscriptionId/move',
      method: 'PUT',
      queryParameters: after != null ? {'after': after} : null,
    );
  }

  /// `DELETE /media/grabbers/operations/{operationId}` — cancel an
  /// in-flight grab (i.e. abort a recording that is currently
  /// happening).
  Future<void> cancelGrab(String operationId) async {
    await _http.request<void>(
      '/media/grabbers/operations/$operationId',
      method: 'DELETE',
    );
  }
}
