// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

/// Identity of the client app talking to Plex.
///
/// Every Plex HTTP request — both to `plex.tv` and to a PMS — carries a
/// fixed set of `X-Plex-*` headers describing who the caller is. The
/// server uses these to scope tokens, attribute timeline updates, and
/// route transcode sessions.
///
/// `clientIdentifier` MUST be a stable per-installation UUID. Generate it
/// once, persist it (SharedPreferences / Keychain / etc.), and reuse it
/// forever. Changing it invalidates every previously-issued token.
class PlexCredentials {
  /// Stable per-install UUID. Sent as `X-Plex-Client-Identifier`.
  final String clientIdentifier;

  /// Application name (e.g. `'Finova'`). Sent as `X-Plex-Product`.
  final String product;

  /// Application version (semver). Sent as `X-Plex-Version`.
  final String version;

  /// Device hardware/category (e.g. `'iPhone'`, `'Macintosh'`).
  /// Sent as `X-Plex-Device`.
  final String device;

  /// Friendly device name (e.g. `"Alex's iPhone"`).
  /// Sent as `X-Plex-Device-Name`.
  final String deviceName;

  /// Platform string (e.g. `'iOS'`, `'macOS'`, `'Android'`, `'Web'`).
  /// Sent as `X-Plex-Platform`.
  final String platform;

  /// Optional OS version. Sent as `X-Plex-Platform-Version`.
  final String? platformVersion;

  /// Optional `X-Plex-Client-Profile-Extra` value — used to declare
  /// extra transcode targets the server should support for this client.
  /// Example:
  /// ```
  /// 'add-transcode-target(type=musicProfile&context=streaming'
  /// '&protocol=hls&container=mpegts&audioCodec=aac,mp3)'
  /// ```
  final String? clientProfileExtra;

  /// Build a credentials bundle. [clientIdentifier] must be a stable per-install UUID.
  const PlexCredentials({
    required this.clientIdentifier,
    required this.product,
    required this.version,
    required this.device,
    required this.deviceName,
    required this.platform,
    this.platformVersion,
    this.clientProfileExtra,
  });

  /// Headers to attach to every request — auth token is added by the
  /// HTTP layer separately.
  Map<String, String> toHeaders() {
    final h = <String, String>{
      'X-Plex-Client-Identifier': clientIdentifier,
      'X-Plex-Product': product,
      'X-Plex-Version': version,
      'X-Plex-Device': device,
      'X-Plex-Device-Name': deviceName,
      'X-Plex-Platform': platform,
      'Accept': 'application/json',
    };
    if (platformVersion != null) {
      h['X-Plex-Platform-Version'] = platformVersion!;
    }
    if (clientProfileExtra != null) {
      h['X-Plex-Client-Profile-Extra'] = clientProfileExtra!;
    }
    return h;
  }

  /// Return a copy with the given fields replaced; preserves [clientIdentifier] unless overridden.
  PlexCredentials copyWith({
    String? clientIdentifier,
    String? product,
    String? version,
    String? device,
    String? deviceName,
    String? platform,
    String? platformVersion,
    String? clientProfileExtra,
  }) =>
      PlexCredentials(
        clientIdentifier: clientIdentifier ?? this.clientIdentifier,
        product: product ?? this.product,
        version: version ?? this.version,
        device: device ?? this.device,
        deviceName: deviceName ?? this.deviceName,
        platform: platform ?? this.platform,
        platformVersion: platformVersion ?? this.platformVersion,
        clientProfileExtra: clientProfileExtra ?? this.clientProfileExtra,
      );
}
