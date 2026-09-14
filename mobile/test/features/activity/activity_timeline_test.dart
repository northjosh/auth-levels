import 'package:auth_levels/app/app.dart';
import 'package:auth_levels/core/storage/secure_store.dart';
import 'package:auth_levels/features/activity/activity_timeline.dart';
import 'package:auth_levels/features/activity/events_api.dart';
import 'package:auth_levels/features/pairing/binding.dart';
import 'package:auth_levels/features/pairing/device_api.dart';
import 'package:auth_levels/features/pairing/device_identity.dart';
import 'package:auth_levels/features/requests/push_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_device_api.dart';
import '../../helpers/fake_events_api.dart';
import '../../helpers/fake_push_api.dart';

void main() {
  late FakeEventsApi api;
  late FakePushApi push;
  final now = DateTime.now();

  setUp(() {
    push = FakePushApi();
    api = FakeEventsApi([
      eventAt(0, now: now, type: 'LOGIN_FAILURE', method: 'TOTP'),
      eventAt(
        1,
        now: now,
        type: 'TRUSTED_DEVICE_PAIRED',
        method: null,
        actor: null,
        details: {'deviceName': 'Pixel 7'},
      ),
      eventAt(2, now: now, type: 'WEIRD_TYPE', method: null),
      for (var i = 3; i < 60; i++) eventAt(i, now: now),
    ]);
  });

  Future<void> pumpPaired(WidgetTester tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
          deviceApiProvider.overrideWithValue(FakeDeviceApi()),
          deviceIdentityProvider.overrideWith((ref) async => testIdentity),
          pushApiProvider.overrideWithValue(push),
          eventsApiProvider.overrideWithValue(api),
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
  }

  testWidgets('rows: titles, subtitles, red tint, raw type', (tester) async {
    await pumpPaired(tester);

    expect(find.text('Failed TOTP sign-in'), findsOneWidget);
    expect(find.text('Chrome on Mac OS X · 127.0.0.1'), findsWidgets);
    final failed = tester.widget<Text>(find.text('Failed TOTP sign-in'));
    expect(
      failed.style?.color,
      Theme.of(tester.element(find.text('Failed TOTP sign-in')))
          .colorScheme
          .error,
    );

    expect(find.text('Pixel 7 paired'), findsOneWidget);
    expect(find.text('Pixel 7'), findsOneWidget);

    final raw = tester.widget<Text>(find.text('WEIRD_TYPE'));
    expect(raw.style?.fontFamily, 'monospace');
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolling to the end loads the next page', (tester) async {
    await pumpPaired(tester);
    expect(api.calls, hasLength(1));
    expect(find.text('That is everything.'), findsNothing);

    // The list is lazy: the sentinel builds, and asks for more, only once
    // scrolled into view.
    await tester.scrollUntilVisible(find.byKey(const ValueKey('ev-49')), 400);
    await tester.pumpAndSettle();

    expect(api.calls, hasLength(2));
    expect(api.calls.last.$2, isNotNull);
    await tester.scrollUntilVisible(find.text('That is everything.'), 400);
    expect(find.byKey(const ValueKey('ev-59')), findsOneWidget);
    expect(find.byType(ActivityRow), findsWidgets);
  });

  testWidgets('sits below the hero cards when requests are open', (
    tester,
  ) async {
    push = FakePushApi(requests: [requestAt('req-1', now: now)]);
    await pumpPaired(tester);
    final cards = tester.getTopLeft(find.text('Needs you'.toUpperCase()));
    final activity = tester.getTopLeft(find.text('Activity'.toUpperCase()));
    expect(cards.dy, lessThan(activity.dy));
  });

  testWidgets('empty state when paired with no events', (tester) async {
    api.events = [];
    await pumpPaired(tester);
    expect(find.text('No activity yet.'), findsOneWidget);
    expect(find.text('Activity'.toUpperCase()), findsOneWidget);
  });
}
