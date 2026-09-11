import 'package:dart_dash_otp/dart_dash_otp.dart';

/// HMAC hash used to derive a code. Labels match the `algorithm` values of
/// the otpauth Key URI format.
enum TotpAlgorithm {
  sha1('SHA1', OTPAlgorithm.SHA1),
  sha256('SHA256', OTPAlgorithm.SHA256),
  sha512('SHA512', OTPAlgorithm.SHA512);

  const TotpAlgorithm(this.label, this._otpAlgorithm);

  final String label;
  final OTPAlgorithm _otpAlgorithm;

  /// Case-insensitive lookup by [label]; null for anything unsupported.
  static TotpAlgorithm? tryParse(String label) {
    final upper = label.toUpperCase();
    for (final a in values) {
      if (a.label == upper) return a;
    }
    return null;
  }
}

/// One TOTP secret held by the app, plus the parameters needed to turn it
/// into a code. Independent of any Trusted Device pairing.
///
/// [secret] is normalised Base32 (uppercase, no padding). Construction does
/// not validate it; use `parseOtpAuthUri` for untrusted input.
class AuthenticatorAccount {
  const AuthenticatorAccount({
    required this.issuer,
    required this.account,
    required this.secret,
    this.algorithm = TotpAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
  });

  final String issuer;
  final String account;
  final String secret;
  final TotpAlgorithm algorithm;
  final int digits;

  /// Time-step length in seconds.
  final int period;

  TOTP get _totp => TOTP(
    secret: secret,
    digits: digits,
    interval: period,
    algorithm: algorithm._otpAlgorithm,
  );

  /// The code valid at [time]. TOTP counts Unix seconds, so the zone of
  /// [time] is irrelevant.
  // `value` only returns null when `date` is null, which it never is here.
  String codeAt(DateTime time) => _totp.value(date: time)!;

  /// The code valid right now.
  String currentCode() => codeAt(DateTime.now());

  /// Seconds until the code shown at [time] rolls over, in `1..period`.
  int secondsLeft([DateTime? time]) => _totp.remainingSeconds(at: time);
}
