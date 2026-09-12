/// A failed API call: the HTTP status plus the backend's machine-readable
/// `error` code (contract §1.1), or [unreachableCode] when no response
/// arrived at all.
class ApiError implements Exception {
  const ApiError({
    required this.status,
    required this.error,
    required this.message,
    this.attemptsLeft,
  });

  /// No connection, timeout, or a closed port. [message] names the URL and
  /// the usual emulator address mix-up.
  factory ApiError.unreachable(String url) => ApiError(
    status: 0,
    error: unreachableCode,
    message:
        "Can't reach $url — is the backend running and is this the right "
        'address for this emulator? (Android emulator: 10.0.2.2, '
        'iOS simulator: localhost)',
  );

  // Client-side codes.
  static const unreachableCode = 'unreachable';
  static const cancelledCode = 'cancelled';

  // Backend codes (contract §1.1).
  static const revokedCode = 'device_revoked';
  static const enrollmentExpiredCode = 'enrollment_expired';
  static const otpMismatchCode = 'otp_mismatch';
  static const requestGoneCode = 'request_gone';

  final int status;
  final String error;
  final String message;

  /// Present on `otp_mismatch` responses.
  final int? attemptsLeft;

  bool get isUnreachable => error == unreachableCode;
  bool get isRevoked => error == revokedCode;
  bool get isEnrollmentExpired => error == enrollmentExpiredCode;

  @override
  String toString() => 'ApiError($status $error): $message';
}

class UserSummary {
  const UserSummary({required this.email, required this.firstName});

  final String email;
  final String firstName;

  factory UserSummary.fromJson(Map<String, Object?> json) => UserSummary(
    email: json['email'] as String,
    firstName: json['firstName'] as String? ?? '',
  );

  Map<String, Object?> toJson() => {'email': email, 'firstName': firstName};
}

/// This install's Trusted Device pairing (spec §5 `device:binding`). Also
/// keeps the name and platform sent at pairing time, so the Settings sheet
/// shows what the backend recorded without re-deriving it.
class TrustedDeviceBinding {
  const TrustedDeviceBinding({
    required this.deviceId,
    required this.deviceToken,
    required this.apiBaseUrl,
    required this.user,
    required this.pairedAt,
    required this.deviceName,
    required this.platform,
  });

  final String deviceId;
  final String deviceToken;
  final String apiBaseUrl;
  final UserSummary user;
  final DateTime pairedAt;
  final String deviceName;
  final String platform;

  factory TrustedDeviceBinding.fromJson(Map<String, Object?> json) =>
      TrustedDeviceBinding(
        deviceId: json['deviceId'] as String,
        deviceToken: json['deviceToken'] as String,
        apiBaseUrl: json['apiBaseUrl'] as String,
        user: UserSummary.fromJson(json['user'] as Map<String, Object?>),
        pairedAt: DateTime.parse(json['pairedAt'] as String),
        deviceName: json['deviceName'] as String? ?? 'This phone',
        platform: json['platform'] as String? ?? 'unknown',
      );

  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'deviceToken': deviceToken,
    'apiBaseUrl': apiBaseUrl,
    'user': user.toJson(),
    'pairedAt': pairedAt.toUtc().toIso8601String(),
    'deviceName': deviceName,
    'platform': platform,
  };
}
