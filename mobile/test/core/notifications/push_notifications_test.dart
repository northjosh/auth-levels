import 'package:auth_levels/app/app.dart';
import 'package:auth_levels/app/router.dart';
import 'package:auth_levels/core/notifications/push_gateway.dart';
import 'package:auth_levels/core/notifications/push_notifications.dart';
import 'package:auth_levels/core/storage/secure_store.dart';
import 'package:auth_levels/features/pairing/binding.dart';
import 'package:auth_levels/features/pairing/device_api.dart';
import 'package:auth_levels/features/pairing/device_identity.dart';
import 'package:auth_levels/features/requests/push_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_device_api.dart';
import '../../helpers/fake_push_api.dart';
import '../../helpers/fake_push_gateway.dart';

void main() {
  late InMemorySecureStore store;
  late FakeDeviceApi deviceApi;
  late FakePushApi push;
  late FakePushGateway gateway;
  late FakePresenter presenter;
  final now = DateTime.now();

  setUp(() {
    store = InMemorySecureStore();
    deviceApi = FakeDeviceApi();
    push = FakePushApi(requests: [requestAt('req-1', now: now)]);
    gateway = FakePushGateway();
    presenter = FakePresenter();
  });
  tearDown(() => gateway.close());

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        deviceApiProvider.overrideWithValue(deviceApi),
        deviceIdentityProvider.overrideWith((ref) async => testIdentity),
        pushApiProvider.overrideWithValue(push),
        pushGatewayProvider.overrideWithValue(gateway),
        notificationPresenterProvider.overrideWithValue(presenter),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AuthLevelsApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('pairing asks for permission and sends the FCM token', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await container.read(bindingProvider.notifier).pair(pairingLinkFixture);

    expect(gateway.permissionRequests, 1);
    expect(deviceApi.pairCalls.single.$2.fcmToken, 'fcm-token-1');
    expect(store.values['device:fcmToken'], 'fcm-token-1');
    expect(await container.read(fcmTokenProvider.future), 'fcm-token-1');
  });

  testWidgets('denied permission pairs with a null token', (tester) async {
    gateway.granted = false;
    final container = await pumpApp(tester);
    await container.read(bindingProvider.notifier).pair(pairingLinkFixture);

    expect(deviceApi.pairCalls.single.$2.fcmToken, isNull);
    expect(store.values.containsKey('device:fcmToken'), isFalse);
  });

  testWidgets('a foreground message shows a notification and refetches', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await container.read(bindingProvider.notifier).pair(pairingLinkFixture);
    await container.read(pushNotificationsProvider).start();
    final listCalls = push.listCalls;

    gateway.foregroundController.add(pushMessage('req-1'));
    await tester.pumpAndSettle();

    expect(presenter.shown.single.requestId, 'req-1');
    expect(presenter.shown.single.title, 'Login request');
    expect(push.listCalls, greaterThan(listCalls));
  });

  testWidgets('a background tap opens the request detail', (tester) async {
    final container = await pumpApp(tester);
    await container.read(bindingProvider.notifier).pair(pairingLinkFixture);
    await container.read(pushNotificationsProvider).start();

    gateway.openedController.add(pushMessage('req-1'));
    await tester.pumpAndSettle();

    expect(find.text('Login request'), findsOneWidget);
    expect(find.text('Chrome on Mac OS X'), findsWidgets);
    // Opening the detail dismisses the tray notification.
    expect(presenter.cancelled, contains('req-1'));
  });

  testWidgets('the launch message from a terminated state opens the detail', (
    tester,
  ) async {
    gateway.initial = pushMessage('nope');
    final container = await pumpApp(tester);
    await container.read(pushNotificationsProvider).start();
    await tester.pumpAndSettle();

    expect(find.text('Login request'), findsOneWidget);
    expect(find.text('Request gone'), findsOneWidget);
    expect(
      container.read(routerProvider).state.uri.path,
      Routes.request('nope'),
    );
  });

  testWidgets('a local notification tap routes the same way', (tester) async {
    final container = await pumpApp(tester);
    await container.read(bindingProvider.notifier).pair(pairingLinkFixture);
    await container.read(pushNotificationsProvider).start();

    presenter.onTap!('req-1');
    await tester.pumpAndSettle();
    expect(find.text('Login request'), findsOneWidget);
  });

  testWidgets('a token refresh while paired is PUT to the backend once', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await container.read(bindingProvider.notifier).pair(pairingLinkFixture);
    await container.read(pushNotificationsProvider).start();

    gateway.tokenRefreshController.add('fcm-token-2');
    await tester.pumpAndSettle();
    gateway.tokenRefreshController.add('fcm-token-2');
    await tester.pumpAndSettle();

    expect(deviceApi.fcmTokens, ['fcm-token-2']);
    expect(store.values['device:fcmToken'], 'fcm-token-2');
  });

  testWidgets('a token refresh while unpaired is ignored', (tester) async {
    final container = await pumpApp(tester);
    await container.read(pushNotificationsProvider).start();
    gateway.tokenRefreshController.add('fcm-token-2');
    await tester.pumpAndSettle();
    expect(deviceApi.fcmTokens, isEmpty);
  });

  testWidgets('unpairing forgets the token', (tester) async {
    final container = await pumpApp(tester);
    final binding = container.read(bindingProvider.notifier);
    await binding.pair(pairingLinkFixture);
    await binding.unpair();
    expect(store.values.containsKey('device:fcmToken'), isFalse);
    expect(presenter.cancelledAll, 1);
  });

  testWidgets('a revoke clears every pending notification', (tester) async {
    final container = await pumpApp(tester);
    final binding = container.read(bindingProvider.notifier);
    await binding.pair(pairingLinkFixture);
    await binding.revoked();
    expect(presenter.cancelledAll, 1);
  });

  test('notifications share the id FCM uses, so cancel clears either', () {
    expect(pushNotificationId, 0);
  });
}
