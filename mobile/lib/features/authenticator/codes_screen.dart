import 'package:flutter/material.dart';

import 'add_account_sheet.dart';

/// Authenticator tab. Lists Authenticator Accounts; empty until ticket 04.
class CodesScreen extends StatelessWidget {
  const CodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Codes'),
        actions: [
          IconButton(
            tooltip: 'Add account',
            icon: const Icon(Icons.add),
            onPressed: () => showAddAccountSheet(context),
          ),
        ],
      ),
      body: const _EmptyCodes(),
    );
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
              'Scan a TOTP QR code or paste an otpauth:// link with the + button.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
