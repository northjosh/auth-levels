import 'dart:convert';

import 'package:auth_levels/core/api/models.dart';
import 'package:auth_levels/core/storage/secure_store.dart';
import 'package:auth_levels/features/pairing/binding.dart';
import 'package:auth_levels/features/pairing/device_api.dart';
import 'package:auth_levels/features/pairing/device_identity.dart';
import 'package:auth_levels/features/pairing/pairing_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_device_api.dart';

final link = parsePairingLink(
  'authlevels://pair?token=ok-1&api=http://10.0.2.2:8002&email=joshua%40terydin.co',
);

void main() {
  late InMemorySecureStore store;
  late FakeDeviceApi api;
  late ProviderContainer container;

  ProviderContainer newContainer() => ProviderContainer(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
      deviceApiProvider.overrideWithValue(api),
      deviceIdentityProvider.overrideWith((ref) async => testIdentity),
    ],
  );

  setUp(() {
    store = InMemorySecureStore();
    api = FakeDeviceApi();
    container = newContainer();
  });
  tearDown(() => container.dispose());

  Future<TrustedDeviceBinding?> binding() =>
      container.read(bindingProvider.future);
  Binding notifier() => container.read(bindingProvider.notifier);

  test('unpaired when nothing is stored', () async {
    expect(await binding(), isNull);
    expect(container.read(apiClientProvider), isNull);
  });

  test(
    'pair calls the API with the device identity and stores the binding',
    () async {
      await binding();
      await notifier().pair(link);

      expect(api.pairCalls.single.$1, 'http://10.0.2.2:8002');
      final sent = api.pairCalls.single.$2;
      expect(sent.enrollmentToken, 'ok-1');
      expect(sent.fcmToken, isNull);
      expect(sent.name, 'Android emulator');
      expect(sent.platform, 'android');
      expect(sent.appVersion, '0.1.0');

      final stored = (await binding())!;
      expect(stored.deviceToken, FakeDeviceApi.deviceToken);
      expect(stored.apiBaseUrl, 'http://10.0.2.2:8002');
      expect(stored.user.email, 'joshua@terydin.co');
      expect(stored.deviceName, 'Android emulator');
      expect(stored.pairedAt.isUtc, isTrue);

      final json = jsonDecode(store.values['device:binding']!) as Map;
      expect(json['deviceToken'], FakeDeviceApi.deviceToken);
      expect(json['apiBaseUrl'], 'http://10.0.2.2:8002');

      final client = container.read(apiClientProvider)!;
      expect(client.baseUrl, 'http://10.0.2.2:8002');
      expect(client.deviceToken, FakeDeviceApi.deviceToken);
    },
  );

  test('the binding survives a restart', () async {
    await binding();
    await notifier().pair(link);

    final fresh = newContainer();
    addTearDown(fresh.dispose);
    final reloaded = await fresh.read(bindingProvider.future);
    expect(reloaded?.deviceId, FakeDeviceApi.deviceId);
  });

  test('refuses to pair twice', () async {
    await binding();
    await notifier().pair(link);
    expect(() => notifier().pair(link), throwsA(isA<AlreadyPairedException>()));
    expect(api.pairCalls, hasLength(1));
  });

  test('a pairing failure leaves the app unpaired', () async {
    await binding();
    api.pairError = const ApiError(
      status: 410,
      error: 'enrollment_expired',
      message: 'expired',
    );
    await expectLater(notifier().pair(link), throwsA(isA<ApiError>()));
    expect(await binding(), isNull);
    expect(store.values.containsKey('device:binding'), isFalse);
  });

  test('unpair calls DELETE /devices/me and wipes everything', () async {
    await binding();
    await notifier().pair(link);
    await notifier().unpair();

    expect(api.unpairCalls, 1);
    expect(await binding(), isNull);
    expect(store.values.containsKey('device:binding'), isFalse);
    expect(container.read(apiClientProvider), isNull);
  });

  test(
    'unpair still wipes when the backend already revoked the device',
    () async {
      await binding();
      await notifier().pair(link);
      api.unpairError = const ApiError(
        status: 401,
        error: 'device_revoked',
        message: 'gone',
      );
      await notifier().unpair();
      expect(await binding(), isNull);
    },
  );

  test('revoked wipes the binding and raises the one-time notice', () async {
    await binding();
    await notifier().pair(link);
    expect(container.read(revokedNoticeProvider), isFalse);

    await notifier().revoked();

    expect(await binding(), isNull);
    expect(container.read(revokedNoticeProvider), isTrue);
    container.read(revokedNoticeProvider.notifier).dismiss();
    expect(container.read(revokedNoticeProvider), isFalse);
  });

  test('an unreadable stored binding is treated as unpaired', () async {
    store.values['device:binding'] = '{nope';
    expect(await binding(), isNull);
  });
}
