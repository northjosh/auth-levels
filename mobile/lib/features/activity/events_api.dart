import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models.dart';

/// `GET /security-events` (contract §4.3), newest first, cursor paged.
abstract interface class EventsApi {
  Future<SecurityEventsPage> list(
    ApiClient client, {
    int limit = 50,
    String? before,
  });
}

class HttpEventsApi implements EventsApi {
  const HttpEventsApi();

  @override
  Future<SecurityEventsPage> list(
    ApiClient client, {
    int limit = 50,
    String? before,
  }) async {
    final data = await client.get<Map<String, Object?>>(
      '/security-events',
      query: {'limit': limit, 'before': ?before},
    );
    return SecurityEventsPage.fromJson(data);
  }
}

final eventsApiProvider = Provider<EventsApi>((_) => const HttpEventsApi());
