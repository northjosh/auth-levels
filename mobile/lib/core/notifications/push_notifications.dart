import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../features/pairing/binding.dart';
import '../../features/requests/push_requests.dart';
import 'push_gateway.dart';

/// Wires FCM into the app: foreground messages become local notifications
/// and refresh the request list, notification taps open the request, and
/// Firebase Installation ID changes reach the backend while paired.
class PushNotifications {
  PushNotifications(this._ref);

  final Ref _ref;
  final _subscriptions = <StreamSubscription<Object?>>[];

  PushGateway get _gateway => _ref.read(pushGatewayProvider);
  NotificationPresenter get _presenter =>
      _ref.read(notificationPresenterProvider);

  Future<void> start() async {
    await _presenter.init(onTap: _openRequest);

    _subscriptions.add(_gateway.foreground.listen(_onForeground));
    _subscriptions.add(
      _gateway.opened.listen((message) => _openRequest(message.requestId)),
    );
    _subscriptions.add(
      _gateway.tokenRefresh.listen(
        (token) => _ref.read(bindingProvider.notifier).syncFcmToken(token),
      ),
    );

    final initial = await _gateway.initialMessage();
    if (initial != null) _openRequest(initial.requestId);

    // Re-affirm the current FID on every app start, bypassing the local
    // dedupe cache: it's the recovery point for a backend-side clear (an
    // `UNREGISTERED` FCM send) that this device had no way to learn about
    // while it happened.
    final token = await _gateway.token();
    if (token != null) {
      await _ref.read(bindingProvider.notifier).syncFcmToken(token, force: true);
    }
  }

  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> _onForeground(PushMessage message) async {
    await _presenter.show(message);
    // The request is already on the backend; pull it into the list.
    unawaited(_ref.read(pushRequestsProvider.notifier).refresh());
  }

  void _openRequest(String requestId) {
    _ref.read(routerProvider).push(Routes.request(requestId));
  }

  /// Ask for permission and return the Firebase Installation ID, or null when
  /// push is unavailable on this device. Used when pairing.
  Future<String?> permissionAndToken() async {
    final granted = await _gateway.requestPermission();
    if (!granted) return null;
    return _gateway.token();
  }

  /// The request was opened or found gone: its notification is stale.
  Future<void> cancelFor(String requestId) => _presenter.cancel(requestId);

  /// Unpaired or revoked: nothing pending is actionable any more.
  Future<void> cancelAll() => _presenter.cancelAll();
}

final pushNotificationsProvider = Provider<PushNotifications>((ref) {
  final service = PushNotifications(ref);
  ref.onDispose(service.dispose);
  return service;
});
