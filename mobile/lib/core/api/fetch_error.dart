import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

/// The most recent failure of a paired list fetch (Push Requests, Security
/// Events), or null after the last success. Lists keep showing their last
/// data; the Account tab turns this into a "Can't reach …" banner.
class LastFetchError extends Notifier<ApiError?> {
  @override
  ApiError? build() => null;

  void record(Object error) =>
      state = error is ApiError ? error : _unexpected(error);

  void clear() => state = null;

  static ApiError _unexpected(Object error) => ApiError(
    status: 0,
    error: 'unexpected',
    message: 'Something went wrong: $error',
  );
}

final lastFetchErrorProvider = NotifierProvider<LastFetchError, ApiError?>(
  LastFetchError.new,
);
