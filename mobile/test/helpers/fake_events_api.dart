import 'package:auth_levels/core/api/api_client.dart';
import 'package:auth_levels/core/api/models.dart';
import 'package:auth_levels/features/activity/events_api.dart';

import 'fake_push_api.dart';

SecurityEvent eventAt(
  int index, {
  required DateTime now,
  String type = 'LOGIN_SUCCESS',
  String? method = 'PASSWORD',
  ClientInfo? actor = chrome,
  Map<String, String> details = const {},
}) => SecurityEvent(
  id: 'ev-$index',
  type: type,
  method: method,
  occurredAt: now.subtract(Duration(minutes: index)),
  actor: actor,
  details: details,
);

/// Serves [events] newest-first in pages; the cursor is the index of the
/// last item served.
class FakeEventsApi implements EventsApi {
  FakeEventsApi(this.events);

  List<SecurityEvent> events;
  final calls = <(int, String?)>[];
  ApiError? failure;

  @override
  Future<SecurityEventsPage> list(
    ApiClient client, {
    int limit = 50,
    String? before,
  }) async {
    calls.add((limit, before));
    if (failure case final f?) throw f;
    final start = before == null ? 0 : int.parse(before) + 1;
    final page = events.skip(start).take(limit).toList();
    final last = start + page.length - 1;
    return SecurityEventsPage(
      items: page,
      nextCursor: last + 1 < events.length ? '$last' : null,
    );
  }
}
