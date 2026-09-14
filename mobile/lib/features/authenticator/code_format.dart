/// Groups a code for display: `123456` → `123 456`, `12345678` → `1234 5678`.
String groupCode(String code) {
  final half = code.length ~/ 2;
  return '${code.substring(0, half)} ${code.substring(half)}';
}
