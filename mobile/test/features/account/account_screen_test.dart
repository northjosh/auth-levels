import 'package:auth_levels/app/app.dart';
import 'package:auth_levels/core/api/models.dart';
import 'package:auth_levels/core/scanner/scan_screen.dart';
import 'package:auth_levels/core/storage/secure_store.dart';
import 'package:auth_levels/features/pairing/binding.dart';
import 'package:auth_levels/features/pairing/device_api.dart';
import 'package:auth_levels/features/pairing/device_identity.dart';
import 'package:auth_levels/features/settings/settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_camera.dart';
import '../../helpers/fake_device_api.dart';

const link =
    'authlevels://pair?token=ok-1&api=http://10.0.2.2:8002&email=joshua%40terydin.co';

void main() {
  late InMemorySecureStore store;
  late FakeDeviceApi api;

  setUp(() {
    store = InMemorySecureStore();
    api = FakeDeviceApi();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(store),
          deviceApiProvider.overrideWithValue(api),
          deviceIdentityProvider.overrideWith((ref) async => testIdentity),
          scanCameraProvider.overrideWithValue(
            fakeCamera(payloads: {'scan pairing': link, 'scan junk': 'nope'}),
          ),
        ],
        child: const AuthLevelsApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Account'));
    await tester.pumpAndSettle();
  }

  Future<void> pairByPaste(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('Pair'));
    await tester.pumpAndSettle();
  }

  testWidgets('paste a link → paired → settings → unpair', (tester) async {
    await pumpApp(tester);
    expect(find.text('Pair this phone to approve logins'), findsOneWidget);

    await pairByPaste(tester, link);

    expect(find.text('Pair this phone to approve logins'), findsNothing);
    expect(find.textContaining('joshua@terydin.co'), findsOneWidget);
    expect(api.pairCalls, hasLength(1));

    // Settings sheet shows the device and the API base URL.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final sheet = find.byType(SettingsSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Android emulator')),
      findsOneWidget,
    );
    expect(find.text('http://10.0.2.2:8002'), findsOneWidget);
    expect(find.text('Push off'), findsOneWidget);

    await tester.tap(find.text('Unpair this phone'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Unpair'));
    await tester.pumpAndSettle();

    expect(api.unpairCalls, 1);
    expect(find.text('Pair this phone to approve logins'), findsOneWidget);
  });

  testWidgets('pairing survives a restart', (tester) async {
    await pumpApp(tester);
    await pairByPaste(tester, link);
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester);
    expect(find.text('Pair this phone to approve logins'), findsNothing);
    expect(find.textContaining('joshua@terydin.co'), findsOneWidget);
  });

  testWidgets('a bad link is rejected inline', (tester) async {
    await pumpApp(tester);
    await pairByPaste(tester, 'https://example.com');
    expect(find.text('This is not a pairing link.'), findsOneWidget);
    expect(api.pairCalls, isEmpty);
  });

  testWidgets('an expired token names the fix', (tester) async {
    await pumpApp(tester);
    api.pairError = const ApiError(
      status: 410,
      error: 'enrollment_expired',
      message: 'Enrollment token expired or unknown',
    );
    await pairByPaste(tester, link);
    expect(find.textContaining('expired'), findsOneWidget);
    expect(find.text('Pair this phone to approve logins'), findsOneWidget);
  });

  testWidgets('an unreachable API names the URL and the emulator hint', (
    tester,
  ) async {
    await pumpApp(tester);
    api.pairError = ApiError.unreachable('http://10.0.2.2:8002');
    await pairByPaste(tester, link);
    expect(
      find.textContaining("Can't reach http://10.0.2.2:8002"),
      findsOneWidget,
    );
    expect(find.textContaining('localhost'), findsOneWidget);
  });

  testWidgets('scanning a pairing QR pairs; junk is reported', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Scan pairing code'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('scan junk'));
    await tester.pump();
    expect(find.text('Not a pairing code'), findsOneWidget);

    await tester.tap(find.text('scan pairing'));
    await tester.pumpAndSettle();
    expect(find.textContaining('joshua@terydin.co'), findsOneWidget);
  });

  testWidgets('a revoked device drops to unpaired with a one-time banner', (
    tester,
  ) async {
    await pumpApp(tester);
    await pairByPaste(tester, link);

    final element = tester.element(find.byType(AuthLevelsApp));
    final container = ProviderScope.containerOf(element);
    await container.read(bindingProvider.notifier).revoked();
    await tester.pumpAndSettle();

    expect(find.text('This phone was unpaired from the web'), findsOneWidget);
    expect(find.text('Pair this phone to approve logins'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('This phone was unpaired from the web'), findsNothing);
  });
}
