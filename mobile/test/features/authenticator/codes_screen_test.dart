import 'dart:async';

import 'package:auth_levels/app/app.dart';
import 'package:auth_levels/core/storage/secure_store.dart';
import 'package:auth_levels/features/authenticator/code_format.dart';
import 'package:auth_levels/features/authenticator/ticker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const link =
    'otpauth://totp/GitHub:northjosh?secret=JBSWY3DPEHPK3PXP&issuer=GitHub';

final groupedCode = RegExp(r'^\d{3} \d{3}$');

void main() {
  test('groupCode splits 6 digits as 3+3 and 8 digits as 4+4', () {
    expect(groupCode('123456'), '123 456');
    expect(groupCode('12345678'), '1234 5678');
  });

  group('Codes tab', () {
    late InMemorySecureStore store;
    late List<String> clipboard;
    // Fake-async pumps don't move DateTime.now(), so the test drives the
    // ticker itself instead of waiting for the real periodic stream.
    late StreamController<DateTime> ticks;

    setUp(() {
      store = InMemorySecureStore();
      clipboard = [];
      ticks = StreamController<DateTime>.broadcast();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard.add((call.arguments as Map)['text'] as String);
            }
            return null;
          });
    });
    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      await ticks.close();
    });

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStoreProvider.overrideWithValue(store),
            tickerProvider.overrideWith((ref) => ticks.stream),
          ],
          child: const AuthLevelsApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> addViaPaste(WidgetTester tester, String uri) async {
      await tester.tap(find.byTooltip('Add account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste otpauth:// link'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), uri);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
    }

    double ringValue(WidgetTester tester) => tester
        .widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .value!;

    testWidgets('add via paste, see a live code, copy, remove', (tester) async {
      await pumpApp(tester);
      await addViaPaste(tester, link);

      expect(find.text('No accounts yet'), findsNothing);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('northjosh'), findsOneWidget);
      final codeFinder = find.textContaining(groupedCode);
      expect(codeFinder, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The shared ticker drives the countdown ring.
      final before = ringValue(tester);
      ticks.add(DateTime.now().add(const Duration(seconds: 10)));
      await tester.pumpAndSettle();
      expect(ringValue(tester), isNot(before));

      // Tap copies the code and toasts it.
      final shown = tester.widget<Text>(codeFinder).data!;
      await tester.tap(find.text('GitHub'));
      await tester.pump();
      expect(clipboard, [shown.replaceAll(' ', '')]);
      expect(find.text('Copied $shown'), findsOneWidget);

      // Survives a restart.
      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester);
      expect(find.text('GitHub'), findsOneWidget);

      // Long-press → Remove → confirm.
      await tester.longPress(find.text('GitHub'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.textContaining('GitHub (northjosh)'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('No accounts yet'), findsOneWidget);
      expect(store.values.containsKey('otp:index'), isTrue);
    });

    testWidgets('a bad link shows the parser message inline', (tester) async {
      await pumpApp(tester);
      await addViaPaste(tester, 'https://example.com');

      expect(find.text('This is not an otpauth:// link.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('a duplicate asks before replacing', (tester) async {
      await pumpApp(tester);
      await addViaPaste(tester, link);
      await addViaPaste(
        tester,
        'otpauth://totp/GitHub:northjosh?secret=GEZDGNBVGY3TQOJQ&issuer=GitHub',
      );
      await tester.pumpAndSettle();

      expect(find.text('Replace existing?'), findsOneWidget);
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      expect(find.text('GitHub'), findsOneWidget);
      expect(store.values.values.join(), contains('GEZDGNBVGY3TQOJQ'));
      expect(store.values.values.join(), isNot(contains('JBSWY3DPEHPK3PXP')));
    });

    testWidgets('manual entry with the advanced fold', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Add account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter details manually'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Issuer'),
        'Cloudflare',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Account'), 'josh');
      await tester.enterText(
        find.widgetWithText(TextField, 'Secret'),
        'jbsw y3dp ehpk 3pxp',
      );
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8'));
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Cloudflare'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\d{4} \d{4}$')), findsOneWidget);
    });
  });
}
