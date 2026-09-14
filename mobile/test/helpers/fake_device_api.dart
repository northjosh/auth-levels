import 'package:auth_levels/core/api/api_client.dart';
import 'package:auth_levels/core/api/models.dart';
import 'package:auth_levels/features/pairing/device_api.dart';
import 'package:auth_levels/features/pairing/device_identity.dart';
import 'package:auth_levels/features/pairing/pairing_link.dart';

/// The stub server's Android-emulator pairing link.
final pairingLinkFixture = parsePairingLink(
  'authlevels://pair?token=ok-1&api=http://10.0.2.2:8002&email=joshua%40terydin.co',
);

/// What tests report as this install's identity.
const testIdentity = DeviceIdentity(
  name: 'Android emulator',
  platform: 'android',
  appVersion: '0.1.0',
);

/// Records calls and answers like the stub server would, without HTTP.
class FakeDeviceApi implements DeviceApi {
  static const deviceId = '11111111-2222-4333-8444-555555555555';
  static const deviceToken = 'fake-device-token';

  final pairCalls = <(String, PairRequest)>[];
  var unpairCalls = 0;
  final fcmTokens = <String>[];

  ApiError? pairError;
  ApiError? unpairError;

  @override
  Future<PairResponse> pair(String apiBaseUrl, PairRequest request) async {
    pairCalls.add((apiBaseUrl, request));
    if (pairError case final error?) throw error;
    return const PairResponse(
      deviceId: deviceId,
      deviceToken: deviceToken,
      user: UserSummary(email: 'joshua@terydin.co', firstName: 'Joshua'),
    );
  }

  @override
  Future<void> unpair(ApiClient client) async {
    unpairCalls++;
    if (unpairError case final error?) throw error;
  }

  @override
  Future<void> updateFcmToken(ApiClient client, String token) async {
    fcmTokens.add(token);
  }
}
