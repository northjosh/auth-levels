import 'dart:io';

import 'package:auth_levels/core/storage/secure_store.dart';
import 'package:auth_levels/features/activity/security_events.dart';
import 'package:auth_levels/features/pairing/binding.dart';
import 'package:auth_levels/features/pairing/device_identity.dart';
import 'package:auth_levels/features/pairing/pairing_link.dart';
import 'package:auth_levels/features/requests/push_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart' show Request;
import 'package:shelf/shelf_io.dart' as io;
import 'package:stub_server/stub_server.dart';

import '../../helpers/fake_device_api.dart';

/// The real client against the real stub: a device the backend no longer
/// knows gets 401 device_revoked on its next list fetch, and that must drop
/// the binding and raise the one-time notice.
void main() {
  late HttpServer server;
  late StubServer stub;
  late ProviderContainer container;

  setUp(() async {
    stub = StubServer();
    server = await io.serve(stub.handler, InternetAddress.loopbackIPv4, 0);
    container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        deviceIdentityProvider.overrideWith((ref) async => testIdentity),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await server.close(force: true);
  });

  test('a revoked device drops to unpaired with the notice', () async {
    final link = parsePairingLink(
      'authlevels://pair?token=ok-1&api=http://127.0.0.1:${server.port}',
    );
    await container.read(bindingProvider.notifier).pair(link);
    expect(await container.read(pushRequestsProvider.future), isNotEmpty);

    await stub.handler(
      Request('POST', Uri.parse('http://127.0.0.1:${server.port}/__revoke')),
    );
    await container.read(pushRequestsProvider.notifier).refresh();
    await container.read(securityEventsProvider.notifier).refresh();
    // Let the revoke's own async work land.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await container.read(bindingProvider.future), isNull);
    expect(container.read(revokedNoticeProvider), isTrue);
    expect(await container.read(pushRequestsProvider.future), isEmpty);
  });
}
