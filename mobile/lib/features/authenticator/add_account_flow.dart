import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/confirm_dialog.dart';
import 'add_account_sheet.dart';
import 'authenticator_account.dart';
import 'authenticator_accounts.dart';
import 'manual_entry_screen.dart';
import 'paste_link_dialog.dart';

/// "+" on the Codes tab: pick a method, collect an [AuthenticatorAccount],
/// then save it (asking before replacing a duplicate).
Future<void> startAddAccount(BuildContext context, WidgetRef ref) async {
  final method = await showAddAccountSheet(context);
  if (method == null || !context.mounted) return;

  final account = await switch (method) {
    AddAccountMethod.paste => showPasteLinkDialog(context),
    AddAccountMethod.manual => Navigator.of(context).push<AuthenticatorAccount>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ManualEntryScreen(),
      ),
    ),
    AddAccountMethod.scan => Future<AuthenticatorAccount?>.value(null),
  };
  if (account == null || !context.mounted) return;

  await saveAccount(context, ref, account);
}

/// Adds [account], or replaces the existing account with the same issuer
/// and account name after the user confirms. Storage failures surface as a
/// snackbar rather than an unhandled error.
Future<void> saveAccount(
  BuildContext context,
  WidgetRef ref,
  AuthenticatorAccount account,
) async {
  final accounts = ref.read(authenticatorAccountsProvider.notifier);
  try {
    // Make sure the list has loaded so the duplicate check sees it.
    await ref.read(authenticatorAccountsProvider.future);
    final existing = accounts.findDuplicate(account);
    if (existing == null) {
      await accounts.add(account);
      return;
    }
    if (!context.mounted) return;
    final replace = await confirmDialog(
      context,
      title: 'Replace existing?',
      body:
          'You already have ${account.issuer} (${account.account}). '
          'Replacing it swaps in the new secret; the old codes stop working.',
      action: 'Replace',
    );
    if (replace) await accounts.replace(existing.id, account);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Couldn't save the account: $e")));
  }
}
