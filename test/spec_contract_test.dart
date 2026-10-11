// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Contract test against the pinned OpenAPI document.
///
/// Every public method of every sub-API is called through `dart:mirrors`
/// with stand-in arguments — every optional parameter filled, so every
/// query parameter the wrapper can send is sent — and each request that
/// leaves the client is checked against `docs/plex-api-spec.yaml` (the
/// community document, LukeHagar/plex-api-spec, pinned in the watchdog):
///
/// * its path matches a documented route,
/// * that route documents its HTTP method,
/// * every query parameter is one the route declares, spelt with the
///   same case (PMS reads `excludeParentID`, not `excludeParentId`).
///
/// Deprecated methods are called too: they still ship. A map parameter
/// that nests (`prefs[key]=…`) is checked by its outer name.
///
/// PMS ignores a query parameter it does not know and answers 200 with
/// a *wider* result, so a misspelt or misplaced parameter is invisible
/// everywhere else. The community document leaves out many parameters PMS
/// does read; each of those is allow-listed below with how it was
/// verified. Here it fails the suite — unless it is listed in
/// [_allowedExtras] with the reason it is right anyway.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:mirrors';
import 'dart:typed_data';

import 'package:dart_plex/dart_plex.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '_helpers/capturing_client.dart';

/// Query parameters a route does not declare, with why they are sent.
/// Keys are `METHOD /spec/route`, values parameter name → reason.
const _allowedExtras = <String, Map<String, String>>{
  '*': {
    // The document lists these as headers; PMS reads every X-Plex-* header
    // as a query parameter too (its own API Info section says so), and
    // URLs a player opens must carry the token in the query.
    'X-Plex-Token': 'auth for URLs opened by a player',
    'X-Plex-Container-Start': 'paging, header or query (API Info)',
    'X-Plex-Container-Size': 'paging, header or query (API Info)',
    'X-Plex-Client-Identifier': 'X-Plex-* header as query (API Info)',
    'X-Plex-Product': 'X-Plex-* header as query (API Info)',
    'X-Plex-Version': 'X-Plex-* header as query (API Info)',
    'X-Plex-Platform': 'X-Plex-* header as query (API Info)',
    'X-Plex-Device': 'X-Plex-* header as query (API Info)',
    'X-Plex-Device-Name': 'X-Plex-* header as query (API Info)',
    'X-Plex-Client-Profile-Name':
        'picks the base profile; without one Linux/macOS get 400 (verified)',
    'X-Plex-Client-Profile-Extra':
        'transcode target and bitrate limitation (verified: 96 -> 96 kbps)',
  },
  'GET /library/sections/{sectionId}/all': {
    'type':
        'the item kind; verified on PMS 1.43.2 (integration: library, music)',
    'sort':
        'section sort syntax; verified on PMS 1.43.2 (integration: library)',
    // PlexFilter conditions travel as their own parameters (genre=6,
    // year>>=2009): plex_library_filter_test pins the encoding and the
    // integration suite their effect.
    ..._filterFields,
  },
  'GET /library/metadata/{id}/children': {
    'sort': 'index:desc reversed an album; verified on PMS 1.43.2',
  },
  'PUT /library/metadata/{ids}': {
    'type': 'edit with type=9 changed an album title; verified on PMS 1.43.2',
  },
  'GET /library/sections/{sectionId}/autocomplete': {
    'type': 'type=10&title.query=Tra answered tracks; verified on PMS 1.43.2',
  },
  'GET /library/sections/{sectionId}/common': {
    'type': 'required: 400 without it, and type 8/9/10 answer different '
        'bodies; verified on PMS 1.43.2',
  },
  'PUT /library/sections/{sectionId}': {
    // PMS answers 200 to any parameter, so the 200 proves nothing; the
    // web app sends location this way when editing a section's folders.
    'location': 'NOT verified: an unknown parameter also answers 200',
  },
  'GET /playlists': {
    'sort': 'titleSort:desc reversed the list; verified on PMS 1.43.2',
    // General filter syntax: title= and userRating>>= narrowed (verified
    // on PMS 1.43.2); the other fields are the section filter syntax.
    ..._filterFields,
  },
  'POST /playlists': {
    'title':
        'creates the named playlist; verified on PMS 1.43.2 (integration: playlists)',
    'type': 'audio playlists; verified on PMS 1.43.2 (integration: playlists)',
    'smart':
        'smart=0 for a regular playlist; verified on PMS 1.43.2 (integration)',
  },
  'PUT /playlists/{playlistId}': {
    'title': 'renames; verified on PMS 1.43.2',
  },
  'GET /playQueues/{playQueueId}': {
    'window': 'window=1 around center answered 3 items; verified on PMS 1.43.2',
    'center': 'centres the window on that item; verified on PMS 1.43.2',
    'includeChapters':
        'NOT verified: no chapters in a music queue; sent as 0.1 did',
  },
  'POST /playQueues': {
    'includeChapters':
        'NOT verified: no chapters in a music queue; sent as 0.1 did',
    'playQueueItemID': 'NOT verified: sent as 0.1 did',
  },
  'GET /library/sections/{sectionId}/search': {
    'query': 'query=Track answered the tracks; verified on PMS 1.43.2',
    'type': 'required: 400 without it; verified on PMS 1.43.2',
    'limit': 'limit=1 answered one; verified on PMS 1.43.2',
  },
  'GET /status/sessions/history/all': {
    'viewedAt>=': 'narrowed 3 plays to 1; verified on PMS 1.43.2',
    'viewedAt<=': 'narrowed 3 plays to 1; verified on PMS 1.43.2',
  },
  'GET /hubs': {
    'includeMeta': 'no effect observed on 1.43.2 (identical bodies with, '
        'without and with garbage); sent as 0.1 did',
  },
  'GET /hubs/sections/{sectionId}': {
    'includeMeta': 'no effect observed on 1.43.2; sent as 0.1 did',
  },
  'GET /{transcodeType}/:/transcode/universal/start.{extension}': {
    'audioCodec': 'NOT verified for video (the music path uses a profile)',
    'videoCodec': 'NOT verified: video transcode',
    'container': 'NOT verified: video transcode',
    'fastSeek': 'sent by the verified music start too',
    'maxAudioBitrate': 'NOT verified for video; no effect on music',
    'audioChannels': 'deprecated universalAudioUrl only, sent as 0.1 did; '
        'NOT verified (startAudioTranscode replaces it)',
    'session': 'session id for ping/stop; verified on PMS 1.43.2',
  },
  'GET /{transcodeType}/:/transcode/universal/decision': {
    'path': 'the item; verified on PMS 1.43.2',
    'mediaIndex': 'verified on PMS 1.43.2 (startAudioTranscode)',
    'partIndex': 'verified on PMS 1.43.2 (startAudioTranscode)',
    'protocol': 'hls / dash; verified on PMS 1.43.2',
    'directPlay': 'verified on PMS 1.43.2 (startAudioTranscode)',
    'directStream': 'verified on PMS 1.43.2 (startAudioTranscode)',
    'fastSeek': 'verified on PMS 1.43.2 (startAudioTranscode)',
    'offset': 'verified on PMS 1.43.2 (startAudioTranscode)',
    'session': 'verified on PMS 1.43.2 (startAudioTranscode)',
  },
};

