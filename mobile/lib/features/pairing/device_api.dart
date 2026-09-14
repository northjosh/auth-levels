import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models.dart';

/// Body of `POST /devices/pair` (contract §2.2).
class PairRequest {
  const PairRequest({
    required this.enrollmentToken,
    required this.fcmToken,
    required this.name,
    required this.platform,
    required this.appVersion,
  });

  final String enrollmentToken;
  final String? fcmToken;
  final String name;
  final String platform;
  final String appVersion;

  Map<String, Object?> toJson() => {
    'enrollmentToken': enrollmentToken,
    'fcmToken': fcmToken,
    'name': name,
    'platform': platform,
    'appVersion': appVersion,
  };
}

class PairResponse {
  const PairResponse({
    required this.deviceId,
    required this.deviceToken,
    required this.user,
  });

  final String deviceId;
  final String deviceToken;
  final UserSummary user;

  factory PairResponse.fromJson(Map<String, Object?> json) => PairResponse(
    deviceId: json['deviceId'] as String,
    deviceToken: json['deviceToken'] as String,
    user: UserSummary.fromJson(json['user'] as Map<String, Object?>),
  );
}

/// The Trusted Device endpoints. Pairing is the one unauthenticated call,
/// made against the URL from the pairing link; the rest use the paired
/// [ApiClient].
abstract interface class DeviceApi {
  Future<PairResponse> pair(String apiBaseUrl, PairRequest request);
  Future<void> unpair(ApiClient client);
  Future<void> updateFcmToken(ApiClient client, String token);
}

class HttpDeviceApi implements DeviceApi {
  const HttpDeviceApi();

  @override
  Future<PairResponse> pair(String apiBaseUrl, PairRequest request) async {
    final data = await ApiClient(baseUrl: apiBaseUrl)
        .post<Object?>('/devices/pair', body: request.toJson());
    return PairResponse.fromJson(data as Map<String, Object?>);
  }

  @override
  Future<void> unpair(ApiClient client) => client.delete<void>('/devices/me');

  @override
  Future<void> updateFcmToken(ApiClient client, String token) =>
      client.put<void>('/devices/me/fcm-token', body: {'fcmToken': token});
}

final deviceApiProvider = Provider<DeviceApi>((_) => const HttpDeviceApi());
