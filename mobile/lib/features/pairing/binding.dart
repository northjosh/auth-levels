import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/notifications/push_notifications.dart';
import '../../core/storage/secure_store.dart';
import 'device_api.dart';
import 'device_identity.dart';
import 'pairing_link.dart';

/// Thrown by [Binding.pair] while a binding already exists.
class AlreadyPairedException implements Exception {
  const AlreadyPairedException();

  final String message = 'Unpair this phone first.';

  @override
  String toString() => 'AlreadyPairedException: $message';
}

/// This install's Trusted Device binding, persisted under `device:binding`.
/// Null while unpaired.
class Binding extends AsyncNotifier<TrustedDeviceBinding?> {
  static const key = 'device:binding';
  static const fcmTokenKey = 'device:fcmToken';

  late SecureStore _store;

  @override
  Future<TrustedDeviceBinding?> build() async {
    _store = ref.watch(secureStoreProvider);
    final raw = await _store.read(key);
    if (raw == null) return null;
    try {
      return TrustedDeviceBinding.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } catch (e) {
      developer.log(
        'Unreadable $key; treating as unpaired (${e.runtimeType})',
        name: 'pairing',
      );
      return null;
    }
  }

  /// Pairs against the API named in [link]. Throws [AlreadyPairedException]
  /// while paired, or the [ApiError] from `POST /devices/pair`. Asks for
  /// notification permission first; the FCM token goes along when there is
  /// one (null on the iOS simulator or when denied).
  Future<TrustedDeviceBinding> pair(PairingLink link) async {
    if (await future != null) throw const AlreadyPairedException();

    final identity = await ref.read(deviceIdentityProvider.future);
    final fcmToken = await ref
        .read(pushNotificationsProvider)
        .permissionAndToken();
    final response = await ref
        .read(deviceApiProvider)
        .pair(
          link.api,
          PairRequest(
            enrollmentToken: link.token,
            fcmToken: fcmToken,
            name: identity.name,
            platform: identity.platform,
            appVersion: identity.appVersion,
          ),
        );

    final binding = TrustedDeviceBinding(
      deviceId: response.deviceId,
      deviceToken: response.deviceToken,
      apiBaseUrl: link.api,
      user: response.user,
      pairedAt: DateTime.now().toUtc(),
      deviceName: identity.name,
      platform: identity.platform,
    );
    await _store.write(key, jsonEncode(binding.toJson()));
    state = AsyncData(binding);
    await _rememberFcmToken(fcmToken);
    return binding;
  }

  /// A rotated FCM token: `PUT /devices/me/fcm-token` while paired, and
  /// remember what the backend last heard. Nothing to do while unpaired;
  /// the next pairing sends the current token.
  Future<void> syncFcmToken(String token) async {
    final current = await future;
    if (current == null) return;
    if (await _store.read(fcmTokenKey) == token) return;
    final client = clientFor(current, onRevoked: revoked);
    try {
      await ref.read(deviceApiProvider).updateFcmToken(client, token);
      await _rememberFcmToken(token);
    } on ApiError catch (e) {
      developer.log('fcm token sync failed: ${e.error}', name: 'pairing');
    }
  }

  Future<void> _rememberFcmToken(String? token) async {
    if (token == null) {
      await _store.delete(fcmTokenKey);
    } else {
      await _store.write(fcmTokenKey, token);
    }
    ref.invalidate(fcmTokenProvider);
  }

  /// `DELETE /devices/me`, then forget the binding. A device the backend
  /// has already revoked is treated as unpaired successfully, and without
  /// the "unpaired from the web" notice: the user asked for this.
  Future<void> unpair() async {
    final current = await future;
    if (current == null) return;
    try {
      await ref.read(deviceApiProvider).unpair(clientFor(current));
    } on ApiError catch (e) {
      if (!e.isRevoked) rethrow;
    }
    await _wipe();
  }

  var _revoking = false;

  /// The backend answered `device_revoked`: forget the binding and raise the
  /// one-time notice. Concurrent calls (several requests failing at once)
  /// collapse into one.
  Future<void> revoked() async {
    if (_revoking) return;
    _revoking = true;
    try {
      if (await future == null) return;
      await _wipe();
      ref.read(revokedNoticeProvider.notifier).show();
    } finally {
      _revoking = false;
    }
  }

  Future<void> _wipe() async {
    await _store.delete(key);
    await _rememberFcmToken(null);
    state = const AsyncData(null);
    await ref.read(pushNotificationsProvider).cancelAll();
  }
}

/// The FCM token the backend last accepted (spec §5 `device:fcmToken`), or
/// null: "Push off".
final fcmTokenProvider = FutureProvider<String?>(
  (ref) => ref.watch(secureStoreProvider).read(Binding.fcmTokenKey),
);

final bindingProvider = AsyncNotifierProvider<Binding, TrustedDeviceBinding?>(
  Binding.new,
);

/// A client for [binding]. [onRevoked] is left out where a revoked reply is
/// expected rather than news (unpairing).
ApiClient clientFor(
  TrustedDeviceBinding binding, {
  void Function()? onRevoked,
}) => ApiClient(
  baseUrl: binding.apiBaseUrl,
  deviceToken: binding.deviceToken,
  onRevoked: onRevoked,
);

/// The paired client, or null while unpaired. Rebuilt whenever the binding
/// changes; a `device_revoked` reply drops the binding.
final apiClientProvider = Provider<ApiClient?>((ref) {
  final binding = ref.watch(bindingProvider).value;
  if (binding == null) return null;
  return clientFor(
    binding,
    onRevoked: () => ref.read(bindingProvider.notifier).revoked(),
  );
});

/// True after a revoke until the user dismisses the banner.
class RevokedNotice extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
  void dismiss() => state = false;
}

final revokedNoticeProvider = NotifierProvider<RevokedNotice, bool>(
  RevokedNotice.new,
);
