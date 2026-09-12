import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/confirm_dialog.dart';
import '../../app/section_label.dart';
import '../../core/api/models.dart';
import '../pairing/binding.dart';
import '../pairing/device_identity.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const SettingsSheet(),
  );
}

/// Trusted Device card, unpair, API base URL, app version.
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  Future<void> _unpair(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Unpair this phone?',
      body:
          'Login approvals stop working here until you pair again. '
          'Your authenticator codes are not affected.',
      action: 'Unpair',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(bindingProvider.notifier).unpair();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      final reason = e is ApiError ? e.message : '$e';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Couldn't unpair: $reason")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final binding = ref.watch(bindingProvider).value;
    final identity = ref.watch(deviceIdentityProvider).value;
    final localizations = MaterialLocalizations.of(context);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text('Settings', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (binding != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Trusted Device'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            binding.deviceName,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        // Ticket 08 turns this on once an FCM token is
                        // registered.
                        const Chip(
                          label: Text('Push off'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    Text(binding.platform, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Text(binding.user.email),
                    Text(
                      'Paired ${localizations.formatMediumDate(binding.pairedAt.toLocal())}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.link_off, color: theme.colorScheme.error),
              title: Text(
                'Unpair this phone',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () => _unpair(context, ref),
            ),
          ] else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phonelink_off),
              title: const Text('Not paired'),
              subtitle: const Text('Pair from the Account tab.'),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('API base URL'),
            subtitle: Text(binding?.apiBaseUrl ?? 'Set by the pairing link'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('App version'),
            subtitle: Text(
              '${identity?.appVersion ?? '…'} · '
              '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
            ),
          ),
        ],
      ),
    );
  }
}
