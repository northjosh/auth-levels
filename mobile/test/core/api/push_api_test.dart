import 'dart:io';

import 'package:auth_levels/core/api/api_client.dart';
import 'package:auth_levels/features/pairing/device_api.dart';
import 'package:auth_levels/features/requests/push_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart' show Request;
import 'package:shelf/shelf_io.dart' as io;
import 'package:stub_server/stub_server.dart';

void main() {
  late HttpServer server;
  late StubServer stub;
  late String baseUrl;
  late ApiClient client;

  setUp(() async {
    stub = StubServer();
    server = await io.serve(stub.handler, InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';

    final paired = await const HttpDeviceApi().pair(
      baseUrl,
      const PairRequest(
        enrollmentToken: 'ok-push',
        fcmToken: 'fid-1',
        name: 'Test phone',
        platform: 'android',
        appVersion: '0.1.0',
      ),
    );
    client = ApiClient(baseUrl: baseUrl, deviceToken: paired.deviceToken);
  });

  tearDown(() => server.close(force: true));

  test('lists and verifies through the request resource path', () async {
    const api = HttpPushApi();
    final request = (await api.list(client)).single;

    await api.verify(client, request.requestId, stub.seededOtp);

    expect(await api.list(client), isEmpty);
  });

  test('denies through the request resource path', () async {
    const api = HttpPushApi();
    await stub.handler(Request('POST', Uri.parse('$baseUrl/__push')));
    final requests = await api.list(client);
    final request = requests.first;

    await api.deny(client, request.requestId);

    expect(
      (await api.list(client))
          .any((item) => item.requestId == request.requestId),
      isFalse,
    );
  });
}
