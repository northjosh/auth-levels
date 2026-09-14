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

  /// True when [other] names the same issuer and account, whatever its
  /// secret or parameters. Adding such an account replaces this one.
  bool sameIdentityAs(AuthenticatorAccount other) =>
      other.issuer == issuer && other.account == account;

  /// What a list row shows for [time]. A record, so equal snapshots compare
  /// equal and a row only rebuilds when the code or countdown changes.
  TotpSnapshot snapshotAt(DateTime time) =>
      (code: codeAt(time), secondsLeft: secondsLeft(time));

  /// Storage shape from spec §5 (minus `id` / `createdAt`, which the
  /// repository adds).
  Map<String, Object?> toJson() => {
    'issuer': issuer,
    'account': account,
    'secret': secret,
    'algorithm': algorithm.label,
    'digits': digits,
    'period': period,
  };

  /// Inverse of [toJson]. Throws [FormatException] on anything unreadable.
  factory AuthenticatorAccount.fromJson(Map<String, Object?> json) {
    final algorithmLabel =
        json['algorithm'] as String? ?? TotpAlgorithm.sha1.label;
    final algorithm = TotpAlgorithm.tryParse(algorithmLabel);
    if (algorithm == null) {
      throw FormatException('Unknown algorithm', algorithmLabel);
    }
    return AuthenticatorAccount(
      issuer: json['issuer'] as String,
      account: json['account'] as String,
      secret: json['secret'] as String,
      algorithm: algorithm,
      digits: json['digits'] as int? ?? 6,
      period: json['period'] as int? ?? 30,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthenticatorAccount &&
      other.issuer == issuer &&
      other.account == account &&
      other.secret == secret &&
      other.algorithm == algorithm &&
      other.digits == digits &&
      other.period == period;

  @override
  int get hashCode =>
      Object.hash(issuer, account, secret, algorithm, digits, period);
}

typedef TotpSnapshot = ({String code, int secondsLeft});
