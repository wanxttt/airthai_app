import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../constants/api_constants.dart';
import 'api_response.dart';

/// Lightweight, robust HTTP client for AirthAI API operations.
///
/// Phase 1: Authentication & Network Layer
/// Uses Dart core `HttpClient` to ensure zero required external dependencies
/// while supporting full REST functionality, timeouts, and safe error mapping.
class ApiClient {
  static final ApiClient instance = ApiClient();

  final String baseUrl;
  final Duration timeout;

  ApiClient({
    this.baseUrl = ApiConstants.defaultBaseUrl,
    this.timeout = ApiConstants.connectTimeout,
  });

  /// Performs an HTTP POST request with JSON payload.
  Future<ApiResponse<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    return _send('POST', path, body: body, headers: headers, token: token);
  }

  /// Performs an HTTP GET request.
  Future<ApiResponse<Map<String, dynamic>>> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    String? token,
  }) async {
    String fullPath = path;
    if (queryParams != null && queryParams.isNotEmpty) {
      final validParams = queryParams.entries
          .where((e) => e.value != null && e.value.toString().isNotEmpty)
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      if (validParams.isNotEmpty) {
        fullPath = '$fullPath?$validParams';
      }
    }
    return _send('GET', fullPath, headers: headers, token: token);
  }

  /// Performs an HTTP PATCH request with JSON payload.
  Future<ApiResponse<Map<String, dynamic>>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    return _send('PATCH', path, body: body, headers: headers, token: token);
  }

  /// Performs an HTTP DELETE request.
  Future<ApiResponse<Map<String, dynamic>>> delete(
    String path, {
    Map<String, String>? headers,
    String? token,
  }) async {
    return _send('DELETE', path, headers: headers, token: token);
  }

  Future<ApiResponse<Map<String, dynamic>>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = timeout;

    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = await client.openUrl(method, uri).timeout(timeout);

      // Default headers
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        ApiConstants.contentTypeJson,
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        ApiConstants.contentTypeJson,
      );

      // Token authorization header
      if (token != null && token.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          '${ApiConstants.bearerPrefix}$token',
        );
      }

      // Custom headers
      if (headers != null) {
        headers.forEach((key, value) {
          request.headers.set(key, value);
        });
      }

      // Request body
      if (body != null) {
        final bodyBytes = utf8.encode(jsonEncode(body));
        request.add(bodyBytes);
      }

      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decodeStream(response).timeout(timeout);

      Map<String, dynamic>? parsedData;
      if (responseBody.isNotEmpty) {
        try {
          final decoded = jsonDecode(responseBody);
          if (decoded is Map<String, dynamic>) {
            parsedData = decoded;
          }
        } catch (_) {
          // Non-JSON response body
        }
      }

      final isOk = response.statusCode >= 200 && response.statusCode < 300;
      final message = parsedData?['message']?.toString() ??
          (isOk ? 'Success' : 'Request failed with status ${response.statusCode}');

      return ApiResponse<Map<String, dynamic>>(
        statusCode: response.statusCode,
        isSuccess: isOk,
        data: parsedData,
        message: message,
      );
    } on SocketException catch (_) {
      return ApiResponse.error(
        statusCode: 503,
        message:
            'Cannot connect to backend server at $baseUrl. Ensure the NestJS server is running.',
      );
    } on TimeoutException catch (_) {
      return ApiResponse.error(
        statusCode: 408,
        message: 'Connection timed out while contacting backend server.',
      );
    } catch (e) {
      return ApiResponse.error(
        statusCode: 500,
        message: 'Network error: ${e.toString()}',
      );
    } finally {
      client.close(force: true);
    }
  }
}

