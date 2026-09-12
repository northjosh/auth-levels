import 'package:auth_levels/core/api/fetch_error.dart';
import 'package:auth_levels/core/api/models.dart';
import 'package:auth_levels/core/storage/secure_store.dart';
import 'package:auth_levels/features/pairing/binding.dart';
import 'package:auth_levels/features/pairing/device_api.dart';
import 'package:auth_levels/features/pairing/device_identity.dart';
import 'package:auth_levels/features/requests/push_api.dart';
import 'package:auth_levels/features/requests/push_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_device_api.dart';
import '../../helpers/fake_push_api.dart';

void main() {
  late FakePushApi push;
  late ProviderContainer container;
  final now = DateTime.now();

  setUp(() {
    push = FakePushApi(
      requests: [
        requestAt('old', now: now.subtract(const Duration(seconds: 30))),
        requestAt('new', now: now),
      ],
    );
    container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        deviceApiProvider.overrideWithValue(FakeDeviceApi()),
        deviceIdentityProvider.overrideWith((ref) async => testIdentity),
        pushApiProvider.overrideWithValue(push),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<List<PushRequest>> requests() =>
      container.read(pushRequestsProvider.future);

  test('empty while unpaired, no API call', () async {
    expect(await requests(), isEmpty);
    expect(push.listCalls, 0);
    expect(container.read(openPushRequestsProvider), isEmpty);
  });

  test('lists newest first once paired; open ones exclude expired', () async {
    push.requests.add(
      requestAt('stale', now: now.subtract(const Duration(minutes: 5))),
    );
    await container.read(bindingProvider.notifier).pair(pairingLinkFixture);
    expect((await requests()).map((r) => r.requestId), ['new', 'old', 'stale']);
    expect(container.read(openPushRequestsProvider).map((r) => r.requestId), [
      'new',
      'old',
    ]);
  });

  test('refresh refetches; a failure keeps the last list', () async {
    await container.read(bindingProvider.notifier).pair(pairingLinkFixture);
    await requests();
    push.requests.removeAt(0);
    await container.read(pushRequestsProvider.notifier).refresh();
    expect((await requests()).map((r) => r.requestId), ['new']);

    push.failure = ApiError.unreachable('http://10.0.2.2:8002');
    await container.read(pushRequestsProvider.notifier).refresh();
    expect(container.read(lastFetchErrorProvider)?.isUnreachable, isTrue);
    expect((await requests()).map((r) => r.requestId), ['new']);

    push.failure = null;
    await container.read(pushRequestsProvider.notifier).refresh();
    expect(container.read(lastFetchErrorProvider), isNull);
  });

  test('a failing first fetch is recorded too', () async {
    push.failure = ApiError.unreachable('http://10.0.2.2:8002');
    await container.read(bindingProvider.notifier).pair(pairingLinkFixture);
    await expectLater(requests(), throwsA(isA<ApiError>()));
    expect(container.read(lastFetchErrorProvider)?.isUnreachable, isTrue);

    await container.read(bindingProvider.notifier).unpair();
    expect(container.read(lastFetchErrorProvider), isNull);
  });

  test('remove drops one request locally', () async {
    await container.read(bindingProvider.notifier).pair(pairingLinkFixture);
    await requests();
    container.read(pushRequestsProvider.notifier).remove('new');
    expect((await requests()).map((r) => r.requestId), ['old']);
  });

  test('unpairing empties the list', () async {
    await container.read(bindingProvider.notifier).pair(pairingLinkFixture);
    await requests();
    await container.read(bindingProvider.notifier).unpair();
    expect(await requests(), isEmpty);
  });
}
