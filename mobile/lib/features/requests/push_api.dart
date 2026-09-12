import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models.dart';

/// The Push Request endpoints (contract §3.2). Every call needs the paired
/// [ApiClient]; errors surface as [ApiError] with `otp_mismatch`
/// (+ `attemptsLeft`) or `request_gone`.
abstract interface class PushApi {
  Future<List<PushRequest>> list(ApiClient client);
  Future<void> verify(ApiClient client, String requestId, String otp);
  Future<void> deny(ApiClient client, String requestId);
}

class HttpPushApi implements PushApi {
  const HttpPushApi();

  @override
  Future<List<PushRequest>> list(ApiClient client) async {
    final data = await client.get<List<Object?>>('/push/get');
    return [
      for (final item in data)
        PushRequest.fromJson(item as Map<String, Object?>),
    ];
  }

  @override
  Future<void> verify(ApiClient client, String requestId, String otp) =>
      client.post<Object?>(
        '/push/verify',
        body: {'requestId': requestId, 'otp': otp},
      );

  @override
  Future<void> deny(ApiClient client, String requestId) =>
      client.post<Object?>('/push/deny', body: {'requestId': requestId});
}

final pushApiProvider = Provider<PushApi>((_) => const HttpPushApi());
