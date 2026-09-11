import 'package:auth_levels/core/scanner/scan_screen.dart';
import 'package:flutter/material.dart';

/// A camera stand-in for widget tests: one button per entry in [payloads]
/// (label → raw QR text) feeds the scanner, and the fallback for [failure]
/// is rendered alongside so its buttons can be exercised too.
ScanCameraBuilder fakeCamera({
  required Map<String, String> payloads,
  ScanFailure? failure = ScanFailure.permissionDenied,
}) {
  return (context, host) => Column(
    children: [
      for (final entry in payloads.entries)
        TextButton(
          onPressed: () => host.onRaw(entry.value),
          child: Text(entry.key),
        ),
      if (failure != null) host.fallback(failure),
    ],
  );
}
