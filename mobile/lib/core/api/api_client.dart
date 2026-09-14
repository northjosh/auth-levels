import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'models.dart';

/// HTTP client for the auth-levels backend. Sends the Device Token when
/// there is one, unwraps the `{code, message, data, url}` envelope, and
/// turns every failure into an [ApiError]. A `device_revoked` reply also
/// fires [onRevoked] so the binding can be dropped.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.deviceToken,
    this.onRevoked,
    this.onServerDate,
    @visibleForTesting Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 5)
      ..receiveTimeout = const Duration(seconds: 10)
      // Status handling lives in [_unwrap]; never throw on 4xx/5xx.
      ..validateStatus = (_) => true;
    if (deviceToken != null) {
      _dio.options.headers['Authorization'] = 'Bearer $deviceToken';
    }
  }

  final String baseUrl;
  final String? deviceToken;
  final void Function()? onRevoked;

  /// The backend's clock, from the `Date` header of every successful
  /// reply; feeds the clock-skew warning.
  final void Function(DateTime serverDate)? onServerDate;
  final Dio _dio;

  Future<T> get<T>(String path, {Map<String, Object?>? query}) =>
      _send<T>('GET', path, query: query);

  Future<T> post<T>(String path, {Object? body}) =>
      _send<T>('POST', path, body: body);

  Future<T> put<T>(String path, {Object? body}) =>
      _send<T>('PUT', path, body: body);

  Future<T> delete<T>(String path) => _send<T>('DELETE', path);

  Future<T> _send<T>(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
  }) async {
    final Response<Object?> response;
    try {
      response = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
    } on DioException catch (e) {
      // With validateStatus always true only transport-level failures reach
      // here: no connection, timeouts, TLS, or a cancelled request.
      throw switch (e.type) {
        DioExceptionType.cancel => ApiError(
          status: 0,
          error: ApiError.cancelledCode,
          message: 'Request cancelled',
        ),
        _ => ApiError.unreachable(baseUrl),
      };
    }
    return _unwrap<T>(response);
  }

  T _unwrap<T>(Response<Object?> response) {
    final status = response.statusCode ?? 0;
    final body = response.data;
    if (status >= 200 && status < 300) _reportServerDate(response);

    if (body is Map<String, Object?> && body['code'] is int) {
      if (body['code'] == 0 && status < 400) return body['data'] as T;
      final data = body['data'];
      final details = data is Map<String, Object?> ? data : const {};
      throw _fail(
        ApiError(
          status: details['errorCode'] as int? ?? status,
          error: details['error'] as String? ?? 'http_$status',
          message: details['errorMessage'] as String? ?? 'Request failed',
          attemptsLeft: details['attemptsLeft'] as int?,
        ),
      );
    }

    // No envelope: a 204, or something that is not this backend.
    if (status >= 200 && status < 300 && null is T) return null as T;
    throw _fail(
      ApiError(
        status: status,
        error: 'http_$status',
        message: 'Unexpected response from $baseUrl (HTTP $status)',
      ),
    );
  }

  ApiError _fail(ApiError error) {
    if (error.isRevoked) onRevoked?.call();
    return error;
  }

  void _reportServerDate(Response<Object?> response) {
    final onServerDate = this.onServerDate;
    final header = response.headers.value('date');
    if (onServerDate == null || header == null) return;
    try {
      onServerDate(HttpDate.parse(header));
    } on FormatException {
      // A proxy that mangles Date is not worth a warning.
    }
  }
}
