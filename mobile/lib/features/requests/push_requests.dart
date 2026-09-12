import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/guarded_refresh.dart';
import '../../core/api/models.dart';
import '../authenticator/ticker.dart';
import '../pairing/binding.dart';
import 'push_api.dart';

/// Push Requests as last fetched for the paired device, newest first.
/// Empty while unpaired. Fetched on first watch and on [refresh]; nothing
/// polls. Use [openPushRequestsProvider] for what is still actionable.
class PushRequests extends AsyncNotifier<List<PushRequest>>
    with GuardedRefresh<List<PushRequest>> {
  @override
  Future<List<PushRequest>> build() => _fetch(ref.watch(apiClientProvider));

  Future<List<PushRequest>> _fetch(ApiClient? client) async {
    if (client == null) return const [];
    final requests = await ref.read(pushApiProvider).list(client);
    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return requests;
  }

  /// Refetches; a failure keeps the last list (see [GuardedRefresh]).
  Future<void> refresh() =>
      guardedRefresh(() => _fetch(ref.read(apiClientProvider)));

  /// Drops a request the user has just approved, denied, or found gone,
  /// so the UI reacts before the follow-up [refresh] lands.
  void remove(String requestId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final r in current)
        if (r.requestId != requestId) r,
    ]);
  }
}

final pushRequestsProvider =
    AsyncNotifierProvider<PushRequests, List<PushRequest>>(PushRequests.new);

/// The fetched requests that have not expired yet; drives the hero cards
/// and the tab badge, and follows the ticker so a request that runs out
/// disappears without a refetch.
final openPushRequestsProvider = Provider<List<PushRequest>>((ref) {
  final now = ref.watch(tickerProvider).value ?? DateTime.now();
  final all = ref.watch(pushRequestsProvider).value ?? const [];
  return [
    for (final r in all)
      if (r.isOpen(now)) r,
  ];
});
