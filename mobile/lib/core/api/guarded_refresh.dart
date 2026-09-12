import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fetch_error.dart';

/// The fetch policy shared by the paired list notifiers: every fetch, first
/// or refresh, reports its outcome to [lastFetchErrorProvider]; a refresh
/// that fails keeps whatever was showing. Only a notifier with nothing
/// loaded yet moves into the error state.
mixin GuardedRefresh<T> on AsyncNotifier<T> {
  FetchSource get fetchSource;

  /// Bumped by every refresh; long-running appends compare it to detect
  /// that the list they were extending has been replaced.
  int generation = 0;

  /// For `build()`: the fetch's outcome is recorded, then the result or
  /// error propagates as usual.
  Future<T> guardedFetch(Future<T> Function() fetch) async {
    final errors = ref.read(lastFetchErrorProvider.notifier);
    try {
      final result = await fetch();
      errors.clear(fetchSource);
      return result;
    } catch (e) {
      errors.record(fetchSource, e);
      rethrow;
    }
  }

  Future<void> guardedRefresh(Future<T> Function() fetch) async {
    generation++;
    try {
      state = AsyncData(await guardedFetch(fetch));
    } catch (e, st) {
      if (state.value == null) state = AsyncError(e, st);
    }
  }
}
