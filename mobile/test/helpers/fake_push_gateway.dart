import 'dart:async';

import 'package:auth_levels/core/notifications/push_gateway.dart';

/// Scriptable FCM: tests push messages and tokens through the controllers.
class FakePushGateway implements PushGateway {
  FakePushGateway({this.granted = true, this.currentToken = 'fcm-token-1'});

  bool granted;
  String? currentToken;
  PushMessage? initial;
  var permissionRequests = 0;

  final tokenRefreshController = StreamController<String>.broadcast();
  final foregroundController = StreamController<PushMessage>.broadcast();
  final openedController = StreamController<PushMessage>.broadcast();

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<String?> token() async => granted ? currentToken : null;

  @override
  Stream<String> get tokenRefresh => tokenRefreshController.stream;

  @override
  Stream<PushMessage> get foreground => foregroundController.stream;

  @override
  Stream<PushMessage> get opened => openedController.stream;

  @override
  Future<PushMessage?> initialMessage() async => initial;

  Future<void> close() async {
    await tokenRefreshController.close();
    await foregroundController.close();
    await openedController.close();
  }
}

class FakePresenter implements NotificationPresenter {
  final shown = <PushMessage>[];
  final cancelled = <String>[];
  void Function(String requestId)? onTap;

  @override
  Future<void> init({required void Function(String requestId) onTap}) async {
    this.onTap = onTap;
  }

  @override
  Future<void> show(PushMessage message) async => shown.add(message);

  @override
  Future<void> cancel(String requestId) async => cancelled.add(requestId);

  var cancelledAll = 0;

  @override
  Future<void> cancelAll() async => cancelledAll++;
}

PushMessage pushMessage(String requestId) => PushMessage(
  requestId: requestId,
  title: 'Login request',
  body: 'Chrome on Mac OS X · 127.0.0.1',
);
