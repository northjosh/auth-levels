import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/section_label.dart';
import '../../core/api/models.dart';
import '../pairing/binding.dart';
import '../pairing/pairing_card.dart';
import '../settings/settings_sheet.dart';

/// Account tab: pairing card while unpaired; otherwise the Trusted Device
/// summary, pending Push Requests (ticket 07) and the activity timeline
/// (ticket 09).
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binding = ref.watch(bindingProvider);
    final revoked = ref.watch(revokedNoticeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showSettingsSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (revoked)
            MaterialBanner(
              content: const Text('This phone was unpaired from the web'),
              leading: const Icon(Icons.link_off),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(revokedNoticeProvider.notifier).dismiss(),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: switch (binding) {
              AsyncData(value: final b?) => _PairedBody(b),
              AsyncData() => const _UnpairedBody(),
              AsyncError() => const Center(
                child: Text("Couldn't read the pairing state."),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

class _UnpairedBody extends StatelessWidget {
  const _UnpairedBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        PairingCard(),
        SizedBox(height: 24),
        _ActivityPlaceholder(paired: false),
      ],
    );
  }
}

class _PairedBody extends StatelessWidget {
  const _PairedBody(this.binding);

  final TrustedDeviceBinding binding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionLabel('Trusted Device'),
        const SizedBox(height: 6),
        Text(
          'Paired as ${binding.user.email}',
          style: theme.textTheme.titleMedium,
        ),
        Text(binding.deviceName, style: theme.textTheme.bodySmall),
        const SizedBox(height: 24),
        const _ActivityPlaceholder(paired: true),
      ],
    );
  }
}

class _ActivityPlaceholder extends StatelessWidget {
  const _ActivityPlaceholder({required this.paired});

  final bool paired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Activity'),
        const SizedBox(height: 12),
        Text(
          paired
              ? 'No activity yet.'
              : 'Sign-ins and security changes show here once paired.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
