// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens the notifications WebSocket on `dart:io`.
///
/// No ping interval: PMS answers only the first ping of a connection, so
/// `dart:io` would close a healthy socket on the second.
/// [connectTimeout] bounds the handshake: past it the attempt is aborted
/// (the socket is not left to connect behind the caller's back) and
/// `ready` fails with a [TimeoutException].
WebSocketChannel connectNotificationsSocket(
  Uri uri, {
  Duration? connectTimeout,
}) {
  final client = HttpClient()..connectionTimeout = connectTimeout;
  var socket = WebSocket.connect(uri.toString(), customClient: client).then((
    webSocket,
  ) {
    // The upgraded socket is detached: the client holds nothing more.
    client.close();
    return webSocket;
  });
  if (connectTimeout != null) {
    socket = socket.timeout(
      connectTimeout,
      onTimeout: () {
        client.close(force: true);
        throw TimeoutException('WebSocket handshake', connectTimeout);
      },
    );
  }
  return IOWebSocketChannel(socket);
}
