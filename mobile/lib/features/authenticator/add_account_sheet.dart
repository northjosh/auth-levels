import 'package:flutter/material.dart';

/// The ways an Authenticator Account can be added.
enum AddAccountMethod { scan, paste, manual }

/// Bottom sheet offering the three ways to add an Authenticator Account.
/// Returns the chosen method, or null when dismissed. Scan is disabled until
/// ticket 05.
Future<AddAccountMethod?> showAddAccountSheet(BuildContext context) {
  return showModalBottomSheet<AddAccountMethod>(
    context: context,
    showDragHandle: true,
    builder: (context) => const AddAccountSheet(),
  );
}

class AddAccountSheet extends StatelessWidget {
  const AddAccountSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add an account',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.qr_code_scanner),
            title: Text('Scan QR code'),
            enabled: false,
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Paste otpauth:// link'),
            onTap: () => Navigator.pop(context, AddAccountMethod.paste),
          ),
          ListTile(
            leading: const Icon(Icons.keyboard),
            title: const Text('Enter details manually'),
            onTap: () => Navigator.pop(context, AddAccountMethod.manual),
          ),
        ],
      ),
    );
  }
}
