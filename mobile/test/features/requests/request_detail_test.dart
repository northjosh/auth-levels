import 'dart:async';

import 'package:auth_levels/app/app.dart';
import 'package:auth_levels/app/router.dart';
import 'package:auth_levels/core/api/models.dart';
import 'package:auth_levels/core/storage/secure_store.dart';
import 'package:auth_levels/features/authenticator/ticker.dart';
import 'package:auth_levels/features/pairing/binding.dart';
import 'package:auth_levels/features/pairing/device_api.dart';
import 'package:auth_levels/features/pairing/device_identity.dart';
import 'package:auth_levels/features/requests/push_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_device_api.dart';
import '../../helpers/fake_push_api.dart';

void main() {
  late InMemorySecureStore store;
  late FakePushApi push;
  late StreamController<DateTime> ticks;
  late DateTime now;

  setUp(() {
    store = InMemorySecureStore();
    now = DateTime.now();
    push = FakePushApi(requests: [requestAt('req-1', now: now)]);
    ticks = StreamController<DateTime>.broadcast();
  });
  tearDown(() => ticks.close());

  /// Pumps the app already paired, on the Account tab.
  Future<ProviderContainer> pumpPaired(WidgetTester tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(store),
          deviceApiProvider.overrideWithValue(FakeDeviceApi()),
          deviceIdentityProvider.overrideWith((ref) async => testIdentity),
          pushApiProvider.overrideWithValue(push),
          tickerProvider.overrideWith((ref) => ticks.stream),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const AuthLevelsApp();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await container.read(bindingProvider.notifier).pair(pairingLinkFixture);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Account'));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> openDetail(WidgetTester tester) async {
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Login request'), findsOneWidget);
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byKey(const Key('code-input')), code);
    await tester.pump();
  }

  testWidgets('hero card, badge, and the facts on the detail', (tester) async {
    await pumpPaired(tester);
    expect(find.text('Needs you'.toUpperCase()), findsOneWidget);
    expect(find.text('Chrome on Mac OS X'), findsOneWidget);
    expect(find.byType(Badge), findsWidgets);
    expect(
      tester.widgetList<Badge>(find.byType(Badge)).any((b) => b.isLabelVisible),
      isTrue,
    );

    await openDetail(tester);
    expect(find.text('Chrome on Mac OS X'), findsWidgets);
    expect(find.text('127.0.0.1'), findsOneWidget);
    expect(find.text('3 attempts left'), findsOneWidget);
    expect(find.text('until this request expires'), findsOneWidget);
  });

  testWidgets('right code → Approved → back to Account, list refetched', (
    tester,
  ) async {
    await pumpPaired(tester);
    await openDetail(tester);
    final listCallsBefore = push.listCalls;

    await enterCode(tester, '482019');
    await tester.tap(find.text('Approve login'));
    await tester.pumpAndSettle();

    expect(find.text('Approved'), findsOneWidget);
    expect(push.verifyCalls, [('req-1', '482019')]);
    expect(push.listCalls, greaterThan(listCallsBefore));

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Login request'), findsNothing);
    expect(find.text('Needs you'.toUpperCase()), findsNothing);
    expect(find.text('Chrome on Mac OS X'), findsNothing);
  });

  testWidgets('wrong codes count down, the third one makes it gone', (
    tester,
  ) async {
    await pumpPaired(tester);
    await openDetail(tester);

    for (final expected in ['2 attempts left', '1 attempt left']) {
      await enterCode(tester, '000000');
      await tester.tap(find.text('Approve login'));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('code-input')))
            .controller!
            .text,
        isEmpty,
      );
    }

    await enterCode(tester, '000000');
    await tester.tap(find.text('Approve login'));
    await tester.pumpAndSettle();
    expect(find.text('Request gone'), findsOneWidget);
    expect(find.text('Back to Account'), findsOneWidget);

    await tester.tap(find.text('Back to Account'));
    await tester.pumpAndSettle();
    expect(find.text('Needs you'.toUpperCase()), findsNothing);
  });

  testWidgets('the countdown reaching zero shows the gone state', (
    tester,
  ) async {
    await pumpPaired(tester);
    await openDetail(tester);
    expect(find.text('Request gone'), findsNothing);

    ticks.add(now.add(const Duration(minutes: 3)));
    await tester.pumpAndSettle();
    expect(find.text('Request gone'), findsOneWidget);
  });

  testWidgets('deny from the detail asks first, then pops', (tester) async {
    await pumpPaired(tester);
    await openDetail(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Deny'));
    await tester.pumpAndSettle();
    expect(find.text('Deny this login?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Deny'));
    await tester.pumpAndSettle();

    expect(find.text('Denied'), findsOneWidget);
    expect(push.denyCalls, ['req-1']);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Login request'), findsNothing);
  });

  testWidgets('deny from the hero card', (tester) async {
    await pumpPaired(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Deny'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Deny'));
    await tester.pumpAndSettle();
    expect(push.denyCalls, ['req-1']);
    expect(find.text('Chrome on Mac OS X'), findsNothing);
  });

  testWidgets('an unknown id opened directly is gone, never an error', (
    tester,
  ) async {
    final container = await pumpPaired(tester);
    container.read(routerProvider).push(Routes.request('nope'));
    await tester.pumpAndSettle();
    expect(find.text('Request gone'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backend down on approve → inline error, request stays', (
    tester,
  ) async {
    await pumpPaired(tester);
    await openDetail(tester);
    push.failure = ApiError.unreachable('http://10.0.2.2:8002');

    await enterCode(tester, '482019');
    await tester.tap(find.text('Approve login'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Can't reach"), findsOneWidget);
    expect(find.text('Approve login'), findsOneWidget);
    expect(find.text('3 attempts left'), findsOneWidget);
  });

  testWidgets('a request that runs out drops off the card list and badge', (
    tester,
  ) async {
    await pumpPaired(tester);
    expect(find.text('Chrome on Mac OS X'), findsOneWidget);

    ticks.add(now.add(const Duration(minutes: 3)));
    await tester.pumpAndSettle();

    expect(find.text('Chrome on Mac OS X'), findsNothing);
    expect(
      tester.widgetList<Badge>(find.byType(Badge)).any((b) => b.isLabelVisible),
      isFalse,
    );
  });

  testWidgets('a cold-start deep link can still get back to Account', (
    tester,
  ) async {
    final container = await pumpPaired(tester);
    container.read(routerProvider).go(Routes.request('nope'));
    await tester.pumpAndSettle();
    expect(find.text('Request gone'), findsOneWidget);

    await tester.tap(find.text('Back to Account'));
    await tester.pumpAndSettle();
    expect(find.text('Paired as joshua@terydin.co'), findsOneWidget);
  });

  testWidgets('pull-to-refresh refetches the list', (tester) async {
    await pumpPaired(tester);
    final before = push.listCalls;
    await tester.fling(
      find.text('Paired as joshua@terydin.co'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(push.listCalls, greaterThan(before));
  });
}
