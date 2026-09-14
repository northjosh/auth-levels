import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the backend's FCM message (contract §3.3) carries once decoded.
class PushMessage {
  const PushMessage({
    required this.requestId,
    required this.title,
    required this.body,
  });

  final String requestId;
  final String title;
  final String body;

  static const type = 'push_request';

  /// Null when the message is not a Push Request.
  static PushMessage? fromRemote(RemoteMessage message) {
    final data = {
      for (final e in message.data.entries) e.key: e.value.toString(),
    };
    if (data['type'] != type) return null;
    final requestId = data['requestId'];
    if (requestId == null || requestId.isEmpty) return null;
    final client = [
      data['userAgentFamily'],
      data['osFamily'],
    ].whereType<String>().join(' on ');
    return PushMessage(
      requestId: requestId,
      title: message.notification?.title ?? 'Login request',
      body:
          message.notification?.body ??
          [client, data['remoteAddress']].whereType<String>().join(' · '),
    );
  }
}

/// Everything the app needs from Firebase Cloud Messaging. Tests use a fake.
abstract interface class PushGateway {
  /// Asks for notification permission (Android 13+); true when granted.
  Future<bool> requestPermission();

  /// The current FCM token, or null when unavailable (iOS simulator, no
  /// Play services, permission denied).
  Future<String?> token();

  Stream<String> get tokenRefresh;

  /// Push Requests arriving while the app is in the foreground.
  Stream<PushMessage> get foreground;

  /// A tap on a tray notification while the app was in the background.
  Stream<PushMessage> get opened;

  /// The tap that launched the app from a terminated state, if any.
  Future<PushMessage?> initialMessage();
}

/// The real thing. [requestPermission] and [token] are reachable from
/// pairing on a build without Firebase, so they report the safe value on a
/// `FirebaseException` instead of failing the pairing; the streams are only
/// subscribed once Firebase is known to be up.
class FirebasePushGateway implements PushGateway {
  const FirebasePushGateway();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  @override
  Future<bool> requestPermission() async {
    try {
      final settings = await _fcm.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } on FirebaseException catch (e) {
      _log('requestPermission unavailable: ${e.code}');
      return false;
    }
  }

  @override
  Future<String?> token() async {
    try {
      final token = await _fcm.getToken();
      // Dev builds only: tool/send_push needs the token and adb logcat is
      // the easiest way off the emulator (Settings shows it too). print,
      // not developer.log: only print reaches logcat.
      if (kDebugMode) debugPrint('fcm token: $token');
      return token;
    } on FirebaseException catch (e) {
      _log('getToken unavailable: ${e.code}');
      return null;
    }
  }

  @override
  Stream<String> get tokenRefresh => _fcm.onTokenRefresh;

  @override
  Stream<PushMessage> get foreground =>
      FirebaseMessaging.onMessage.map(PushMessage.fromRemote).nonNulls;

  @override
  Stream<PushMessage> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map(PushMessage.fromRemote).nonNulls;

  @override
  Future<PushMessage?> initialMessage() async {
    final message = await _fcm.getInitialMessage();
    return message == null ? null : PushMessage.fromRemote(message);
  }

  void _log(String message) => developer.log(message, name: 'push');
}

extension<T extends Object> on Stream<T?> {
  Stream<T> get nonNulls => where((e) => e != null).cast<T>();
}

/// Shows and cancels the local notification for a Push Request.
abstract interface class NotificationPresenter {
  Future<void> init({required void Function(String requestId) onTap});
  Future<void> show(PushMessage message);
  Future<void> cancel(String requestId);

  /// Every Push Request notification: the device was unpaired or revoked.
  Future<void> cancelAll();
}

/// Android channel for Push Requests (spec §3): high importance so the
/// notification heads up.
const pushChannel = AndroidNotificationChannel(
  'push_requests',
  'Login requests',
  description: 'Someone is signing in and needs your approval.',
  importance: Importance.high,
);

/// Android keys notifications by (tag, id). FCM's own tray notification for
/// a background message uses `tag = requestId` and id 0 (contract §3.3), so
/// the app's foreground notification uses the same key: a re-send replaces
/// it, and one cancel clears either kind.
const pushNotificationId = 0;

/// Backed by `flutter_local_notifications`. Inert until [init] succeeds
/// (the plugin's platform side only exists once the app's registrant has
/// run), and platform failures after that are logged, never thrown: a
/// missing notification must not break pairing or approving.
class LocalNotificationPresenter implements NotificationPresenter {
  LocalNotificationPresenter();

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  @override
  Future<void> init({required void Function(String requestId) onTap}) =>
      _platform('init', () async {
        _ready = true;
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            // Permission is asked for while pairing (spec §4.4), not at
            // launch.
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
          onDidReceiveNotificationResponse: (response) {
            final payload = response.payload;
            if (payload != null && payload.isNotEmpty) onTap(payload);
          },
        );
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(pushChannel);
      });

  @override
  Future<void> show(PushMessage message) => _platform(
    'show',
    () => _plugin.show(
      id: pushNotificationId,
      title: message.title,
      body: message.body,
      payload: message.requestId,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          pushChannel.id,
          pushChannel.name,
          channelDescription: pushChannel.description,
          importance: pushChannel.importance,
          priority: Priority.high,
          tag: message.requestId,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    ),
  );

  @override
  Future<void> cancel(String requestId) => _platform(
    'cancel',
    () => _plugin.cancel(id: pushNotificationId, tag: requestId),
  );

  @override
  Future<void> cancelAll() => _platform('cancelAll', _plugin.cancelAll);

  Future<void> _platform(String what, Future<void> Function() call) async {
    if (what != 'init' && !_ready) return;
    try {
      await call();
    } on MissingPluginException catch (e) {
      _ready = false;
      developer.log('$what: $e', name: 'push');
    } on PlatformException catch (e) {
      developer.log('$what failed: ${e.code}', name: 'push');
    }
  }
}

final pushGatewayProvider = Provider<PushGateway>(
  (_) => const FirebasePushGateway(),
);

final notificationPresenterProvider = Provider<NotificationPresenter>(
  (_) => LocalNotificationPresenter(),
);
