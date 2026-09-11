import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key-value store for secrets. Thin seam over `flutter_secure_storage` so
/// providers can be tested against [InMemorySecureStore].
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Platform keychain / KeyStore-backed store used by the app.
class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore();

  // Spec §5: KeyStore-wrapped AES (the v11 default) and wipe on a decrypt
  // error rather than crash. Stated explicitly so an upgrade can't flip it.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Plain map; for tests and previews only.
class InMemorySecureStore implements SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

final secureStoreProvider = Provider<SecureStore>(
  (ref) => const FlutterSecureStore(),
);
