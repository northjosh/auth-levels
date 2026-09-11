import 'package:flutter/material.dart';

/// Bottom sheet offering the three ways to add an Authenticator Account.
/// Options are placeholders until tickets 04 and 05 wire them up.
Future<void> showAddAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
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
          const ListTile(
            leading: Icon(Icons.link),
            title: Text('Paste otpauth:// link'),
            enabled: false,
          ),
          const ListTile(
            leading: Icon(Icons.keyboard),
            title: Text('Enter details manually'),
            enabled: false,
          ),
        ],
      ),
    );
  }
}
