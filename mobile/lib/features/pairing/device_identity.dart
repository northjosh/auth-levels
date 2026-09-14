import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// What the backend records about this install when it pairs.
class DeviceIdentity {
  const DeviceIdentity({
    required this.name,
    required this.platform,
    required this.appVersion,
  });

  /// Human name: the device model, or "Android emulator" / "iOS simulator".
  final String name;

  /// `android` or `ios` (contract §2.1).
  final String platform;

  final String appVersion;
}

final deviceIdentityProvider = FutureProvider<DeviceIdentity>((ref) async {
  final package = await PackageInfo.fromPlatform();
  final plugin = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final info = await plugin.androidInfo;
    return DeviceIdentity(
      name: info.isPhysicalDevice
          ? '${info.manufacturer} ${info.model}'
          : 'Android emulator',
      platform: 'android',
      appVersion: package.version,
    );
  }
  if (Platform.isIOS) {
    final info = await plugin.iosInfo;
    return DeviceIdentity(
      name: info.isPhysicalDevice ? info.name : 'iOS simulator',
      platform: 'ios',
      appVersion: package.version,
    );
  }
  return DeviceIdentity(
    name: Platform.localHostname,
    platform: Platform.operatingSystem,
    appVersion: package.version,
  );
});
