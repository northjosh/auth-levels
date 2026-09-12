import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

/// The paired lists that report fetch failures.
enum FetchSource { pushRequests, securityEvents }

/// The failures of the paired list fetches, tracked per source so one list
/// succeeding does not hide the other failing. Lists keep showing their
/// last data; the Account tab turns the surviving error into a "Can't
/// reach …" banner. Null when every source last succeeded.
class LastFetchError extends Notifier<ApiError?> {
  final _bySource = <FetchSource, ApiError>{};

  @override
  ApiError? build() => null;

  void record(FetchSource source, Object error) {
    _bySource[source] = error is ApiError ? error : _unexpected(error);
    _publish();
  }

  void clear(FetchSource source) {
    _bySource.remove(source);
    _publish();
  }

  /// Unpaired: nothing is being fetched any more.
  void reset() {
    _bySource.clear();
    _publish();
  }

  /// An unreachable backend is the message worth showing when sources
  /// disagree.
  void _publish() {
    state = _bySource.values.fold<ApiError?>(
      null,
      (best, e) =>
          best == null || (e.isUnreachable && !best.isUnreachable) ? e : best,
    );
  }

  static ApiError _unexpected(Object error) => ApiError(
    status: 0,
    error: 'unexpected',
    message: 'Something went wrong: $error',
  );
}

final lastFetchErrorProvider = NotifierProvider<LastFetchError, ApiError?>(
  LastFetchError.new,
);
