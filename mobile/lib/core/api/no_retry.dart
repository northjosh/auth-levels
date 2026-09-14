/// Riverpod 3 retries a failed provider build with exponential backoff by
/// default. Spec §7: nothing retries beyond the user pulling to refresh,
/// so every provider that touches the network or storage opts out.
Duration? noRetry(int retryCount, Object error) => null;
