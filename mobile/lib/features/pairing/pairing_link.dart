/// What the web shows as a QR / copyable text:
/// `authlevels://pair?token=…&api=…&email=…` (contract §2.2).
class PairingLink {
  const PairingLink({required this.token, required this.api, this.email});

  /// The Enrollment Token.
  final String token;

  /// Backend base URL, no trailing slash.
  final String api;

  /// The account being paired to, for display only.
  final String? email;
}

class PairingLinkException implements Exception {
  const PairingLinkException(this.message);

  /// User-readable reason.
  final String message;

  @override
  String toString() => 'PairingLinkException: $message';
}

/// Parses a pairing link or throws [PairingLinkException].
PairingLink parsePairingLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'authlevels' || uri.host != 'pair') {
    throw const PairingLinkException('This is not a pairing link.');
  }
  final params = uri.queryParameters;

  final token = params['token']?.trim() ?? '';
  if (token.isEmpty) {
    throw const PairingLinkException('The pairing link has no token.');
  }

  final api = Uri.tryParse(params['api']?.trim() ?? '');
  if (api == null ||
      !(api.scheme == 'http' || api.scheme == 'https') ||
      !api.hasAuthority ||
      api.host.isEmpty) {
    throw const PairingLinkException(
      'The pairing link has no valid API address.',
    );
  }

  final email = params['email']?.trim();
  return PairingLink(
    token: token,
    api: api.toString().replaceFirst(RegExp(r'/+$'), ''),
    email: (email == null || email.isEmpty) ? null : email,
  );
}

/// [parsePairingLink] as yes / no, for the scanner.
PairingLink? tryParsePairingLink(String raw) {
  try {
    return parsePairingLink(raw);
  } on PairingLinkException {
    return null;
  }
}
