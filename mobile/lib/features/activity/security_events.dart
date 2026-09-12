import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/fetch_error.dart';
import '../../core/api/guarded_refresh.dart';
import '../../core/api/models.dart';
import '../pairing/binding.dart';
import 'events_api.dart';

/// What the timeline has loaded so far.
class PagedEvents {
  const PagedEvents({
    required this.items,
    required this.nextCursor,
    this.loadingMore = false,
  });

  static const empty = PagedEvents(items: [], nextCursor: null);

  final List<SecurityEvent> items;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  PagedEvents withLoadingMore(bool loadingMore) => PagedEvents(
    items: items,
    nextCursor: nextCursor,
    loadingMore: loadingMore,
  );
}

/// Security Events for the paired account: the first page on first watch,
/// older pages through [loadMore], a fresh first page through [refresh].
/// Empty while unpaired.
class SecurityEvents extends AsyncNotifier<PagedEvents>
    with GuardedRefresh<PagedEvents> {
  static const pageSize = 50;

  @override
  Future<PagedEvents> build() => _firstPage(ref.watch(apiClientProvider));

  Future<PagedEvents> _firstPage(ApiClient? client) async {
    if (client == null) return PagedEvents.empty;
    final page = await ref
        .read(eventsApiProvider)
        .list(client, limit: pageSize);
    return PagedEvents(items: page.items, nextCursor: page.nextCursor);
  }

  /// Reloads the newest page and resets paging; a failure keeps the current
  /// list (see [GuardedRefresh]).
  Future<void> refresh() =>
      guardedRefresh(() => _firstPage(ref.read(apiClientProvider)));

  /// Appends the next page, if there is one and none is in flight. A page
  /// that lands after a [refresh] started is dropped: it would extend a
  /// list that no longer exists.
  Future<void> loadMore() async {
    final current = state.value;
    final client = ref.read(apiClientProvider);
    if (current == null || !current.hasMore || current.loadingMore) return;
    if (client == null) return;

    final startedIn = generation;
    state = AsyncData(current.withLoadingMore(true));
    try {
      final page = await ref
          .read(eventsApiProvider)
          .list(client, limit: pageSize, before: current.nextCursor);
      if (startedIn != generation) return;
      final seen = {for (final e in current.items) e.id};
      state = AsyncData(
        PagedEvents(
          items: [
            ...current.items,
            for (final e in page.items)
              if (!seen.contains(e.id)) e,
          ],
          nextCursor: page.nextCursor,
        ),
      );
      ref.read(lastFetchErrorProvider.notifier).clear();
    } catch (e) {
      if (startedIn != generation) return;
      ref.read(lastFetchErrorProvider.notifier).record(e);
      state = AsyncData(current.withLoadingMore(false));
    }
  }
}

final securityEventsProvider =
    AsyncNotifierProvider<SecurityEvents, PagedEvents>(SecurityEvents.new);
