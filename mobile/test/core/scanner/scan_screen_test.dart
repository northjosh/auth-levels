import 'package:auth_levels/core/scanner/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_camera.dart';

int? acceptNumber(String raw) =>
    raw.startsWith('ok:') ? int.tryParse(raw.substring(3)) : null;

void main() {
  final defaultCamera = fakeCamera(payloads: {'junk': 'junk', 'good': 'ok:42'});

  /// Pumps a host page whose 'open' button pushes the scanner; returns a
  /// getter for the route's result.
  Future<Future<ScanOutcome<int>?> Function()> pumpScanner(
    WidgetTester tester, {
    ScanCameraBuilder? camera,
    bool manual = true,
  }) async {
    final cameraBuilder = camera ?? defaultCamera;
    late Future<ScanOutcome<int>?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              result = Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ScanScreen<int>(
                    title: 'Scan a number',
                    accept: acceptNumber,
                    rejectMessage: 'Not a number',
                    manualLabel: manual ? 'Type it instead' : null,
                    camera: cameraBuilder,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    return () => result;
  }

  testWidgets('pops with the first accepted payload', (tester) async {
    final result = await pumpScanner(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Scan a number'), findsOneWidget);

    await tester.tap(find.text('good'));
    await tester.pumpAndSettle();

    expect(find.text('Scan a number'), findsNothing);
    expect(
      await result(),
      isA<Scanned<int>>().having((s) => s.value, 'value', 42),
    );
  });

  testWidgets('a rejected payload shows the message and keeps scanning', (
    tester,
  ) async {
    final result = await pumpScanner(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('junk'));
    await tester.pump();
    expect(find.text('Not a number'), findsOneWidget);
    expect(find.text('Scan a number'), findsOneWidget);

    // The notice clears on its own.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Not a number'), findsNothing);

    await tester.tap(find.text('good'));
    await tester.pumpAndSettle();
    expect(await result(), isA<Scanned<int>>());
  });

  testWidgets('only the first accepted payload wins', (tester) async {
    final result = await pumpScanner(
      tester,
      camera: (context, host) => TextButton(
        onPressed: () {
          host.onRaw('ok:1');
          host.onRaw('ok:2');
        },
        child: const Text('burst'),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('burst'));
    await tester.pumpAndSettle();
    expect((await result() as Scanned<int>).value, 1);
  });

  group('fallback', () {
    testWidgets('permission denied offers settings and manual entry', (
      tester,
    ) async {
      final result = await pumpScanner(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Camera access'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Type it instead'), findsOneWidget);

      await tester.tap(find.text('Type it instead'));
      await tester.pumpAndSettle();
      expect(await result(), isA<ScanEnterManually<int>>());
    });

    testWidgets('no camera explains itself without a settings button', (
      tester,
    ) async {
      await pumpScanner(
        tester,
        camera: (context, host) => host.fallback(ScanFailure.noCamera),
        manual: false,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no camera'), findsOneWidget);
      expect(find.text('Open settings'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
