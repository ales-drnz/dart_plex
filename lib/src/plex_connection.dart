// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'package:dio/dio.dart';

import 'plex_credentials.dart';
import 'plex_error_type.dart';
import 'plex_exception.dart';

/// Internal HTTP transport shared by every sub-API.
///
/// Holds the [Dio] instance, the credential headers, the active server
/// base URL, and the current `X-Plex-Token`. Sub-APIs use it via
/// [request] / [requestBytes] — they never see the raw Dio.
///
/// Lives inside `src/`; not exported. Public API is [PlexClient].
class PlexConnection {
  final Dio _dio;
  final PlexCredentials credentials;

  String? _baseUrl;
  String? _token;

  PlexConnection({
    required this.credentials,
    Dio? dio,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) : _dio = dio ?? Dio() {
    _dio.options.connectTimeout = connectTimeout;
    _dio.options.receiveTimeout = receiveTimeout;
    _dio.options.headers.addAll(credentials.toHeaders());
  }

  /// Currently configured PMS base URL, or null if not yet connected.
  String? get baseUrl => _baseUrl;

  /// Currently configured auth token, or null if not yet authenticated.
  String? get token => _token;

  /// Whether [connect] has been called and a token is available.
  bool get isAuthenticated => _baseUrl != null && _token != null;

  /// Set or clear the PMS base URL. Trailing slash is stripped.
  set baseUrl(String? value) {
    if (value == null) {
      _baseUrl = null;
      return;
    }
    _baseUrl =
        value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  /// Set or clear the X-Plex-Token. When set, the header is also applied
  /// to the underlying Dio default headers so any caller (including
  /// caches sitting on the same Dio) sees the token automatically.
  set token(String? value) {
    _token = value;
    if (value == null) {
      _dio.options.headers.remove('X-Plex-Token');
    } else {
      _dio.options.headers['X-Plex-Token'] = value;
    }
  }

  /// Make a request against [path] on the active PMS base URL.
  ///
  /// Pass [absoluteUrl] = true and a full URL in [path] to target a host
  /// other than the connected server — used by the plex.tv account API.
  Future<Response<T>> request<T>(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? queryParameters,
    Object? data,
    Map<String, String>? extraHeaders,
    bool absoluteUrl = false,
    ResponseType? responseType,
  }) async {
    final url = absoluteUrl ? path : _resolve(path);
    try {
      return await _dio.request<T>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: extraHeaders,
          responseType: responseType,
        ),
      );
    } on DioException catch (e) {
      throw PlexException.fromDio(e, path: url);
    }
  }

  /// Convenience wrapper for byte-stream GETs (artwork, downloads).
  Future<Response<List<int>>> requestBytes(
    String url, {
    Map<String, dynamic>? queryParameters,
    bool absoluteUrl = true,
  }) async {
    return request<List<int>>(
      url,
      queryParameters: queryParameters,
      absoluteUrl: absoluteUrl,
      responseType: ResponseType.bytes,
    );
  }

  /// Open a streaming GET (used for SSE / chunked event streams).
  /// Returns the [Response] with a [ResponseBody] stream that the
  /// caller listens to. Translates [DioException] into
  /// [PlexException] like the other transport methods.
  Future<Response<ResponseBody>> streamGet(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? extraHeaders,
    bool absoluteUrl = false,
  }) async {
    final url = absoluteUrl ? path : _resolve(path);
    try {
      return await _dio.get<ResponseBody>(
        url,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.stream,
          headers: extraHeaders,
        ),
      );
    } on DioException catch (e) {
      throw PlexException.fromDio(e, path: url);
    }
  }

  String _resolve(String path) {
    if (_baseUrl == null) {
      throw const PlexException(
        'PlexClient.connect() has not been called — no PMS base URL is set.',
        type: PlexErrorType.state,
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (!path.startsWith('/')) return '$_baseUrl/$path';
    return '$_baseUrl$path';
  }
}
