// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../plex_connection.dart';

/// `/media/subscriptions/*` — DVR recording subscriptions.
///
/// Wraps the `Subscriptions` OpenAPI tag (10 operations). A
/// subscription is a recording rule: "record this show whenever it
/// airs", "record this single program", etc.
class PlexSubscriptionsApi {
  final PlexConnection _http;

  PlexSubscriptionsApi(this._http);

  /// `GET /media/subscriptions` — list every subscription.
  Future<Map<String, dynamic>> list({
    bool includeGrabs = false,
    bool includeStorage = false,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/media/subscriptions',
      queryParameters: {
        'includeGrabs': includeGrabs ? 1 : 0,
        'includeStorage': includeStorage ? 1 : 0,
      },
    );
    return res.data ?? const {};
  }

  /// `POST /media/subscriptions` — create a new recording rule.
  Future<Map<String, dynamic>> create({
    required int targetLibrarySectionID,
    int? targetSectionLocationID,
    String? type,
    Map<String, dynamic>? hints,
    Map<String, dynamic>? prefs,
    Map<String, dynamic>? params,
  }) async {
    final qp = <String, dynamic>{
      'targetLibrarySectionID': targetLibrarySectionID,
    };
    if (targetSectionLocationID != null) {
      qp['targetSectionLocationID'] = targetSectionLocationID;
    }
    if (type != null) qp['type'] = type;
    if (hints != null) qp['hints'] = hints;
    if (prefs != null) qp['prefs'] = prefs;
    if (params != null) qp['params'] = params;
    final res = await _http.request<Map<String, dynamic>>(
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
  Future<Map<String, dynamic>> scheduledRecordings() async {
    final res = await _http.request<Map<String, dynamic>>(
      '/media/subscriptions/scheduled',
    );
    return res.data ?? const {};
  }

  /// `GET /media/subscriptions/template?guid={guid}` — fetch the
  /// default subscription template for a program.
  Future<Map<String, dynamic>> template({required String guid}) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/media/subscriptions/template',
      queryParameters: {'guid': guid},
    );
    return res.data ?? const {};
  }

  /// `GET /media/subscriptions/{subscriptionId}` — one subscription.
  Future<Map<String, dynamic>> get(
    String subscriptionId, {
    bool includeGrabs = false,
    bool includeStorage = false,
  }) async {
    final res = await _http.request<Map<String, dynamic>>(
      '/media/subscriptions/$subscriptionId',
      queryParameters: {
        'includeGrabs': includeGrabs ? 1 : 0,
        'includeStorage': includeStorage ? 1 : 0,
      },
    );
    return res.data ?? const {};
  }

  /// `PUT /media/subscriptions/{subscriptionId}?prefs={...}` — edit
  /// a subscription's preferences.
  Future<void> editPreferences({
    required String subscriptionId,
    Map<String, dynamic>? prefs,
  }) async {
    final qp = <String, dynamic>{};
    if (prefs != null) qp.addAll(prefs);
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
  Future<void> reorder({
    required String subscriptionId,
    required String after,
  }) async {
    await _http.request<void>(
      '/media/subscriptions/$subscriptionId/move',
      method: 'PUT',
      queryParameters: {'after': after},
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
