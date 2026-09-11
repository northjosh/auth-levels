import 'package:auth_levels/features/authenticator/authenticator_account.dart';
import 'package:auth_levels/features/authenticator/otpauth_parser.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime at(int unixSeconds) =>
    DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true);

// RFC 6238 Appendix B: the ASCII secrets "1234567890..." of 20 / 32 / 64 bytes.
const sha1Secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
const sha256Secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA';
const sha512Secret =
    'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'
    'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA';

AuthenticatorAccount rfcAccount(TotpAlgorithm algorithm, String secret) =>
    AuthenticatorAccount(
      issuer: 'RFC',
      account: 'appendix-b',
      secret: secret,
      algorithm: algorithm,
      digits: 8,
    );

void main() {
  group('RFC 6238 test vectors', () {
    const vectors = <int, List<String>>{
      // time : [SHA1, SHA256, SHA512]
      59: ['94287082', '46119246', '90693936'],
      1111111109: ['07081804', '68084774', '25091201'],
      1111111111: ['14050471', '67062674', '99943326'],
      1234567890: ['89005924', '91819424', '93441116'],
      2000000000: ['69279037', '90698825', '38618901'],
      20000000000: ['65353130', '77737706', '47863826'],
    };

    for (final entry in vectors.entries) {
      test('T=${entry.key}', () {
        expect(
          rfcAccount(TotpAlgorithm.sha1, sha1Secret).codeAt(at(entry.key)),
          entry.value[0],
        );
        expect(
          rfcAccount(TotpAlgorithm.sha256, sha256Secret).codeAt(at(entry.key)),
          entry.value[1],
        );
        expect(
          rfcAccount(TotpAlgorithm.sha512, sha512Secret).codeAt(at(entry.key)),
          entry.value[2],
        );
      });
    }

    test('6 digits truncates the same HMAC', () {
      final account = AuthenticatorAccount(
        issuer: 'RFC',
        account: 'x',
        secret: sha1Secret,
      );
      expect(account.codeAt(at(59)), '287082');
      expect(account.digits, 6);
    });

    test('period changes the counter', () {
      final account = AuthenticatorAccount(
        issuer: 'RFC',
        account: 'x',
        secret: sha1Secret,
        digits: 8,
        period: 60,
      );
      // step 1 for 60 s at T=118 equals step 1 for 30 s at T=59
      expect(account.codeAt(at(118)), '94287082');
    });

    test('local-time DateTime gives the same code as UTC', () {
      final account = AuthenticatorAccount(
        issuer: 'RFC',
        account: 'x',
        secret: sha1Secret,
      );
      expect(
        account.codeAt(at(1234567890).toLocal()),
        account.codeAt(at(1234567890)),
      );
    });
  });

  group('secondsLeft', () {
    final account = AuthenticatorAccount(
      issuer: 'RFC',
      account: 'x',
      secret: sha1Secret,
    );

    test('counts down from period to 1 within a step', () {
      expect(account.secondsLeft(at(0)), 30);
      expect(account.secondsLeft(at(1)), 29);
      expect(account.secondsLeft(at(29)), 1);
      expect(account.secondsLeft(at(30)), 30);
    });

    test('ignores sub-second time', () {
      final t = DateTime.fromMillisecondsSinceEpoch(29999, isUtc: true);
      expect(account.secondsLeft(t), 1);
    });

    test('respects a custom period', () {
      final a = AuthenticatorAccount(
        issuer: 'RFC',
        account: 'x',
        secret: sha1Secret,
        period: 60,
      );
      expect(a.secondsLeft(at(45)), 15);
    });
  });

  group('backend fixture', () {
    // Recorded 2026-09-11 against the Spring backend (GoogleAuthenticator,
    // SHA1 / 6 digits / 30 s): POST /enable-totp for test@example.com
    // returned this secret; the code below, derived by this library at the
    // given Unix time, was accepted by POST /activate-totp (HTTP 200).
    const secret = 'SYSOCPZNPUZ3X6HL';
    const qrUrl =
        'otpauth://totp/JoshAuth:test%40example.com?secret=$secret&issuer=JoshAuth';
    const unixTime = 1789158361;
    const acceptedCode = '665571';

    test('derives the code the backend accepted', () {
      final account = parseOtpAuthUri(qrUrl);
      expect(account.issuer, 'JoshAuth');
      expect(account.account, 'test@example.com');
      expect(account.secret, secret);
      expect(account.codeAt(at(unixTime)), acceptedCode);
    });

    test('the backend accepts ±1 step, so the neighbours differ', () {
      final account = parseOtpAuthUri(qrUrl);
      expect(account.codeAt(at(unixTime - 30)), isNot(acceptedCode));
      expect(account.codeAt(at(unixTime + 30)), isNot(acceptedCode));
    });
  });

  test('TotpAlgorithm labels round-trip', () {
    for (final a in TotpAlgorithm.values) {
      expect(TotpAlgorithm.tryParse(a.label), a);
      expect(TotpAlgorithm.tryParse(a.label.toLowerCase()), a);
    }
    expect(TotpAlgorithm.tryParse('MD5'), isNull);
  });
}
