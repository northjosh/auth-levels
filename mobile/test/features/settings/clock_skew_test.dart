import 'package:auth_levels/features/settings/clock_skew.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  final now = DateTime.utc(2026, 9, 12, 12, 0, 0);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  ClockSkew skew() => container.read(clockSkewProvider.notifier);
  Duration? state() => container.read(clockSkewProvider);

  test('small drift stays quiet', () {
    skew().observe(now.add(const Duration(seconds: 19)), deviceNow: now);
    expect(state(), isNull);
  });

  test('drift over the threshold is reported, either direction', () {
    skew().observe(now.add(const Duration(seconds: 90)), deviceNow: now);
    expect(state(), const Duration(seconds: 90));
    skew().observe(now.subtract(const Duration(seconds: 45)), deviceNow: now);
    expect(state(), const Duration(seconds: -45));
  });

  test('dismiss hides it until the drift moves', () {
    skew().observe(now.add(const Duration(seconds: 90)), deviceNow: now);
    skew().dismiss();
    expect(state(), isNull);

    skew().observe(now.add(const Duration(seconds: 92)), deviceNow: now);
    expect(state(), isNull, reason: 'same drift, stays dismissed');

    skew().observe(now.add(const Duration(seconds: 120)), deviceNow: now);
    expect(state(), const Duration(seconds: 120));
  });

  test('a clock that comes back in line clears it', () {
    skew().observe(now.add(const Duration(seconds: 90)), deviceNow: now);
    skew().observe(now.add(const Duration(seconds: 2)), deviceNow: now);
    expect(state(), isNull);
  });
}
