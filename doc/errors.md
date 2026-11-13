Handle failures, cancel and retry requests, and walk paged lists.

## Error handling

### PlexException

Every call throws a `PlexException` on failure:

```dart
try {
  await plex.library.sections();
} on PlexException catch (e) {
  print('${e.type} ${e.statusCode} ${e.message}');
}
```

`PlexErrorType` is one of `connection`, `timeout`, `auth`,
`passRequired`, `notFound`, `badRequest`, `serverError`, `parse`, `state`,
`cancelled` and `unknown`. The exception also carries the request `path`,
the underlying `cause`, the original `stackTrace`, the whole error `body`
the server sent (`message` holds at most its first 512 bytes) and, when
the server sent `Retry-After` (on a `429` or `503`), `retryAfter`. The
value of an `X-Plex-Token`, `deviceJWT` or `pin` in the `path` or the
`message` reads `REDACTED`, so `toString()` can be logged as it is.
`body` and `cause` are kept as they came.

### An empty answer

A call that looks one thing up (`get`, `item`, `details`, `byId`,
`person`, `liveSession`) returns `null` when the answer holds nothing. A
call that creates something (`playlists.create`, `collections.create`,
`playQueues.create`, `downloadQueue.create`) throws a `parse` error when
the answer does not hold it. `subscriptions.create` returns `null`
instead: what PMS answers to it is not verified.

### Classifying a failure

```dart
try {
  await plex.library.sections();
} on PlexException catch (e) {
  if (e.isCancelled) {
    // the caller gave up: not a failure, ignore it
  } else if (e.isPassRequired) {
    showPassNeeded(); // remote video needs a Plex Pass or Remote Watch Pass
  } else if (e.isAuthError) {
    // 401 or 498: the token is refused. A 403 can also be a valid token
    // that may not do this (a shared user on an owner's route): check
    // e.statusCode before signing the user out.
    await signInAgain();
  } else if (e.isTransient) {
    scheduleRetry(e.retryAfter); // network, 5xx or 429
  } else if (e.isNotFound) {
    showGone(); // 404: confirmed absence
  } else {
    showError(e.message);
  }
}
```

| Getter | True for |
| :--- | :--- |
| `isNetworkFailure` | No answer at all: the connection failed or timed out |
| `isTransient` | A failure that may pass if sent again: a network failure, a 5xx or a `429` |
| `isNotFound` | The server answered `404` |
| `isCancelled` | The request was cancelled through a `PlexCancelToken` |
| `isAuthError` | `401`, `403` or `498` (plex.tv's "token expired"), or a sign-in answered without a token |
| `isPassRequired` | Playback refused for want of a Plex Pass or Remote Watch Pass (see [Streaming](https://pub.dev/documentation/dart_plex/latest/topics/Streaming-topic.html)); not an auth error |

After `useJwt()` the client renews an expired JWT on its own, and retries
the refused request once; `tokenRenewer` does the same for tokens you
renew yourself. Otherwise, on `isAuthError`, sign in again (see
[Client and sign-in](https://pub.dev/documentation/dart_plex/latest/topics/Client%20and%20sign-in-topic.html)).

## Cancellation and retries

### Cancelling requests

```dart
PlexCancelToken? searchToken;

Future<List<PlexHub>> searchAsYouType(PlexClient plex, String text) async {
  searchToken?.cancel(); // drop the previous keystroke's request
  final token = searchToken = PlexCancelToken();
  try {
    return await plex.withCancelToken(token).search.hubs(query: text);
  } on PlexException catch (e) {
    if (e.isCancelled) return const [];
    rethrow;
  }
}
```

`withCancelToken(token)` returns a view of the client whose every call is
cancelled by `token.cancel()`. The view shares the client's connections,
server and token (`connect`, `setToken` and `close` on either affect
both) and costs nothing to create, so make one per page, filter or
search term. A token cancels once: make a new one for the next request.
`request()`, `requestBytes()`, `requestStream()` and `downloadToFile()`
also take a `cancelToken` directly.

A cancelled call throws a `PlexException` of type `cancelled`.
`notifications` is the same object on the view as on the client: a
WebSocket is not a request and is not cancelled.

### Retry policy

```dart
final plex = PlexClient(
  credentials: credentials,
  retryPolicy: const PlexRetryPolicy(
    maxAttempts: 4, // the first attempt included
    maxDelay: Duration(seconds: 10),
  ),
);
```

Retries are off by default. With a policy, only `GET` and `HEAD`
requests are sent again, and only after a failure another attempt can
fix: no answer (connection lost, timeout), `502`, `503`, `504` or `429`.
A `500` is not retried. The wait grows exponentially from `initialDelay`
(300 ms) with random jitter, never above `maxDelay` (5 s); a
`Retry-After` header is honoured up to `maxDelay`, and a cancel token
cancels the wait too. `const PlexRetryPolicy()` sends a request up to
three times. Opening a stream is retried as well; a body already flowing
is not replayed.

## Paging

### Page parameters

Plex pages with `X-Plex-Container-Start` and `X-Plex-Container-Size`, and
pages only when it gets both, so every paged call sends both.

`allByType()`, `albums()`, `playlists.list()`, `sessions.history()` and
`hubs.drill()` always read one page: 50 rows from `start` unless you pass
`size`. `children()`, `grandchildren()`, `allLeaves()`, `recentlyAdded()`
and `playlists.items()` return every row when you pass neither, and one
page when you pass `size` (`start` is 0 by default). Pass `start`
together with `size`: a `start` alone throws an `ArgumentError`, since
the server would ignore it.

### Walking every page

```dart
final tracks = PlexPaging.items(
  (start, size) => plex.library.grandchildren(
    ratingKey: artist.ratingKey,
    start: start,
    size: size,
  ),
  pageSize: 200,
);
await for (final track in tracks) {
  print(track.title);
}

// allByType returns a container: hand PlexPaging its items.
final albumPages = PlexPaging.pages(
  (start, size) async => (await plex.library.allByType(
    sectionId: musicLib.id,
    type: PlexMetadataType.album,
    start: start,
    size: size,
  ))
      .items,
  limit: 500,
);
```

`PlexPaging.pages()` streams one page at a time and `items()` the rows
one by one. Paging stops at the first page shorter than `pageSize` (100
by default) or once `limit` rows have arrived, asking the last page for
exactly what is left. Each page is one request, made as the stream is
listened to; cancelling the subscription stops the requests. Pair it
with a cancel token (see Cancelling requests above) to drop the request
in flight too.
