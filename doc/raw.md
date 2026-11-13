For an endpoint the typed sub-APIs do not cover, send the request
yourself. It goes through the same HTTP client, headers, retry policy and
`PlexException` handling.

## Raw request

```dart
final response = await plex.request<Map<String, Object?>>(
  '/library/sections/${musicLib.id}/all',
  queryParameters: {
    'type': 9,
    'X-Plex-Container-Start': 0,
    'X-Plex-Container-Size': 50,
  },
);
print('${response.statusCode} ${response.contentType}');
final container = response.data?['MediaContainer'];
```

A `PlexResponse<T>` carries `data`, `statusCode`, `headers` (lower-case
names), `contentType` and the requested `uri`. `method` takes `'POST'`,
`'PUT'` or `'DELETE'`, and `get()`, `post()`, `put()` and `delete()` are
shorthands. `extraHeaders`, `data`, `absoluteUrl` and `cancelToken` are
optional. An `extraHeaders` entry replaces the header of the same name,
and an empty value removes it: `{'X-Plex-Token': ''}` sends no token. `responseType` picks the decoding: `PlexResponseType.json`
(JSON when the server says so, text otherwise), `bytes` or `plain`.

## Raw bytes and streams

```dart
// Small bodies, held in memory.
final art = await plex.requestBytes(
  '/library/metadata/123/thumb/1700000000',
  absoluteUrl: false,
);
final bytes = art.data; // Uint8List?

// Large bodies, chunk by chunk.
final res = await plex.requestStream(
  '${plex.baseUrl}/library/parts/123/1700000000/file.flac',
);
print('${res.contentLength} bytes of ${res.contentType}');
await for (final chunk in res.stream) {
  sink.add(chunk);
}
```

`requestBytes()` and `requestStream()` take a full URL by default; pass
`absoluteUrl: false` for a path on the connected server. The token
travels in the headers to the connected server (its host and port) and
to plex.tv only: a full URL to any other host, such as artwork on a CDN,
is requested without it. To send one there, name it:
`extraHeaders: {'X-Plex-Token': token}` on `request()` or
`requestStream()`. Listen to a `PlexStreamedResponse`'s
`stream` once; cancelling the subscription closes the connection. A
pause longer than the receive timeout fails the stream unless
`stallTimeout` is `false`.
