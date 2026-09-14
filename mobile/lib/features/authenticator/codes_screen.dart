import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/confirm_dialog.dart';
import '../settings/clock_skew.dart';
import 'add_account_flow.dart';
import 'authenticator_accounts.dart';
import 'code_format.dart';
import 'ticker.dart';

/// Authenticator tab: every Authenticator Account with its live code.
class CodesScreen extends ConsumerWidget {
  const CodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(authenticatorAccountsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Codes'),
        actions: [
          IconButton(
            tooltip: 'Add account',
            icon: const Icon(Icons.add),
            onPressed: () => startAddAccount(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          const ClockSkewBanner(),
          Expanded(
            child: switch (accounts) {
              AsyncData(:final value) when value.isEmpty => const _EmptyCodes(),
              AsyncData(:final value) => ListView.separated(
                itemCount: value.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _AccountRow(value[i]),
              ),
              AsyncError() => const Center(
                child: Text("Couldn't load accounts."),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow(this.stored);

  final StoredAccount stored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = stored.account;
    final snapshot = ref.watch(
      tickerProvider.select(
        (tick) => account.snapshotAt(tick.value ?? DateTime.now()),
      ),
    );
    final theme = Theme.of(context);
    final grouped = groupCode(snapshot.code);
    final low = snapshot.secondsLeft <= 5;

    return InkWell(
      onTap: () => _copy(context, snapshot.code, grouped),
      onLongPress: () => _showRowActions(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.issuer,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(account.account, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              grouped,
              // Read digit by digit rather than as one large number.
              semanticsLabel: snapshot.code.split('').join(' '),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
                color: low ? theme.colorScheme.error : null,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: snapshot.secondsLeft / account.period,
                strokeWidth: 3,
                color: low ? theme.colorScheme.error : null,
                semanticsLabel: '${snapshot.secondsLeft} seconds left',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String code, String grouped) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Copied $grouped')));
  }

  Future<void> _showRowActions(BuildContext context, WidgetRef ref) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Remove'),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (remove != true || !context.mounted) return;

    final account = stored.account;
    final confirmed = await confirmDialog(
      context,
      title: 'Remove ${account.issuer} (${account.account})?',
      body:
          'This phone will stop generating codes for it. '
          'Make sure you can still sign in another way.',
      action: 'Remove',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(authenticatorAccountsProvider.notifier).remove(stored.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't remove the account: $e")),
      );
    }
  }
}

class _EmptyCodes extends StatelessWidget {
  const _EmptyCodes();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pin_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text('No accounts yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Paste an otpauth:// link or enter the details with the + button.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
