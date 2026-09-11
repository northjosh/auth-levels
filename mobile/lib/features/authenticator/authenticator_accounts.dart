import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/secure_store.dart';
import 'authenticator_account.dart';

/// An [AuthenticatorAccount] as persisted: stable id plus creation time.
class StoredAccount {
  const StoredAccount({
    required this.id,
    required this.createdAt,
    required this.account,
  });

  final String id;
  final DateTime createdAt;
  final AuthenticatorAccount account;

  factory StoredAccount.fromJson(Map<String, Object?> json) => StoredAccount(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    account: AuthenticatorAccount.fromJson(json),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    ...account.toJson(),
  };
}

/// The user's Authenticator Accounts in display order, backed by secure
/// storage: `otp:index` holds the ordered ids, `otp:<id>` each entry.
///
/// Loading never fails on one bad entry: an unreadable `otp:<id>` is logged
/// and skipped so the rest of the list still shows.
class AuthenticatorAccounts extends AsyncNotifier<List<StoredAccount>> {
  static const indexKey = 'otp:index';
  static String entryKey(String id) => 'otp:$id';

  static const _uuid = Uuid();

  late SecureStore _store;

  @override
  Future<List<StoredAccount>> build() async {
    _store = ref.watch(secureStoreProvider);
    final rawIndex = await _store.read(indexKey);
    if (rawIndex == null) return const [];

    List<String> ids;
    try {
      ids = (jsonDecode(rawIndex) as List).cast<String>();
    } catch (e) {
      _log('Unreadable $indexKey, starting empty: $e');
      return const [];
    }

    final accounts = <StoredAccount>[];
    for (final id in ids) {
      final raw = await _store.read(entryKey(id));
      if (raw == null) {
        _log('Index lists $id but ${entryKey(id)} is missing; skipping');
        continue;
      }
      try {
        accounts.add(
          StoredAccount.fromJson(jsonDecode(raw) as Map<String, Object?>),
        );
      } catch (e) {
        // Only the error type: a FormatException would echo the raw entry,
        // secret included.
        _log('Unreadable ${entryKey(id)}; skipping (${e.runtimeType})');
      }
    }
    return accounts;
  }

  /// Appends [account] and returns its stored form.
  Future<StoredAccount> add(AuthenticatorAccount account) async {
    final stored = StoredAccount(
      id: _uuid.v4(),
      createdAt: DateTime.now().toUtc(),
      account: account,
    );
    final next = [...await future, stored];
    await _store.write(entryKey(stored.id), jsonEncode(stored.toJson()));
    await _writeIndex(next);
    state = AsyncData(next);
    return stored;
  }

  /// The stored account with the same issuer and account name, if any.
  StoredAccount? findDuplicate(AuthenticatorAccount account) {
    for (final stored in state.value ?? const <StoredAccount>[]) {
      if (stored.account.sameIdentityAs(account)) return stored;
    }
    return null;
  }

  /// Swaps the account behind [id] for [account], keeping id, position and
  /// the original creation time.
  Future<void> replace(String id, AuthenticatorAccount account) async {
    final next = [
      for (final stored in await future)
        if (stored.id == id)
          StoredAccount(id: id, createdAt: stored.createdAt, account: account)
        else
          stored,
    ];
    final replaced = next.firstWhere((s) => s.id == id);
    await _store.write(entryKey(id), jsonEncode(replaced.toJson()));
    state = AsyncData(next);
  }

  Future<void> remove(String id) async {
    final next = [
      for (final stored in await future)
        if (stored.id != id) stored,
    ];
    await _writeIndex(next);
    await _store.delete(entryKey(id));
    state = AsyncData(next);
  }

  Future<void> _writeIndex(List<StoredAccount> accounts) =>
      _store.write(indexKey, jsonEncode([for (final s in accounts) s.id]));

  void _log(String message) => developer.log(message, name: 'authenticator');
}

final authenticatorAccountsProvider =
    AsyncNotifierProvider<AuthenticatorAccounts, List<StoredAccount>>(
      AuthenticatorAccounts.new,
    );
