// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens the notifications WebSocket in a browser.
///
/// [connectTimeout] is applied by the caller, on the channel's `ready`.
WebSocketChannel connectNotificationsSocket(
  Uri uri, {
  Duration? connectTimeout,
}) => WebSocketChannel.connect(uri);
