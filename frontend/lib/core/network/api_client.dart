import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  final String baseUrl;
  final Duration defaultTimeout;
  final http.Client _client;

  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient();

  /// In-memory token cache — populated on first authenticated request.
  String? _cachedToken;

  ApiClient({
    String? baseUrl,
    Duration? defaultTimeout,
    http.Client? client,
  })  : baseUrl = baseUrl ?? AppConfig.baseUrl,
        defaultTimeout = defaultTimeout ?? AppConfig.apiTimeout,
        _client = client ?? http.Client();

  // ---------------------------------------------------------------------------
  // Auth token helpers
  // ---------------------------------------------------------------------------

  /// Stores the token in-memory so that ApiClient can attach it immediately
  /// without waiting for SharedPreferences on every request.
  void cacheToken(String? token) {
    _cachedToken = token;
    debugPrint('[ApiClient] Token cached in memory: ${token != null ? '***${token.substring(token.length > 6 ? token.length - 6 : 0)}' : 'null'}');
  }

  /// Clears the cached token (call on sign-out).
  void clearToken() {
    _cachedToken = null;
    debugPrint('[ApiClient] Token cleared from memory.');
  }

  /// Returns the current auth token — in-memory first, then SharedPreferences.
  Future<String?> _getToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('auth_token');
      if (stored != null && stored.isNotEmpty) {
        _cachedToken = stored; // warm the cache
        return stored;
      }
    } catch (e) {
      debugPrint('[ApiClient] Could not read auth_token from SharedPreferences: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // URI & header builders
  // ---------------------------------------------------------------------------

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    String fullUrl;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      fullUrl = path;
    } else {
      final cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final cleanPath = path.startsWith('/') ? path : '/$path';
      fullUrl = '$cleanBase$cleanPath';
    }

    final uri = Uri.parse(fullUrl);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final existingParams = Map<String, dynamic>.from(uri.queryParameters);
      existingParams.addAll(queryParameters);
      return uri.replace(queryParameters: existingParams);
    }
    return uri;
  }

  /// Builds the final headers, automatically injecting the auth token.
  Future<Map<String, String>> _buildHeaders(
      Map<String, String>? customHeaders) async {
    final token = await _getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?customHeaders,
    };
    return headers;
  }

  Object? _encodeBody(Object? body) {
    if (body == null) return null;
    if (body is String) return body;
    return jsonEncode(body);
  }

  // ---------------------------------------------------------------------------
  // HTTP verbs
  // ---------------------------------------------------------------------------

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final builtHeaders = await _buildHeaders(headers);
    try {
      return await _client
          .get(uri, headers: builtHeaders)
          .timeout(timeout ?? defaultTimeout);
    } on TimeoutException {
      throw ApiException(
        message: 'Request timed out for $uri',
        uri: uri,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: e.toString(),
        uri: uri,
      );
    }
  }

  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path);
    final builtHeaders = await _buildHeaders(headers);
    try {
      return await _client
          .post(
            uri,
            headers: builtHeaders,
            body: _encodeBody(body),
          )
          .timeout(timeout ?? defaultTimeout);
    } on TimeoutException {
      throw ApiException(
        message: 'Request timed out for $uri',
        uri: uri,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: e.toString(),
        uri: uri,
      );
    }
  }

  Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path);
    final builtHeaders = await _buildHeaders(headers);
    try {
      return await _client
          .put(
            uri,
            headers: builtHeaders,
            body: _encodeBody(body),
          )
          .timeout(timeout ?? defaultTimeout);
    } on TimeoutException {
      throw ApiException(
        message: 'Request timed out for $uri',
        uri: uri,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: e.toString(),
        uri: uri,
      );
    }
  }

  Future<http.Response> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path);
    final builtHeaders = await _buildHeaders(headers);
    try {
      return await _client
          .patch(
            uri,
            headers: builtHeaders,
            body: _encodeBody(body),
          )
          .timeout(timeout ?? defaultTimeout);
    } on TimeoutException {
      throw ApiException(
        message: 'Request timed out for $uri',
        uri: uri,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: e.toString(),
        uri: uri,
      );
    }
  }

  Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path);
    final builtHeaders = await _buildHeaders(headers);
    try {
      return await _client
          .delete(
            uri,
            headers: builtHeaders,
            body: _encodeBody(body),
          )
          .timeout(timeout ?? defaultTimeout);
    } on TimeoutException {
      throw ApiException(
        message: 'Request timed out for $uri',
        uri: uri,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: e.toString(),
        uri: uri,
      );
    }
  }
}
