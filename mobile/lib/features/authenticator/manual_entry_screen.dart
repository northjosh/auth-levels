import 'package:flutter/material.dart';

import 'authenticator_account.dart';
import 'otpauth_parser.dart';

/// Full-screen form: issuer, account, secret, and an Advanced fold for
/// algorithm / digits / period. Pops with the [AuthenticatorAccount].
class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _issuer = TextEditingController();
  final _account = TextEditingController();
  final _secret = TextEditingController();
  final _period = TextEditingController(text: '30');
  var _algorithm = TotpAlgorithm.sha1;
  var _digits = 6;

  String? _issuerError;
  String? _accountError;
  String? _secretError;
  String? _periodError;

  @override
  void dispose() {
    for (final c in [_issuer, _account, _secret, _period]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final issuer = _issuer.text.trim();
    final account = _account.text.trim();
    String? secret;
    String? secretError;
    try {
      secret = normaliseSecret(_secret.text);
    } on OtpAuthException catch (e) {
      secretError = e.message;
    }
    int? period;
    String? periodError;
    try {
      period = parsePeriod(_period.text);
    } on OtpAuthException catch (e) {
      periodError = e.message;
    }

    setState(() {
      _issuerError = issuer.isEmpty ? 'Enter the service name.' : null;
      _accountError = account.isEmpty ? 'Enter the account name.' : null;
      _secretError = secretError;
      _periodError = periodError;
    });
    if ([
      _issuerError,
      _accountError,
      _secretError,
      _periodError,
    ].any((e) => e != null)) {
      return;
    }

    Navigator.pop(
      context,
      AuthenticatorAccount(
        issuer: issuer,
        account: account,
        secret: secret!,
        algorithm: _algorithm,
        digits: _digits,
        period: period!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter details'),
        actions: [TextButton(onPressed: _submit, child: const Text('Add'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _issuer,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Issuer',
              hintText: 'GitHub',
              errorText: _issuerError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _account,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Account',
              hintText: 'you@example.com',
              errorText: _accountError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _secret,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Secret',
              hintText: 'Base32 key, spaces allowed',
              errorText: _secretError,
            ),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('Advanced'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              DropdownButtonFormField<TotpAlgorithm>(
                initialValue: _algorithm,
                decoration: const InputDecoration(labelText: 'Algorithm'),
                items: [
                  for (final a in TotpAlgorithm.values)
                    DropdownMenuItem(value: a, child: Text(a.label)),
                ],
                onChanged: (a) => setState(() => _algorithm = a ?? _algorithm),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('Digits')),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 6, label: Text('6')),
                      ButtonSegment(value: 8, label: Text('8')),
                    ],
                    selected: {_digits},
                    onSelectionChanged: (s) =>
                        setState(() => _digits = s.single),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _period,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Period (seconds)',
                  errorText: _periodError,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
