import 'dart:convert';

import 'package:auth_levels/core/api/api_client.dart';
import 'package:auth_levels/core/api/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with one canned response; no network.
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.status, this.body, {this.headers = const {}});

  final int status;
  final Object? body;
  final Map<String, String> headers;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final text = body == null ? '' : jsonEncode(body);
    return ResponseBody.fromString(
      text,
      status,
      headers: {
        if (body != null) Headers.contentTypeHeader: [Headers.jsonContentType],
        for (final e in headers.entries) e.key: [e.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient clientFor(int status, Object? body, {void Function()? onRevoked}) {
  final dio = Dio()..httpClientAdapter = _CannedAdapter(status, body);
  return ApiClient(
    baseUrl: 'http://stub',
    deviceToken: 'tok',
    onRevoked: onRevoked,
    dio: dio,
  );
}

Map<String, Object?> envelope(int code, Object? data) => {
  'code': code,
  'message': code == 0 ? 'Success' : 'Failed',
  'data': data,
  'url': 'http://stub/x',
};

void main() {
  test('a success envelope yields data', () async {
    final client = clientFor(200, envelope(0, {'a': 1}));
    expect(await client.get<Map<String, Object?>>('/x'), {'a': 1});
  });

  test(
    'a failure envelope becomes an ApiError with the backend code',
    () async {
      final client = clientFor(
        403,
        envelope(-1, {
          'errorCode': 403,
          'errorMessage': 'Invalid Code',
          'error': 'otp_mismatch',
          'attemptsLeft': 2,
          'url': 'http://stub/push/verify',
        }),
      );
      await expectLater(
        client.post<Object?>('/push/verify'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.status, 'status', 403)
              .having((e) => e.error, 'error', ApiError.otpMismatchCode)
              .having((e) => e.message, 'message', 'Invalid Code')
              .having((e) => e.attemptsLeft, 'attemptsLeft', 2),
        ),
      );
    },
  );

  test('code -1 on an HTTP 200 is still a failure', () async {
    final client = clientFor(200, envelope(-1, {'error': 'weird'}));
    await expectLater(
      client.get<Object?>('/x'),
      throwsA(isA<ApiError>().having((e) => e.error, 'error', 'weird')),
    );
  });

  test('a 204 is fine for void, an error for a typed result', () async {
    await clientFor(204, null).delete<void>('/devices/me');
    await expectLater(
      clientFor(204, null).get<Map<String, Object?>>('/x'),
      throwsA(isA<ApiError>().having((e) => e.error, 'error', 'http_204')),
    );
  });

  test('a non-envelope 500 names the base URL', () async {
    final client = clientFor(500, {'oops': true});
    await expectLater(
      client.get<Object?>('/x'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.status, 'status', 500)
            .having((e) => e.message, 'message', contains('http://stub')),
      ),
    );
  });

  test('a successful reply reports the server Date', () async {
    DateTime? seen;
    final dio = Dio()
      ..httpClientAdapter = _CannedAdapter(
        200,
        envelope(0, null),
        headers: {'date': 'Sat, 12 Sep 2026 12:00:00 GMT'},
      );
    final client = ApiClient(
      baseUrl: 'http://stub',
      onServerDate: (d) => seen = d,
      dio: dio,
    );
    await client.get<Object?>('/x');
    expect(seen, DateTime.utc(2026, 9, 12, 12));
  });

  test('device_revoked fires onRevoked', () async {
    var fired = 0;
    final client = clientFor(
      401,
      envelope(-1, {'errorCode': 401, 'error': 'device_revoked'}),
      onRevoked: () => fired++,
    );
    await expectLater(
      client.get<Object?>('/x'),
      throwsA(isA<ApiError>().having((e) => e.isRevoked, 'isRevoked', true)),
    );
    expect(fired, 1);
  });
}
