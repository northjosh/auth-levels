import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auth_levels/app/app.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AuthLevelsApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the Codes tab with its empty state', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Codes'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Account'), findsOneWidget);
    expect(find.text('No accounts yet'), findsOneWidget);
  });

  testWidgets('"+" on Codes opens the add-account sheet', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add account'));
    await tester.pumpAndSettle();

    expect(find.text('Add an account'), findsOneWidget);
  });

  testWidgets('Account tab shows the not-paired card', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Account'));
    await tester.pumpAndSettle();

    expect(find.text('Pair this phone to approve logins'), findsOneWidget);
    expect(find.text('No accounts yet'), findsNothing);
  });
}
