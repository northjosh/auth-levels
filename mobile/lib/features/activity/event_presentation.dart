import 'package:flutter/material.dart';

import '../../core/api/models.dart';

/// How a Security Event row reads: title from the spec §6.4 templates,
/// an icon by type family, and whether it should be tinted as bad news.
class EventPresentation {
  const EventPresentation({
    required this.title,
    required this.icon,
    this.negative = false,
    this.rawType = false,
  });

  final String title;
  final IconData icon;

  /// `LOGIN_FAILURE` and `PUSH_REQUEST_DENIED`.
  final bool negative;

  /// The type is unknown; [title] is the raw enum, show it monospace.
  final bool rawType;
}

EventPresentation presentEvent(SecurityEvent event) {
  final device = event.details['deviceName'] ?? 'a Trusted Device';
  switch (event.type) {
    case 'LOGIN_SUCCESS':
      return EventPresentation(
        title: switch (event.method) {
          'PUSH' => 'Login approved on $device',
          'RECOVERY_CODE' => 'Signed in with a recovery code',
          final m? => 'Signed in with ${_methodName(m)}',
          null => 'Signed in',
        },
        icon: Icons.login,
      );
    case 'LOGIN_FAILURE':
      return EventPresentation(
        title: switch (event.method) {
          'PUSH' => 'Wrong approval code',
          final m? => 'Failed ${_methodName(m)} sign-in',
          null => 'Failed sign-in',
        },
        icon: Icons.error_outline,
        negative: true,
      );
    case 'SIGNUP':
      return const EventPresentation(
        title: 'Account created',
        icon: Icons.person_add_alt,
      );
    case 'EMAIL_VERIFIED':
      return const EventPresentation(
        title: 'Email verified',
        icon: Icons.mark_email_read_outlined,
      );
    case 'TOTP_ENABLED':
      return const EventPresentation(title: 'TOTP set up', icon: Icons.pin);
    case 'TOTP_ACTIVATED':
      return const EventPresentation(title: 'TOTP activated', icon: Icons.pin);
    case 'TOTP_DISABLED':
      return const EventPresentation(title: 'TOTP disabled', icon: Icons.pin);
    case 'RECOVERY_CODES_GENERATED':
      return const EventPresentation(
        title: 'Recovery codes generated',
        icon: Icons.key_outlined,
      );
    case 'PASSKEY_ADDED':
      return const EventPresentation(
        title: 'Passkey added',
        icon: Icons.fingerprint,
      );
    case 'PASSKEY_REMOVED':
      return const EventPresentation(
        title: 'Passkey removed',
        icon: Icons.fingerprint,
      );
    case 'PASSWORD_RESET_REQUESTED':
      return const EventPresentation(
        title: 'Password reset requested',
        icon: Icons.lock_reset,
      );
    case 'PASSWORD_RESET_COMPLETED':
      return const EventPresentation(
        title: 'Password reset completed',
        icon: Icons.lock_reset,
      );
    case 'PUSH_REQUEST_CREATED':
      return const EventPresentation(
        title: 'Login request sent',
        icon: Icons.notifications_outlined,
      );
    case 'PUSH_REQUEST_DENIED':
      return EventPresentation(
        title: 'Login denied on $device',
        icon: Icons.block,
        negative: true,
      );
    case 'TRUSTED_DEVICE_PAIRED':
      return EventPresentation(
        title: '$device paired',
        icon: Icons.phonelink_ring_outlined,
      );
    case 'TRUSTED_DEVICE_REMOVED':
      return EventPresentation(
        title: '$device unpaired',
        icon: Icons.phonelink_off,
      );
    default:
      return EventPresentation(
        title: event.type,
        icon: Icons.help_outline,
        rawType: true,
      );
  }
}

/// Subtitle: who did it, when known; else the device named in details.
String? eventSubtitle(SecurityEvent event) {
  final actor = event.actor;
  if (actor != null) {
    return [
      actor.browserOnOs,
      if (actor.remoteAddress.isNotEmpty) actor.remoteAddress,
    ].join(' · ');
  }
  return event.details['deviceName'];
}

String _methodName(String method) => switch (method) {
  'PASSWORD' => 'password',
  'TOTP' => 'TOTP',
  'RECOVERY_CODE' => 'recovery code',
  'PASSKEY' => 'passkey',
  'MAGIC_LINK' => 'magic link',
  _ => method.toLowerCase().replaceAll('_', ' '),
};
