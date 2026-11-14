// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import '../parsing/plex_json.dart';
import '../parsing/plex_parsing.dart';
import '../plex_client.dart';
import '../plex_connection.dart';
import '../plex_models.dart';
import '../plex_urls.dart';

/// `/media/subscriptions/*` — DVR recording subscriptions.
///
/// Wraps the `Subscriptions` OpenAPI tag (10 operations). A
/// subscription is a recording rule: "record this show whenever it
/// airs", "record this single program", etc.
///
/// {@category Live TV}
class PlexSubscriptionsApi {
  final PlexConnection _http;

  /// Construct from a [PlexConnection]. Typically obtained via [PlexClient.subscriptions].
  PlexSubscriptionsApi(this._http);

  /// `GET /media/subscriptions` — every subscription; with
  /// [includeGrabs] their recordings, with [includeStorage] the space
  /// they use.
  Future<List<PlexMediaSubscription>> list({
    bool includeGrabs = false,
    bool includeStorage = false,
  }) => _http.requestJson(
    '/media/subscriptions',
    entriesOf('MediaSubscription', PlexMediaSubscription.fromJson),
    queryParameters: {
      'includeGrabs': includeGrabs ? 1 : 0,
      'includeStorage': includeStorage ? 1 : 0,
    },
  );

  /// `POST /media/subscriptions` — create a new recording rule.
  ///
  /// [type] is the Plex metadata type to subscribe to (e.g. `2` for
  /// show/season), matching the spec's integer `type` parameter.
  /// [hints], [prefs] and [params] travel as `hints[key]=value` (and so
  /// on), the form PMS reads.
  ///
  /// Returns the subscription created, or `null` when the answer holds
  /// none. Unlike the other creates it does not throw then: what PMS
  /// answers here is not verified.
  Future<PlexMediaSubscription?> create({
    required int targetLibrarySectionID,
    int? targetSectionLocationID,
    int? type,
    Map<String, Object?>? hints,
    Map<String, Object?>? prefs,
    Map<String, Object?>? params,
  }) => _http.requestJson(
    '/media/subscriptions',
    firstOf('MediaSubscription', PlexMediaSubscription.fromJson),
    method: 'POST',
    queryParameters: {
      'targetLibrarySectionID': targetLibrarySectionID,
      'targetSectionLocationID': ?targetSectionLocationID,
      'type': ?type,
      'hints': ?hints,
      'prefs': ?prefs,
      'params': ?params,
    },
  );

  /// `POST /media/subscriptions/process` — re-evaluate every
  /// subscription against the current EPG (used after the guide
  /// reloads).
  Future<void> processAll() async {
    await _http.request<void>('/media/subscriptions/process', method: 'POST');
  }

  /// `GET /media/subscriptions/scheduled` — every recording the DVR
  /// plans to make.
  Future<List<PlexMediaGrabOperation>> scheduledRecordings() =>
      _http.requestJson(
        '/media/subscriptions/scheduled',
        entriesOf('MediaGrabOperation', PlexMediaGrabOperation.fromJson),
      );

  /// `GET /media/subscriptions/template?guid={guid}` — the subscriptions
  /// the server proposes for a program: one per way of recording it
  /// (this airing, the whole show, …), each with its default settings.
  Future<List<PlexMediaSubscription>> template({required String guid}) =>
      _http.requestJson(
        '/media/subscriptions/template',
        _templates,
        queryParameters: {'guid': guid},
      );

  /// `SubscriptionTemplate[].MediaSubscription[]`, flattened.
  static List<PlexMediaSubscription> _templates(Object? json) {
    final templates = mediaContainer(json)['SubscriptionTemplate'];
    return [
      for (final t in asObjectList(templates, (t) => t))
        ...asObjectList(t['MediaSubscription'], PlexMediaSubscription.fromJson),
    ];
  }

  /// `GET /media/subscriptions/{subscriptionId}` — one subscription, or
  /// `null` when the answer holds none.
  Future<PlexMediaSubscription?> get({
    required String subscriptionId,
    bool includeGrabs = false,
    bool includeStorage = false,
  }) async => _http.requestJson(
    '/media/subscriptions/${seg(subscriptionId)}',
    firstOf('MediaSubscription', PlexMediaSubscription.fromJson),
    queryParameters: {
      'includeGrabs': includeGrabs ? 1 : 0,
      'includeStorage': includeStorage ? 1 : 0,
    },
  );

  /// `PUT /media/subscriptions/{subscriptionId}?prefs[key]=value` — edit
  /// a subscription's preferences.
  Future<void> editPreferences({
    required String subscriptionId,
    Map<String, Object?>? prefs,
  }) async {
    await _http.request<void>(
      '/media/subscriptions/${seg(subscriptionId)}',
      method: 'PUT',
      queryParameters: {'prefs': ?prefs},
    );
  }

  /// `DELETE /media/subscriptions/{subscriptionId}` — cancel a
  /// subscription (the recordings already on disk stay).
  Future<void> delete({required String subscriptionId}) async {
    await _http.request<void>(
      '/media/subscriptions/${seg(subscriptionId)}',
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
  Future<void> reorder({required String subscriptionId, String? after}) async {
    await _http.request<void>(
      '/media/subscriptions/${seg(subscriptionId)}/move',
      method: 'PUT',
      queryParameters: {'after': ?after},
    );
  }

  /// `DELETE /media/grabbers/operations/{operationId}` — cancel an
  /// in-flight grab (i.e. abort a recording that is currently
  /// happening).
  Future<void> cancelGrab({required String operationId}) async {
    await _http.request<void>(
      '/media/grabbers/operations/${seg(operationId)}',
      method: 'DELETE',
    );
  }
}
