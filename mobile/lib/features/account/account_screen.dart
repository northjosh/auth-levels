import 'package:flutter/material.dart';

import '../../app/section_label.dart';

/// Account tab. Shows the pairing card until a Trusted Device binding exists
/// (ticket 06); pending Push Requests and the activity timeline follow.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _PairingCard(),
          SizedBox(height: 24),
          _ActivityPlaceholder(),
        ],
      ),
    );
  }
}

class _PairingCard extends StatelessWidget {
  const _PairingCard();

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
            const FilledButton(
              onPressed: null,
              child: Text('Scan pairing code'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityPlaceholder extends StatelessWidget {
  const _ActivityPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Activity'),
        const SizedBox(height: 12),
        Text(
          'Sign-ins and security changes show here once paired.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
