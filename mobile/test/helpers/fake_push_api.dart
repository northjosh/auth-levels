import 'package:auth_levels/core/api/api_client.dart';
import 'package:auth_levels/core/api/models.dart';
import 'package:auth_levels/features/requests/push_api.dart';

const chrome = ClientInfo(
  userAgentFamily: 'Chrome',
  osFamily: 'Mac OS X',
  deviceFamily: 'Other',
  remoteAddress: '127.0.0.1',
);

PushRequest requestAt(
  String requestId, {
  required DateTime now,
  Duration ttl = const Duration(minutes: 2),
}) => PushRequest(
  id: 'id-$requestId',
  requestId: requestId,
  createdAt: now,
  expiresAt: now.add(ttl),
  client: chrome,
);

/// In-memory Push Request backend: a fixed list, a right code per request,
/// and the contract's three-attempt rule.
class FakePushApi implements PushApi {
  FakePushApi({List<PushRequest> requests = const []})
    : requests = [...requests];

  final List<PushRequest> requests;
  final attempts = <String, int>{};
  final verifyCalls = <(String, String)>[];
  final denyCalls = <String>[];
  var listCalls = 0;

  /// The code every request accepts.
  String otp = '482019';

  /// When set, every call throws this instead.
  ApiError? failure;

  @override
  Future<List<PushRequest>> list(ApiClient client) async {
    listCalls++;
    if (failure case final f?) throw f;
    return [...requests];
  }

  @override
  Future<void> verify(ApiClient client, String requestId, String otp) async {
    verifyCalls.add((requestId, otp));
    if (failure case final f?) throw f;
    if (!requests.any((r) => r.requestId == requestId)) {
      throw const ApiError(
        status: 404,
        error: ApiError.requestGoneCode,
        message: 'Request not found',
      );
    }
    if (otp == this.otp) {
      requests.removeWhere((r) => r.requestId == requestId);
      return;
    }
    final used = (attempts[requestId] ?? 0) + 1;
    attempts[requestId] = used;
    final left = 3 - used;
    if (left <= 0) requests.removeWhere((r) => r.requestId == requestId);
    throw ApiError(
      status: 403,
      error: ApiError.otpMismatchCode,
      message: 'Invalid code',
      attemptsLeft: left,
    );
  }

  @override
  Future<void> deny(ApiClient client, String requestId) async {
    denyCalls.add(requestId);
    if (failure case final f?) throw f;
    if (!requests.any((r) => r.requestId == requestId)) {
      throw const ApiError(
        status: 404,
        error: ApiError.requestGoneCode,
        message: 'Request not found',
      );
    }
    requests.removeWhere((r) => r.requestId == requestId);
  }
}
