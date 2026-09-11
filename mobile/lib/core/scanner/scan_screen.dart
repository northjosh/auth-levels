import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mobile_scanner_camera.dart';

/// Turns a raw QR payload into a value, or null when it is not the kind of
/// code this screen is looking for.
typedef ScanAccept<T> = T? Function(String raw);

/// Builds the live camera view. The default is the `mobile_scanner`
/// adapter; tests inject a stand-in that feeds [ScanCameraHost.onRaw].
typedef ScanCameraBuilder = Widget Function(
  BuildContext context,
  ScanCameraHost host,
);

final scanCameraProvider = Provider<ScanCameraBuilder>(
  (_) => mobileScannerCamera,
);

/// Why the camera could not be shown.
enum ScanFailure { permissionDenied, noCamera, other }

/// How a [ScanScreen] ended: a payload was accepted, or the user asked to
/// type the details instead. A dismissed screen pops with null.
sealed class ScanOutcome<T> {
  const ScanOutcome();
}

final class Scanned<T> extends ScanOutcome<T> {
  const Scanned(this.value);
  final T value;
}

final class ScanEnterManually<T> extends ScanOutcome<T> {
  const ScanEnterManually();
}

/// What a camera adapter can do: hand over payloads, or ask for the
/// fallback UI when the camera is unavailable. [onRetry], when given, lets
/// the fallback try to start the camera again.
class ScanCameraHost {
  const ScanCameraHost({required this.onRaw, required this.fallback});

  final void Function(String raw) onRaw;
  final Widget Function(ScanFailure failure, {VoidCallback? onRetry}) fallback;
}

/// Full-screen scanner. Pops with [Scanned] holding the first payload that
/// [accept] turns into a value; anything else flashes [rejectMessage] and
/// scanning continues. When the camera is unavailable the fallback offers
/// system settings (for a denied permission) and, if [manualLabel] is set,
/// a way out that pops with [ScanEnterManually].
class ScanScreen<T> extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.title,
    required this.accept,
    required this.rejectMessage,
    required this.camera,
    this.manualLabel,
  });

  final String title;
  final ScanAccept<T> accept;
  final String rejectMessage;
  final ScanCameraBuilder camera;
  final String? manualLabel;

  static const noticeDuration = Duration(seconds: 2);

  @override
  State<ScanScreen<T>> createState() => _ScanScreenState<T>();
}

class _ScanScreenState<T> extends State<ScanScreen<T>> {
  var _done = false;
  String? _notice;
  Timer? _noticeTimer;

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  void _onRaw(String raw) {
    if (_done) return;
    final value = widget.accept(raw);
    if (value != null) {
      _done = true;
      Navigator.pop(context, Scanned<T>(value));
      return;
    }
    _noticeTimer?.cancel();
    setState(() => _notice = widget.rejectMessage);
    _noticeTimer = Timer(ScanScreen.noticeDuration, () {
      if (mounted) setState(() => _notice = null);
    });
  }

  void _enterManually() {
    if (_done) return;
    _done = true;
    Navigator.pop(context, ScanEnterManually<T>());
  }

  Widget _fallback(ScanFailure failure, {VoidCallback? onRetry}) =>
      _ScanFallback(
        failure: failure,
        manualLabel: widget.manualLabel,
        onEnterManually: _enterManually,
        onRetry: onRetry,
      );

  @override
  Widget build(BuildContext context) {
    final host = ScanCameraHost(onRaw: _onRaw, fallback: _fallback);
    final notice = _notice;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.camera(context, host),
          if (notice != null)
            Positioned(left: 16, right: 16, bottom: 32, child: _Notice(notice)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.inverseSurface,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onInverseSurface),
        ),
      ),
    );
  }
}

/// Shown in place of the camera when it cannot start.
class _ScanFallback extends StatelessWidget {
  const _ScanFallback({
    required this.failure,
    this.manualLabel,
    this.onEnterManually,
    this.onRetry,
  });

  final ScanFailure failure;
  final String? manualLabel;
  final VoidCallback? onEnterManually;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manualLabel = this.manualLabel;
    final onRetry = this.onRetry;
    final (icon, message) = switch (failure) {
      ScanFailure.permissionDenied => (
        Icons.no_photography_outlined,
        'Camera access is turned off for this app. Allow it in Settings to '
            'scan, or enter the details by hand.',
      ),
      ScanFailure.noCamera => (
        Icons.videocam_off_outlined,
        'This device has no camera. Enter the details by hand instead.',
      ),
      ScanFailure.other => (
        Icons.error_outline,
        "The camera couldn't start. Try again, or enter the details by hand.",
      ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (failure == ScanFailure.permissionDenied)
              FilledButton(
                onPressed: () => AppSettings.openAppSettings(),
                child: const Text('Open settings'),
              )
            else if (failure == ScanFailure.other && onRetry != null)
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            if (manualLabel != null)
              TextButton(onPressed: onEnterManually, child: Text(manualLabel)),
          ],
        ),
      ),
    );
  }
}
