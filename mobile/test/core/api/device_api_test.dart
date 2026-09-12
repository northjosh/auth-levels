import 'dart:io';

import 'package:auth_levels/core/api/api_client.dart';
import 'package:auth_levels/core/api/models.dart';
import 'package:auth_levels/features/pairing/device_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart' show Request;
import 'package:shelf/shelf_io.dart' as io;
import 'package:stub_server/stub_server.dart';

/// Runs the contract stub in-process and drives the real HTTP client
/// against it, so envelope unwrapping, error codes and the Device Token
/// header are exercised end to end.
void main() {
  late HttpServer server;
  late StubServer stub;
  late String baseUrl;

  const request = PairRequest(
    enrollmentToken: 'ok-1',
    fcmToken: null,
    name: 'Test phone',
    platform: 'android',
    appVersion: '0.1.0',
  );

  setUp(() async {
    stub = StubServer();
    server = await io.serve(stub.handler, InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
  });
  tearDown(() => server.close(force: true));

  test('pair returns the device token and user', () async {
    final result = await const HttpDeviceApi().pair(baseUrl, request);
    expect(result.deviceId, isNotEmpty);
    expect(result.deviceToken, hasLength(43));
    expect(result.user.email, StubServer.user['email']);
    expect(result.user.firstName, StubServer.user['firstName']);
  });

  test('an expired token is a 410 enrollment_expired ApiError', () async {
    expect(
      () => const HttpDeviceApi().pair(
        baseUrl,
        const PairRequest(
          enrollmentToken: 'expired-1',
          fcmToken: null,
          name: 'p',
          platform: 'ios',
          appVersion: '0',
        ),
      ),
      throwsA(
        isA<ApiError>()
            .having((e) => e.status, 'status', 410)
            .having((e) => e.error, 'error', 'enrollment_expired')
            .having((e) => e.message, 'message', isNotEmpty),
      ),
    );
  });

  test('a closed port is an unreachable ApiError naming the URL', () async {
    final dead = 'http://127.0.0.1:1';
    expect(
      () => const HttpDeviceApi().pair(dead, request),
      throwsA(
        isA<ApiError>()
            .having((e) => e.isUnreachable, 'isUnreachable', isTrue)
            .having((e) => e.message, 'message', contains(dead)),
      ),
    );
  });

  test('a paired client sends the Device Token and can unpair', () async {
    final paired = await const HttpDeviceApi().pair(baseUrl, request);
    final client = ApiClient(baseUrl: baseUrl, deviceToken: paired.deviceToken);

    final requests = await client.get<List<dynamic>>('/push/get');
    expect(requests, isNotEmpty);

    await const HttpDeviceApi().unpair(client);
    expect(
      () => client.get<List<dynamic>>('/push/get'),
      throwsA(isA<ApiError>().having((e) => e.isRevoked, 'isRevoked', isTrue)),
    );
  });

  test('device_revoked triggers onRevoked once per call', () async {
    final paired = await const HttpDeviceApi().pair(baseUrl, request);
    var revoked = 0;
    final client = ApiClient(
      baseUrl: baseUrl,
      deviceToken: paired.deviceToken,
      onRevoked: () => revoked++,
    );
    await stub.handler(Request('POST', Uri.parse('$baseUrl/__revoke')));
    await expectLater(
      client.get<Object?>('/push/get'),
      throwsA(isA<ApiError>()),
    );
    expect(revoked, 1);
  });

  test('update fcm token is a 204', () async {
    final paired = await const HttpDeviceApi().pair(baseUrl, request);
    final client = ApiClient(baseUrl: baseUrl, deviceToken: paired.deviceToken);
    await const HttpDeviceApi().updateFcmToken(client, 'fcm-1');
  });
}
