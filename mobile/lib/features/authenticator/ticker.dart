import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One shared once-per-second clock. Every code row derives its snapshot
/// from this instead of owning a timer; it stops when no row is showing.
final tickerProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  ),
);
