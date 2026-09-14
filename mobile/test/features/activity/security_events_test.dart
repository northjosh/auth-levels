import 'package:auth_levels/core/api/fetch_error.dart';
import 'package:auth_levels/core/api/models.dart';
import 'package:auth_levels/core/storage/secure_store.dart';
import 'package:auth_levels/features/activity/events_api.dart';
import 'package:auth_levels/features/activity/security_events.dart';
import 'package:auth_levels/features/pairing/binding.dart';
import 'package:auth_levels/features/pairing/device_api.dart';
import 'package:auth_levels/features/pairing/device_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_device_api.dart';
import '../../helpers/fake_events_api.dart';

void main() {
  late FakeEventsApi api;
  late ProviderContainer container;
  final now = DateTime.now();

  setUp(() {
    api = FakeEventsApi([for (var i = 0; i < 120; i++) eventAt(i, now: now)]);
    container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        deviceApiProvider.overrideWithValue(FakeDeviceApi()),
        deviceIdentityProvider.overrideWith((ref) async => testIdentity),
        eventsApiProvider.overrideWithValue(api),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<PagedEvents> events() => container.read(securityEventsProvider.future);
  SecurityEvents notifier() => container.read(securityEventsProvider.notifier);
  Future<void> pair() =>
      container.read(bindingProvider.notifier).pair(pairingLinkFixture);

  test('empty while unpaired, no call', () async {
    expect((await events()).items, isEmpty);
    expect(api.calls, isEmpty);
  });

  test('first page once paired, 50 newest', () async {
    await pair();
    final page = await events();
    expect(page.items, hasLength(50));
    expect(page.items.first.id, 'ev-0');
    expect(page.hasMore, isTrue);
    expect(api.calls, [(50, null)]);
  });

  test(
    'loadMore appends without duplicates until the cursor runs out',
    () async {
      await pair();
      await events();
      await notifier().loadMore();
      expect((await events()).items, hasLength(100));
      await notifier().loadMore();
      final all = await events();
      expect(all.items, hasLength(120));
      expect(all.hasMore, isFalse);
      expect(all.items.map((e) => e.id).toSet(), hasLength(120));

      await notifier().loadMore();
      expect(api.calls, hasLength(3), reason: 'nothing to load');
    },
  );

  test('refresh reloads the first page and resets paging', () async {
    await pair();
    await events();
    await notifier().loadMore();
    api.events = [eventAt(999, now: now)];
    await notifier().refresh();
    final page = await events();
    expect(page.items.single.id, 'ev-999');
    expect(page.hasMore, isFalse);
  });

  test('a failed refresh keeps the list and records the error', () async {
    await pair();
    await events();
    api.failure = ApiError.unreachable('http://10.0.2.2:8002');
    await notifier().refresh();
    expect((await events()).items, hasLength(50));
    expect(container.read(lastFetchErrorProvider)?.isUnreachable, isTrue);
  });

  test('a loadMore that lands after a refresh is dropped', () async {
    await pair();
    await events();
    final older = notifier().loadMore(); // page 2 in flight
    api.events = [eventAt(999, now: now)];
    await notifier().refresh();
    await older;
    final page = await events();
    expect(page.items.map((e) => e.id), ['ev-999']);
    expect(page.hasMore, isFalse);
    expect(page.loadingMore, isFalse);
  });

  test('a failed loadMore keeps the list and clears the spinner', () async {
    await pair();
    await events();
    api.failure = ApiError.unreachable('http://10.0.2.2:8002');
    await notifier().loadMore();
    final page = await events();
    expect(page.items, hasLength(50));
    expect(page.loadingMore, isFalse);
    expect(page.hasMore, isTrue);
  });
}
