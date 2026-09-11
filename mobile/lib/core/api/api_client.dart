import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base URL of the auth-levels backend, or null while unpaired.
/// Placeholder: the pairing ticket overrides this with the stored binding's URL.
final apiBaseUrlProvider = Provider<String?>((ref) => null);

/// Shared HTTP client. Rebuilt whenever the base URL changes.
final apiClientProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  return Dio(
    BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
});
