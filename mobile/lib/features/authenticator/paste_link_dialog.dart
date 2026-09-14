import 'package:flutter/material.dart';

import 'authenticator_account.dart';
import 'otpauth_parser.dart';

/// Single text field for an `otpauth://` link. Parses on Add; a rejection
/// shows its reason under the field and keeps the dialog open.
Future<AuthenticatorAccount?> showPasteLinkDialog(BuildContext context) {
  return showDialog<AuthenticatorAccount>(
    context: context,
    builder: (_) => const PasteLinkDialog(),
  );
}

class PasteLinkDialog extends StatefulWidget {
  const PasteLinkDialog({super.key});

  @override
  State<PasteLinkDialog> createState() => _PasteLinkDialogState();
}

class _PasteLinkDialogState extends State<PasteLinkDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      Navigator.pop(context, parseOtpAuthUri(_controller.text));
    } on OtpAuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste otpauth:// link'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        keyboardType: TextInputType.url,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: 'otpauth://totp/…',
          errorText: _error,
          errorMaxLines: 3,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
