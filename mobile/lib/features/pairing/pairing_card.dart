import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/section_label.dart';
import '../../core/api/models.dart';
import '../../core/scanner/scan_screen.dart';
import 'binding.dart';
import 'pairing_link.dart';

/// The unpaired Account tab: scan the web's pairing QR or paste the link.
class PairingCard extends ConsumerStatefulWidget {
  const PairingCard({super.key});

  @override
  ConsumerState<PairingCard> createState() => _PairingCardState();
}

class _PairingCardState extends ConsumerState<PairingCard> {
  final _link = TextEditingController();
  final _linkFocus = FocusNode();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _link.dispose();
    _linkFocus.dispose();
    super.dispose();
  }

  Future<void> _pair(PairingLink link) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(bindingProvider.notifier).pair(link);
    } on AlreadyPairedException catch (e) {
      _fail(e.message);
    } on ApiError catch (e) {
      _fail(
        e.isEnrollmentExpired
            ? 'This pairing code expired — generate a new one on the web.'
            : e.message,
      );
    } on Exception catch (e) {
      // A reply that is not the contract, or storage refusing the write.
      _fail("Couldn't pair: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  void _pairFromText() {
    final PairingLink link;
    try {
      link = parsePairingLink(_link.text);
    } on PairingLinkException catch (e) {
      _fail(e.message);
      return;
    }
    _pair(link);
  }

  Future<void> _scan() async {
    final outcome = await Navigator.of(context).push<ScanOutcome<PairingLink>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ScanScreen<PairingLink>(
          title: 'Scan pairing code',
          accept: tryParsePairingLink,
          rejectMessage: 'Not a pairing code',
          manualLabel: 'Paste the link instead',
          camera: ref.read(scanCameraProvider),
        ),
      ),
    );
    if (!mounted) return;
    switch (outcome) {
      case Scanned(:final value):
        await _pair(value);
      case ScanEnterManually():
        _linkFocus.requestFocus();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Not paired'),
            const SizedBox(height: 6),
            Text(
              'Pair this phone to approve logins',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Open Settings → Trusted Devices on the web and scan the code.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan pairing code'),
            ),
            const SizedBox(height: 12),
            Text('or paste the pairing link', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            TextField(
              controller: _link,
              focusNode: _linkFocus,
              enabled: !_busy,
              autocorrect: false,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'authlevels://pair?token=…',
                errorText: _error,
                errorMaxLines: 4,
                isDense: true,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _pairFromText(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: _pairFromText,
                      child: const Text('Pair'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
