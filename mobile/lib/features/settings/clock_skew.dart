import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How far this device's clock is from the backend's, measured from the
/// `Date` header of every successful paired call (spec §5). Codes are never
/// adjusted; the app only warns, because a TOTP from a wrong clock is
/// rejected server-side.
class ClockSkew extends Notifier<Duration?> {
  /// Below this the warning stays quiet; HTTP `Date` is whole seconds and
  /// a request takes a moment, so a few seconds is noise.
  static const threshold = Duration(seconds: 20);

  /// A dismissed warning comes back only when the drift moves by more than
  /// this, so the banner doesn't reappear on every call.
  static const rebound = Duration(seconds: 10);

  Duration? _dismissedAt;

  @override
  Duration? build() => null;

  void observe(DateTime serverDate, {DateTime? deviceNow}) {
    final skew = serverDate.difference(deviceNow ?? DateTime.now());
    if (skew.abs() < threshold) {
      state = null;
      _dismissedAt = null;
      return;
    }
    final dismissed = _dismissedAt;
    if (dismissed != null && (skew - dismissed).abs() < rebound) return;
    _dismissedAt = null;
    state = skew;
  }

  void dismiss() {
    _dismissedAt = state;
    state = null;
  }

  /// Unpaired: no backend to compare against any more.
  void reset() {
    _dismissedAt = null;
    state = null;
  }
}

final clockSkewProvider = NotifierProvider<ClockSkew, Duration?>(ClockSkew.new);

/// "Device clock is off by N s — codes may be rejected", dismissible. Empty
/// when there is nothing to say.
class ClockSkewBanner extends ConsumerWidget {
  const ClockSkewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skew = ref.watch(clockSkewProvider);
    if (skew == null) return const SizedBox.shrink();
    final seconds = skew.inSeconds.abs();
    final direction = skew.isNegative ? 'ahead of' : 'behind';
    return MaterialBanner(
      leading: const Icon(Icons.schedule),
      content: Text(
        'Device clock is off by $seconds s ($direction the server) — '
        'codes may be rejected',
      ),
      actions: [
        TextButton(
          onPressed: () => ref.read(clockSkewProvider.notifier).dismiss(),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }
}
