import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fetch_error.dart';

/// The refresh policy shared by the paired list notifiers: refetch, and on
/// failure keep whatever was showing and record the error for the banner.
/// Only a notifier with nothing loaded yet moves into the error state.
mixin GuardedRefresh<T> on AsyncNotifier<T> {
  /// Bumped by every refresh; long-running appends compare it to detect
  /// that the list they were extending has been replaced.
  int generation = 0;

  Future<void> guardedRefresh(Future<T> Function() fetch) async {
    final errors = ref.read(lastFetchErrorProvider.notifier);
    generation++;
    try {
      state = AsyncData(await fetch());
      errors.clear();
    } catch (e, st) {
      errors.record(e);
      if (state.value == null) state = AsyncError(e, st);
    }
  }
}