/// The [PlexFilter] fields the stand-in filters send (see [_filters]): the
/// section filter syntax, each narrowed a section on PMS 1.43.2
/// (integration: filtering, and the 0.2 review's A/B checks).
const _filterFields = <String, String>{
  'genre': 'genre=5 narrowed, genre=999 emptied; verified on PMS 1.43.2',
  'year>>': 'year>>=2019 kept the 2020 album, 2021 dropped it; verified',
  'title=': 'exact title match; verified on PMS 1.43.2',
  'userRating>>': 'rated() narrowed; verified on PMS 1.43.2',
  'unwatched': 'played()/unplayed() partition a section; verified',
};

/// One filter of each kind, so every field name is checked.
final _filters = <PlexFilter>[
  PlexFilter.genre(1),
  PlexFilter.yearAfter(2019),
  PlexFilter.titleIs('x'),
  PlexFilter.rated(),
  PlexFilter.unplayed(),
];

/// Routes PMS serves that the community document does not list, with the
/// methods and query parameters verified on a real server.
const _extraRoutes = <String, Map<String, List<String>>>{
  // 200 with the genre index; verified on PMS 1.43.2.
  '/library/sections/{sectionId}/genre': {
    'GET': ['type'],
  },
  // The document's "firstCharacters" answers 404; this is the real one.
  '/library/sections/{sectionId}/firstCharacter': {
    'GET': ['type', 'sort'],
  },
  // Legacy flat search, 200; verified on PMS 1.43.2.
  '/search': {
    'GET': ['query', 'limit'],
  },
  // Stop and ping of a live music session answered 200; verified on PMS 1.43.2.
  '/video/:/transcode/universal/ping': {
    'GET': ['session'],
  },
  '/video/:/transcode/universal/stop': {
    'GET': ['session'],
  },
  // GET /:/timeline is what counted plays in the timeline probes; verified on PMS 1.43.2
  // (the document lists only POST).
  '/:/timeline': {
    'GET': [
      'ratingKey', 'key', 'state', 'time', 'duration', 'continuing', //
      'playQueueItemID',
    ],
  },
  // Creating a section is a POST (the bootstrap does it); the document
  // lists only GET /library/sections.
  '/library/sections': {
    'POST': [
      'name', 'type', 'agent', 'scanner', 'language', 'location', //
      'importFromiTunes', 'metadataAgentProviderGroupId', 'relative',
      // Agent preferences as prefs[name]=value, as 0.1 sent them; the
      // bootstrap's own section creation sends none (NOT verified).
      'prefs',
    ],
  },
  // NOT verified (needs Plex Pass): the document says POST; the wrapper
  // sends GET, as python-plexapi does.
  '/status/sessions/terminate': {
    'GET': ['sessionId', 'reason'],
  },
  // POST answers 200 with an empty container, GET and PUT 404, on PMS
  // 1.43.2 without tuners: the document's GET is the wrong one.
  '/media/grabbers/devices/discover': {
    'POST': [],
  },
};

