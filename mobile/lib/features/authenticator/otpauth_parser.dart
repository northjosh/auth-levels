import 'package:dart_dash_otp/dart_dash_otp.dart';

import 'authenticator_account.dart';

/// Why an `otpauth://` URI was rejected. One entry per user-facing reason.
enum OtpAuthError {
  notOtpAuth,
  notTotp,
  missingAccount,
  missingSecret,
  invalidSecret,
  badDigits,
  unknownAlgorithm,
  badPeriod,
}

/// Thrown by [parseOtpAuthUri]; [error] identifies the reason, [message]
/// explains it to the user.
class OtpAuthException implements Exception {
  const OtpAuthException(this.error, this.message);

  final OtpAuthError error;

  /// Short, user-readable explanation. Safe to show in the UI as is.
  final String message;

  @override
  String toString() => 'OtpAuthException(${error.name}): $message';
}

/// Issuer shown when neither the `issuer` parameter nor a label prefix is
/// present.
const unknownIssuer = 'Unknown';

const _defaultDigits = 6;
const _defaultPeriod = 30;
const _allowedDigits = {6, 8};

/// Parses a Google Authenticator Key URI (`otpauth://totp/LABEL?PARAMS`)
/// into an [AuthenticatorAccount], or throws [OtpAuthException].
///
/// Only TOTP is supported. `secret` is required and normalised (uppercase,
/// whitespace and `=` padding stripped). The label must name an account;
/// `issuer` comes from the parameter, else from the label's prefix before
/// the first `:`, else [unknownIssuer]. `algorithm`, `digits` and `period`
/// default to SHA1 / 6 / 30.
///
/// Query parameters are form-decoded, so `+` reads as a space. That matches
/// the backend, whose `URLEncoder` writes spaces in the issuer as `+`.
AuthenticatorAccount parseOtpAuthUri(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'otpauth' || uri.host.isEmpty) {
    throw const OtpAuthException(
      OtpAuthError.notOtpAuth,
      'This is not an otpauth:// link.',
    );
  }
  if (uri.host != 'totp') {
    throw const OtpAuthException(
      OtpAuthError.notTotp,
      'Only time-based (TOTP) codes are supported.',
    );
  }

  final params = uri.queryParameters;
  final label = _Label.parse(uri.path);
  if (label.account.isEmpty) {
    throw const OtpAuthException(
      OtpAuthError.missingAccount,
      'The link does not name an account.',
    );
  }
  final issuerParam = params['issuer']?.trim();

  return AuthenticatorAccount(
    issuer: (issuerParam?.isNotEmpty ?? false)
        ? issuerParam!
        : label.issuer ?? unknownIssuer,
    account: label.account,
    secret: normaliseSecret(params['secret']),
    algorithm: _algorithm(params['algorithm']),
    digits: _digits(params['digits']),
    period: parsePeriod(params['period']),
  );
}

/// The percent-decoded label, split on its first colon into an optional
/// issuer prefix and the account name.
class _Label {
  const _Label(this.issuer, this.account);

  final String? issuer;
  final String account;

  static _Label parse(String path) {
    final encoded = path.startsWith('/') ? path.substring(1) : path;
    final decoded = Uri.decodeComponent(encoded);
    final colon = decoded.indexOf(':');
    if (colon < 0) return _Label(null, decoded.trim());
    final prefix = decoded.substring(0, colon).trim();
    return _Label(
      prefix.isEmpty ? null : prefix,
      decoded.substring(colon + 1).trim(),
    );
  }
}

/// Normalises a Base32 secret as typed or scanned (uppercase, whitespace and
/// `=` padding stripped) and validates it, throwing [OtpAuthException] with
/// `missingSecret` or `invalidSecret`. Shared by the URI parser and the
/// manual entry form.
String normaliseSecret(String? raw) {
  final normalised = (raw ?? '').replaceAll(RegExp(r'[\s=]'), '').toUpperCase();
  if (normalised.isEmpty) {
    throw const OtpAuthException(
      OtpAuthError.missingSecret,
      'No secret was given.',
    );
  }
  // Unpadded Base32 can never be 1, 3 or 6 characters past a multiple of 8;
  // the decoder would silently drop the dangling bits.
  const impossibleTails = {1, 3, 6};
  if (impossibleTails.contains(normalised.length % 8)) {
    throw const OtpAuthException(
      OtpAuthError.invalidSecret,
      'The secret is not valid Base32.',
    );
  }
  try {
    // Reuses the library's alphabet and minimum-length checks, so the parser
    // can never accept a secret the code generator would throw on. Only the
    // secret is passed; the other constructor defaults are always valid.
    TOTP(secret: normalised);
  } on ArgumentError {
    throw const OtpAuthException(
      OtpAuthError.invalidSecret,
      'The secret is not valid Base32.',
    );
  }
  return normalised;
}

TotpAlgorithm _algorithm(String? raw) {
  if (raw == null) return TotpAlgorithm.sha1;
  final algorithm = TotpAlgorithm.tryParse(raw);
  if (algorithm == null) {
    throw OtpAuthException(
      OtpAuthError.unknownAlgorithm,
      'Unsupported algorithm "$raw". Use SHA1, SHA256 or SHA512.',
    );
  }
  return algorithm;
}

int _digits(String? raw) {
  if (raw == null) return _defaultDigits;
  final digits = int.tryParse(raw);
  if (digits == null || !_allowedDigits.contains(digits)) {
    throw const OtpAuthException(
      OtpAuthError.badDigits,
      'Codes must have 6 or 8 digits.',
    );
  }
  return digits;
}

/// The time-step length in seconds; null or blank means the default (30).
/// Throws [OtpAuthException] with `badPeriod` unless a positive integer.
/// Shared by the URI parser and the manual entry form.
int parsePeriod(String? raw) {
  if (raw == null || raw.trim().isEmpty) return _defaultPeriod;
  final period = int.tryParse(raw.trim());
  if (period == null || period <= 0) {
    throw const OtpAuthException(
      OtpAuthError.badPeriod,
      'The period must be a positive number of seconds.',
    );
  }
  return period;
}
