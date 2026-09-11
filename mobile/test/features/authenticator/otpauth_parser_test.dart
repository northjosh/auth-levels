import 'package:auth_levels/features/authenticator/authenticator_account.dart';
import 'package:auth_levels/features/authenticator/otpauth_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher rejects(OtpAuthError error) =>
    throwsA(isA<OtpAuthException>().having((e) => e.error, 'error', error));

void main() {
  group('parseOtpAuthUri accepts', () {
    test('a fully specified TOTP URI from the Key URI wiki', () {
      final account = parseOtpAuthUri(
        'otpauth://totp/ACME%20Co:john.doe@email.com'
        '?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME%20Co'
        '&algorithm=SHA1&digits=6&period=30',
      );
      expect(account.issuer, 'ACME Co');
      expect(account.account, 'john.doe@email.com');
      expect(account.secret, 'HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ');
      expect(account.algorithm, TotpAlgorithm.sha1);
      expect(account.digits, 6);
      expect(account.period, 30);
    });

    test('defaults to SHA1, 6 digits, 30 seconds', () {
      final account = parseOtpAuthUri(
        'otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example',
      );
      expect(account.algorithm, TotpAlgorithm.sha1);
      expect(account.digits, 6);
      expect(account.period, 30);
    });

    test('SHA256 / SHA512, 8 digits, custom period, case-insensitive', () {
      final a = parseOtpAuthUri(
        'otpauth://totp/x?secret=JBSWY3DPEHPK3PXP&algorithm=sha256&digits=8&period=60',
      );
      expect(a.algorithm, TotpAlgorithm.sha256);
      expect(a.digits, 8);
      expect(a.period, 60);
      final b = parseOtpAuthUri(
        'OTPAUTH://TOTP/x?secret=JBSWY3DPEHPK3PXP&algorithm=SHA512',
      );
      expect(b.algorithm, TotpAlgorithm.sha512);
    });

    test('normalises the secret: lowercase, spaces, padding', () {
      final account = parseOtpAuthUri(
        'otpauth://totp/x?secret=jbsw%20y3dp%20ehpk%203pxp%3D%3D',
      );
      expect(account.secret, 'JBSWY3DPEHPK3PXP');
    });

    test("the backend's enable-totp link (URLEncoder-encoded label)", () {
      final account = parseOtpAuthUri(
        'otpauth://totp/JoshAuth:test%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=JoshAuth',
      );
      expect(account.issuer, 'JoshAuth');
      expect(account.account, 'test@example.com');
    });
  });

  group('issuer resolution', () {
    test('issuer param wins over the label prefix', () {
      final account = parseOtpAuthUri(
        'otpauth://totp/Prefix:bob?secret=JBSWY3DPEHPK3PXP&issuer=Param',
      );
      expect(account.issuer, 'Param');
      expect(account.account, 'bob');
    });

    test('falls back to the label prefix before the first colon', () {
      final account = parseOtpAuthUri(
        'otpauth://totp/Prefix:%20bob?secret=JBSWY3DPEHPK3PXP',
      );
      expect(account.issuer, 'Prefix');
      expect(account.account, 'bob');
    });

    test('accepts a percent-encoded colon as the separator', () {
      final account = parseOtpAuthUri(
        'otpauth://totp/Prefix%3Abob?secret=JBSWY3DPEHPK3PXP',
      );
      expect(account.issuer, 'Prefix');
      expect(account.account, 'bob');
    });

    test('falls back to "Unknown" when neither is present', () {
      final account = parseOtpAuthUri(
        'otpauth://totp/bob?secret=JBSWY3DPEHPK3PXP',
      );
      expect(account.issuer, 'Unknown');
      expect(account.account, 'bob');
    });

    test('empty issuer param counts as absent', () {
      final account = parseOtpAuthUri(
        'otpauth://totp/bob?secret=JBSWY3DPEHPK3PXP&issuer=',
      );
      expect(account.issuer, 'Unknown');
    });

    test('a label with a slash stays one account name', () {
      final account = parseOtpAuthUri(
        'otpauth://totp/Corp:team/bob?secret=JBSWY3DPEHPK3PXP',
      );
      expect(account.issuer, 'Corp');
      expect(account.account, 'team/bob');
    });
  });

  group('parseOtpAuthUri rejects', () {
    test('a non-otpauth scheme', () {
      expect(
        () => parseOtpAuthUri('https://example.com/?secret=JBSWY3DPEHPK3PXP'),
        rejects(OtpAuthError.notOtpAuth),
      );
    });

    test('a label with a broken percent-escape', () {
      expect(
        () =>
            parseOtpAuthUri('otpauth://totp/%E0%A4%A?secret=JBSWY3DPEHPK3PXP'),
        rejects(OtpAuthError.notOtpAuth),
      );
      expect(
        tryParseOtpAuthUri('otpauth://totp/%E0%A4%A?secret=JBSWY3DPEHPK3PXP'),
        isNull,
      );
    });

    test('text that is not a URI at all', () {
      expect(
        () => parseOtpAuthUri('hello world'),
        rejects(OtpAuthError.notOtpAuth),
      );
      expect(() => parseOtpAuthUri(''), rejects(OtpAuthError.notOtpAuth));
      expect(
        () => parseOtpAuthUri('otpauth:::'),
        rejects(OtpAuthError.notOtpAuth),
      );
    });

    test('HOTP', () {
      expect(
        () => parseOtpAuthUri(
          'otpauth://hotp/x?secret=JBSWY3DPEHPK3PXP&counter=1',
        ),
        rejects(OtpAuthError.notTotp),
      );
    });

    test('a label without an account name', () {
      expect(
        () => parseOtpAuthUri('otpauth://totp/?secret=JBSWY3DPEHPK3PXP'),
        rejects(OtpAuthError.missingAccount),
      );
      expect(
        () => parseOtpAuthUri('otpauth://totp/Corp:?secret=JBSWY3DPEHPK3PXP'),
        rejects(OtpAuthError.missingAccount),
      );
      expect(
        () => parseOtpAuthUri('otpauth://totp?secret=JBSWY3DPEHPK3PXP'),
        rejects(OtpAuthError.missingAccount),
      );
    });

    test('a missing or empty secret', () {
      expect(
        () => parseOtpAuthUri('otpauth://totp/x'),
        rejects(OtpAuthError.missingSecret),
      );
      expect(
        () => parseOtpAuthUri('otpauth://totp/x?secret='),
        rejects(OtpAuthError.missingSecret),
      );
      expect(
        () => parseOtpAuthUri('otpauth://totp/x?secret=%3D%3D'),
        rejects(OtpAuthError.missingSecret),
      );
    });

    test('a secret that is not Base32', () {
      expect(
        () => parseOtpAuthUri('otpauth://totp/x?secret=NOT-BASE32!'),
        rejects(OtpAuthError.invalidSecret),
      );
      expect(
        () => parseOtpAuthUri('otpauth://totp/x?secret=ABC189'),
        rejects(OtpAuthError.invalidSecret),
      );
      expect(
        () => parseOtpAuthUri('otpauth://totp/x?secret=A'),
        rejects(OtpAuthError.invalidSecret),
      );
      // 17 chars: a length no unpadded Base32 string can have
      expect(
        () => parseOtpAuthUri('otpauth://totp/x?secret=JBSWY3DPEHPK3PXPA'),
        rejects(OtpAuthError.invalidSecret),
      );
    });

    test('but accepts every legal unpadded Base32 length', () {
      for (final secret in [
        'JBSWY3DP',
        'JBSWY3DPEH',
        'JBSWY3DPEHPK',
        'JBSWY3DPEHPK3',
        'JBSWY3DPEHPK3PX',
        'JBSWY3DPEHPK3PXP',
      ]) {
        expect(
          parseOtpAuthUri('otpauth://totp/x?secret=$secret').secret,
          secret,
        );
      }
    });

    test('digits outside {6, 8}', () {
      for (final d in ['7', '5', '9', '0', 'six']) {
        expect(
          () => parseOtpAuthUri(
            'otpauth://totp/x?secret=JBSWY3DPEHPK3PXP&digits=$d',
          ),
          rejects(OtpAuthError.badDigits),
          reason: 'digits=$d',
        );
      }
    });

    test('an unknown algorithm', () {
      expect(
        () => parseOtpAuthUri(
          'otpauth://totp/x?secret=JBSWY3DPEHPK3PXP&algorithm=MD5',
        ),
        rejects(OtpAuthError.unknownAlgorithm),
      );
      expect(
        () => parseOtpAuthUri(
          'otpauth://totp/x?secret=JBSWY3DPEHPK3PXP&algorithm=SHA384',
        ),
        rejects(OtpAuthError.unknownAlgorithm),
      );
    });

    test('a non-positive or non-numeric period', () {
      for (final p in ['0', '-30', 'abc', '1.5']) {
        expect(
          () => parseOtpAuthUri(
            'otpauth://totp/x?secret=JBSWY3DPEHPK3PXP&period=$p',
          ),
          rejects(OtpAuthError.badPeriod),
          reason: 'period=$p',
        );
      }
    });

    test('with a distinct user-readable message per reason', () {
      final messages = <String>{};
      for (final uri in [
        'https://x',
        'otpauth://hotp/x?secret=JBSWY3DPEHPK3PXP',
        'otpauth://totp/?secret=JBSWY3DPEHPK3PXP',
        'otpauth://totp/x',
        'otpauth://totp/x?secret=!',
        'otpauth://totp/x?secret=JBSWY3DPEHPK3PXP&digits=7',
        'otpauth://totp/x?secret=JBSWY3DPEHPK3PXP&algorithm=MD5',
        'otpauth://totp/x?secret=JBSWY3DPEHPK3PXP&period=0',
      ]) {
        try {
          parseOtpAuthUri(uri);
          fail('expected $uri to be rejected');
        } on OtpAuthException catch (e) {
          expect(e.message, isNotEmpty);
          expect(
            messages.add(e.message),
            isTrue,
            reason: 'duplicate message for $uri',
          );
        }
      }
      expect(messages, hasLength(OtpAuthError.values.length));
    });
  });
}