/// Arguments that must not be the generic stand-in, per method.
const _overrides = <String, Map<Symbol, Object?>>{
  // Exactly one of uri / playlistId.
  'PlexPlayQueuesApi.addItems': {#playlistId: #omit},
  'PlexStreamingApi.startAudioTranscode': {#protocol: 'hls'},
  'PlexStreamingApi.directFileUrl': {#partKey: '/library/parts/1/2/file.flac'},
};

/// Methods not called, with why.
const _skipped = <String, String>{
  // plex.tv, not PMS: outside the document.
  'PlexAccountApi.*': 'plex.tv account API, not part of the PMS document',
  // These follow a key the server handed out, so the path is the server's.
  'PlexHubsApi.drill': 'follows Hub.key',
  'PlexStreamingApi.lyrics': 'follows a lyrics stream key',
  'PlexSessionsApi.deleteHistoryEntry': 'follows PlexHistoryEntry.historyKey',
  'PlexLibraryApi.filterValues': 'follows PlexLibraryFilter.valuesKey',
  'PlexLiveTvApi.dvrChannels': 'follows a DVR key',
  'PlexNotificationsApi.connectWebSocket': 'WebSocket',
  'PlexNotificationsApi.closeWebSocket': 'WebSocket',
  'PlexNotificationsApi.connectEventSource': 'long-lived stream',
  'PlexNotificationsApi.closeEventSource': 'long-lived stream',
};

final class _Route {
  final String path;
  final RegExp pattern;
  final int literals;
  final Map<String, Set<String>> paramsByMethod;

  _Route(this.path, this.pattern, this.literals, this.paramsByMethod);
}

List<_Route> _loadSpec() {
  final spec =
      loadYaml(File('docs/plex-api-spec.yaml').readAsStringSync()) as YamlMap;
  final routes = <_Route>[];
  (spec['paths'] as YamlMap).forEach((path, ops) {
    // An example path left in the document (/playQueues/1) would outrank
    // the real template; numeric literal segments are not routes.
    if ((path as String).split('/').any((s) => int.tryParse(s) != null)) {
      return;
    }
    final byMethod = <String, Set<String>>{};
    final shared = (ops as YamlMap)['parameters'] as YamlList?;
    ops.forEach((method, op) {
      if (op is! YamlMap || method == 'parameters') return;
      byMethod[(method as String).toUpperCase()] = {
        for (final p in [...?(op['parameters'] as YamlList?), ...?shared])
          if (_param(spec, p) case {'in': 'query', 'name': final String n}) n,
      };
    });
    routes.add(_route(path, byMethod));
  });
  _extraRoutes.forEach((path, methods) {
    routes.add(
      _route(path, {
        for (final e in methods.entries) e.key: {...e.value},
      }),
    );
  });
  return routes;
}

/// A parameter object, following one `\$ref` into `components`.
Map<Object?, Object?> _param(YamlMap spec, Object? p) {
  if (p is! YamlMap) return const {};
  final ref = p[r'$ref'];
  if (ref is! String) return p;
  Object? o = spec;
  for (final part in ref.split('/').skip(1)) {
    o = (o as YamlMap?)?[part];
  }
  return o is YamlMap ? o : const {};
}

_Route _route(String rawPath, Map<String, Set<String>> byMethod) {
  // The document spells a few routes with a trailing slash.
  final path = rawPath.length > 1 && rawPath.endsWith('/')
      ? rawPath.substring(0, rawPath.length - 1)
      : rawPath;
  // A placeholder can be a whole segment ({itemId}) or part of one
  // ({segmentId}.{container}).
  final regex = path
      .split('/')
      .map(
        (s) => s
            .split(RegExp(r'(\{[^}]+\})'))
            .map(RegExp.escape)
            .join()
            .toLowerCase(),
      )
      .join('/');
  final pattern = RegExp(
    '^${path.toLowerCase().split('/').map((s) => s.replaceAllMapped(RegExp(r'\{[^}]+\}'), (_) => '\u0000')).map((s) => s.split('\u0000').map(RegExp.escape).join('[^/]+')).join('/')}\$',
  );
  assert(regex.isNotEmpty);
  return _Route(
    path,
    pattern,
    path.split('/').where((s) => !s.contains('{')).length,
    byMethod,
  );
}

/// The most specific route matching [path], preferring one that documents
/// [method] (`/Items/{id}/RemoteSearch/Subtitles/{language}` and
/// `…/{subtitleId}` share a shape and differ by method).
_Route? _match(List<_Route> routes, String path, String method) {
  final lower = path.toLowerCase();
  _Route? best;
  int score(_Route r) =>
      r.literals * 2 + (r.paramsByMethod.containsKey(method) ? 1 : 0);
  for (final r in routes) {
    if (!r.pattern.hasMatch(lower)) continue;
    if (best == null || score(r) > score(best)) best = r;
  }
  return best;
}

/// A stand-in value for a parameter of [type], or `#skip` when there is
/// none (the parameter is then left out if it may be).
Object? _value(TypeMirror type, String name) {
  // Extra headers are not part of the query contract.
  if (name == 'extraHeaders') return #skip;
  if (type is! ClassMirror) return #skip;
  final t = type.reflectedType;
  if (t == String) {
    return name.toLowerCase().contains('date') ? '2026-01-01' : 'x';
  }
  if (t == int) return 1;
  if (t == Object) return 'x';
  if (t == double) return 1.5;
  if (t == num) return 1;
  if (t == bool) return true;
  if (t == Duration) return const Duration(seconds: 1);
  if (t == DateTime) return DateTime.utc(2026);
  if (t == Uint8List) return Uint8List.fromList([1]);
  if (type.isEnum) {
    return (type.getField(#values).reflectee as List<Object?>).first;
  }
  if (type.simpleName == #List &&
      (type.typeArguments.single as ClassMirror).reflectedType == PlexFilter) {
    return _filters;
  }
  if (type.simpleName == #List) {
    final arg = type.typeArguments.single;
    final inner = _value(arg, name);
    return inner == #skip ? #skip : _list(arg, inner);
  }
  // A map is either spread into the query (`args`, `changes`: free-form,
  // its keys are the caller's) or nested under its own name
  // (`prefs[key]=…`). One sentinel entry tells them apart: a bare
  // sentinel is a spread map, `name[sentinel]` is checked as `name`.
  if (type.simpleName == #Map) {
    final v = (type.typeArguments.last as ClassMirror).reflectedType;
    if (v == String) return <String, String>{_free: 'x'};
    if (v == Object) return <String, Object>{_free: 'x'};
    return <String, Object?>{_free: 'x'};
  }
  if (t == PlexCredentials) {
    return const PlexCredentials(
      clientIdentifier: 'x',
      product: 'x',
      version: '1',
      device: 'x',
      deviceName: 'x',
      platform: 'x',
    );
  }
  if (t == PlexFilter) return PlexFilter.genre(1);
  if (t == PlexLibraryFilter) {
    return PlexLibraryFilter.fromJson(const {
      'filter': 'genre',
      'title': 'Genre',
      'filterType': 'string',
      'key': '/library/sections/1/genre',
    });
  }
  return #skip;
}

/// A typed one-element list, so `List<String>` parameters accept it.
Object _list(TypeMirror arg, Object? element) {
  final t = (arg as ClassMirror).reflectedType;
  if (t == String) return <String>[element! as String];
  if (t == int) return <int>[element! as int];
  if (t == double) return <double>[element! as double];
  if (t == num) return <num>[element! as num];
  if (element is Map<String, Object?>) return <Map<String, Object?>>[element];
  if (element is PlexFilter) return <PlexFilter>[element];
  return [element];
}

bool _deprecated(DeclarationMirror d) =>
    d.metadata.any((m) => m.reflectee is Deprecated);

/// The key of the one entry every stand-in map carries.
const _free = 'freeFormKey';

/// The name a query key is checked under: `prefs[x]` is `prefs`.
String _outer(String key) {
  final i = key.indexOf('[');
  return i > 0 && key.endsWith(']') ? key.substring(0, i) : key;
}

void main() {
  final routes = _loadSpec();

  test('every request a sub-API sends is in the pinned spec', () async {
    final adapter = CapturingAdapter();
    final client = testClient(adapter, jsonIsolateThreshold: 1 << 30);
    final clientMirror = reflect(client);
    final violations = <String>[];
    final uncalled = <String>[];
    var calls = 0;

    final apis = clientMirror.type.declarations.values
        .whereType<VariableMirror>()
        .where((v) => !v.isPrivate && !v.isStatic)
        .map((v) => clientMirror.getField(v.simpleName))
        .where((m) => MirrorSystem.getName(m.type.simpleName).endsWith('Api'));

    for (final api in apis) {
      final apiName = MirrorSystem.getName(api.type.simpleName);
      // instanceMembers, not declarations: a sub-API split into mixins
      // (PlexLibraryApi) inherits most of its methods.
      final methods = api.type.instanceMembers.values.where(
        (m) =>
            m.isRegularMethod &&
            !m.isPrivate &&
            !m.isOperator &&
            (m.owner as ClassMirror?)?.reflectedType != Object,
      );
      for (final m in methods) {
        final name = '$apiName.${MirrorSystem.getName(m.simpleName)}';
        if (_skipped.containsKey(name) || _skipped.containsKey('$apiName.*')) {
          continue;
        }
        final positional = <Object?>[];
        final named = <Symbol, Object?>{};
        var callable = true;
        final overrides = _overrides[name] ?? const {};
        for (final p in m.parameters) {
          if (_deprecated(p)) continue;
          if (overrides[p.simpleName] == #omit) continue;
          final v = overrides.containsKey(p.simpleName)
              ? overrides[p.simpleName]
              : _value(p.type, MirrorSystem.getName(p.simpleName));
          if (v == #skip) {
            if (!p.isOptional && !p.isNamed) callable = false;
            if (p.isNamed && !p.isOptional) callable = false;
            continue;
          }
          if (p.isNamed) {
            named[p.simpleName] = v;
          } else {
            positional.add(v);
          }
        }
        if (!callable) {
          uncalled.add(name);
          continue;
        }
        final before = adapter.requests.length;
        Object? result;
        Object? failure;
        try {
          result = api.invoke(m.simpleName, positional, named).reflectee;
          if (result is Future) await result;
          if (result is Stream) await result.first;
        } catch (e) {
          // The canned answer fits few endpoints; only the request matters.
          failure = e;
        }
        final sent = [
          ...adapter.requests.skip(before).map((r) => (r.method, r.uri)),
          if (result is String && result.startsWith('http'))
            ('GET', Uri.parse(result)),
          if (result is (String, String) && result.$1.startsWith('http'))
            ('GET', Uri.parse(result.$1)),
        ];
        if (sent.isEmpty) {
          uncalled.add('$name (sent nothing: $failure)');
          continue;
        }
        for (final (method, uri) in sent) {
          calls++;
          final route = _match(routes, uri.path, method);
          if (route == null) {
            violations.add('$name: ${uri.path} is not a route in the spec');
            continue;
          }
          final declared = route.paramsByMethod[method];
          if (declared == null) {
            violations.add(
              '$name: $method ${route.path} — the spec has '
              '${route.paramsByMethod.keys.join('/')}',
            );
            continue;
          }
          final allowed = {
            ...?_allowedExtras['*']?.keys,
            ...?_allowedExtras['$method ${route.path}']?.keys,
          };
          for (final q in uri.queryParametersAll.keys) {
            if (q == _free) continue; // a spread free-form map
            final k = _outer(q);
            if (!declared.contains(k) && !allowed.contains(k)) {
              violations.add(
                '$name: $method ${route.path} sends "$q", '
                'which the route does not declare',
              );
            }
          }
        }
      }
    }

    // ignore: avoid_print
    print('spec contract: $calls requests checked; not called: '
        '${uncalled.length}\n  ${uncalled.join('\n  ')}');
    expect(violations, isEmpty, reason: violations.join('\n'));
    expect(uncalled, isEmpty, reason: 'every method must be exercised');
    expect(calls, greaterThan(200));
  });
}
