import 'package:auth_levels/features/activity/event_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_events_api.dart';

void main() {
  final now = DateTime.now();

  test('every LOGIN_SUCCESS method has a template', () {
    const expected = {
      'PASSWORD': 'Signed in with password',
      'TOTP': 'Signed in with TOTP',
      'RECOVERY_CODE': 'Signed in with a recovery code',
      'PASSKEY': 'Signed in with passkey',
      'MAGIC_LINK': 'Signed in with magic link',
    };
    for (final entry in expected.entries) {
      final view = presentEvent(eventAt(0, now: now, method: entry.key));
      expect(view.title, entry.value, reason: entry.key);
      expect(view.negative, isFalse);
      expect(view.rawType, isFalse);
    }
    expect(
      presentEvent(
        eventAt(
          0,
          now: now,
          method: 'PUSH',
          details: {'deviceName': 'Pixel 7'},
        ),
      ).title,
      'Login approved on Pixel 7',
    );
  });

  test('LOGIN_FAILURE names the method and is negative', () {
    final e = presentEvent(
      eventAt(0, now: now, type: 'LOGIN_FAILURE', method: 'RECOVERY_CODE'),
    );
    expect(e.title, 'Failed recovery code sign-in');
    expect(e.negative, isTrue);
    expect(
      presentEvent(eventAt(0, now: now, type: 'LOGIN_FAILURE', method: 'PUSH'))
          .title,
      'Wrong approval code',
    );
    expect(
      presentEvent(eventAt(0, now: now, type: 'LOGIN_FAILURE', method: null))
          .title,
      'Failed sign-in',
    );
  });

  test('the non-login types', () {
    const expected = {
      'SIGNUP': 'Account created',
      'EMAIL_VERIFIED': 'Email verified',
      'TOTP_ENABLED': 'TOTP set up',
      'TOTP_ACTIVATED': 'TOTP activated',
      'TOTP_DISABLED': 'TOTP disabled',
      'RECOVERY_CODES_GENERATED': 'Recovery codes generated',
      'PASSKEY_ADDED': 'Passkey added',
      'PASSKEY_REMOVED': 'Passkey removed',
      'PASSWORD_RESET_REQUESTED': 'Password reset requested',
      'PASSWORD_RESET_COMPLETED': 'Password reset completed',
      'PUSH_REQUEST_CREATED': 'Login request sent',
      'PUSH_REQUEST_DENIED': 'Login denied on Pixel 7',
      'TRUSTED_DEVICE_PAIRED': 'Pixel 7 paired',
      'TRUSTED_DEVICE_REMOVED': 'Pixel 7 unpaired',
    };
    for (final entry in expected.entries) {
      final view = presentEvent(
        eventAt(
          0,
          now: now,
          type: entry.key,
          method: null,
          details: {'deviceName': 'Pixel 7'},
        ),
      );
      expect(view.title, entry.value, reason: entry.key);
      expect(view.negative, entry.key == 'PUSH_REQUEST_DENIED');
      expect(view.rawType, isFalse);
    }
  });

  test('a missing deviceName still reads', () {
    expect(
      presentEvent(
        eventAt(0, now: now, type: 'TRUSTED_DEVICE_PAIRED', method: null),
      ).title,
      'a Trusted Device paired',
    );
  });

  test('an unknown type renders the raw enum, flagged monospace', () {
    final view = presentEvent(
      eventAt(0, now: now, type: 'SOMETHING_NEW', method: null),
    );
    expect(view.title, 'SOMETHING_NEW');
    expect(view.rawType, isTrue);
    expect(view.negative, isFalse);
  });

  test('subtitle prefers the actor, then the device name, else nothing', () {
    expect(
      eventSubtitle(eventAt(0, now: now)),
      'Chrome on Mac OS X · 127.0.0.1',
    );
    expect(
      eventSubtitle(
        eventAt(0, now: now, actor: null, details: {'deviceName': 'Pixel 7'}),
      ),
      'Pixel 7',
    );
    expect(eventSubtitle(eventAt(0, now: now, actor: null)), isNull);
  });
}
