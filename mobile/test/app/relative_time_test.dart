import 'package:auth_levels/app/relative_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 12, 12, 0);

  test('relativeTime buckets', () {
    expect(
      relativeTime(now.subtract(const Duration(seconds: 10)), now: now),
      'just now',
    );
    expect(
      relativeTime(now.subtract(const Duration(seconds: 59)), now: now),
      'just now',
    );
    expect(
      relativeTime(now.subtract(const Duration(minutes: 3)), now: now),
      '3 min ago',
    );
    expect(
      relativeTime(now.subtract(const Duration(hours: 2)), now: now),
      '2 h ago',
    );
    expect(
      relativeTime(now.subtract(const Duration(days: 2)), now: now),
      'Thu',
    );
    expect(
      relativeTime(now.subtract(const Duration(days: 30)), now: now),
      '13 Aug',
    );
  });

  test('minutesSeconds pads seconds', () {
    expect(minutesSeconds(102), '1:42');
    expect(minutesSeconds(5), '0:05');
    expect(minutesSeconds(0), '0:00');
  });
}
