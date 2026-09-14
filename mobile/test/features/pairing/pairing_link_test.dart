import 'package:auth_levels/features/pairing/pairing_link.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher rejectsWith(String fragment) => throwsA(
  isA<PairingLinkException>().having(
    (e) => e.message,
    'message',
    contains(fragment),
  ),
);

void main() {
  test('parses token, api and email', () {
    final link = parsePairingLink(
      'authlevels://pair?token=ok-1&api=http%3A%2F%2F10.0.2.2%3A8002&email=joshua%40terydin.co',
    );
    expect(link.token, 'ok-1');
    expect(link.api, 'http://10.0.2.2:8002');
    expect(link.email, 'joshua@terydin.co');
  });

  test('email is optional and a trailing slash on api is dropped', () {
    final link = parsePairingLink(
      'authlevels://pair?token=abc&api=https://auth.example.com/',
    );
    expect(link.email, isNull);
    expect(link.api, 'https://auth.example.com');
  });

  test('tryParsePairingLink is the null-returning form', () {
    expect(
      tryParsePairingLink('authlevels://pair?token=a&api=http://x'),
      isNotNull,
    );
    expect(
      tryParsePairingLink('otpauth://totp/x?secret=JBSWY3DPEHPK3PXP'),
      isNull,
    );
  });

  group('rejects', () {
    test('other schemes and hosts', () {
      expect(
        () => parsePairingLink('https://x/pair?token=a&api=http://x'),
        rejectsWith('pairing link'),
      );
      expect(
        () => parsePairingLink('authlevels://login?token=a&api=http://x'),
        rejectsWith('pairing link'),
      );
      expect(() => parsePairingLink('not a link'), rejectsWith('pairing link'));
    });

    test('a missing token', () {
      expect(
        () => parsePairingLink('authlevels://pair?api=http://x'),
        rejectsWith('token'),
      );
      expect(
        () => parsePairingLink('authlevels://pair?token=&api=http://x'),
        rejectsWith('token'),
      );
    });

    test('a missing or non-http api', () {
      expect(
        () => parsePairingLink('authlevels://pair?token=a'),
        rejectsWith('address'),
      );
      expect(
        () => parsePairingLink('authlevels://pair?token=a&api=ftp://x'),
        rejectsWith('address'),
      );
      expect(
        () => parsePairingLink('authlevels://pair?token=a&api=10.0.2.2:8001'),
        rejectsWith('address'),
      );
    });
  });
}
