import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scan_screen.dart';

/// The production camera: `mobile_scanner` limited to QR codes. Every
/// decoded payload goes to the host; a camera that cannot start is mapped
/// onto the host's fallback.
Widget mobileScannerCamera(BuildContext context, ScanCameraHost host) =>
    _MobileScannerCamera(host: host);

class _MobileScannerCamera extends StatefulWidget {
  const _MobileScannerCamera({required this.host});

  final ScanCameraHost host;

  @override
  State<_MobileScannerCamera> createState() => _MobileScannerCameraState();
}

/// Owns the controller, so it also owns the lifecycle: `MobileScanner` only
/// pauses and resumes the camera by itself when it creates the controller.
/// Stopping on `inactive` releases the camera while backgrounded; starting
/// on `resumed` also retries after the user grants permission in Settings.
class _MobileScannerCameraState extends State<_MobileScannerCamera>
    with WidgetsBindingObserver {
  // noDuplicates: a code held in frame is reported once, not every 250 ms.
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _start();
      case AppLifecycleState.inactive:
        if (_controller.value.isRunning) unawaited(_controller.stop());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Starts the camera unless it is already running or starting. A start
  /// that fails (denied permission, no camera) lands in the controller's
  /// error state and is rendered by [errorBuilder], not thrown.
  void _start() {
    final value = _controller.value;
    if (value.isRunning || value.isStarting) return;
    unawaited(
      _controller.start().catchError(
        (Object _) {},
        test: (e) => e is MobileScannerException,
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null) widget.host.onRaw(raw);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: _onDetect,
      errorBuilder: (context, error) =>
          widget.host.fallback(switch (error.errorCode) {
            MobileScannerErrorCode.permissionDenied =>
              ScanFailure.permissionDenied,
            MobileScannerErrorCode.unsupported => ScanFailure.noCamera,
            _ => ScanFailure.other,
          }, onRetry: _start),
    );
  }
}
