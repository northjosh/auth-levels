import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/api/no_retry.dart';
import 'core/notifications/push_notifications.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await _initFirebase();

  // Spec §7: no automatic retries anywhere.
  final container = ProviderContainer(retry: noRetry);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AuthLevelsApp(),
    ),
  );
  // After runApp so the router exists for notification taps. Without
  // Firebase the gateway reports "no push" and the app runs as before.
  if (firebaseReady) {
    await container.read(pushNotificationsProvider).start();
  }
}

/// Firebase is optional at runtime: a build without the config files (see
/// tool/gen_firebase_options.py) or a platform without Play services just
/// pairs with `fcmToken: null`.
Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
    return true;
  } on Exception catch (e, st) {
    developer.log(
      'Firebase unavailable, push disabled',
      name: 'push',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}

/// Runs in its own isolate when a message arrives while the app is in the
/// background or terminated. The tray notification is the OS's job for a
/// combined message, and the request list refetches when the app opens, so
/// there is nothing to do beyond initialising Firebase — with explicit
/// options, since there is no google-services plugin to supply a default
/// app in this isolate.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
