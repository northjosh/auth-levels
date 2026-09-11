import 'dart:convert';

import 'package:auth_levels/core/storage/secure_store.dart';
import 'package:auth_levels/features/authenticator/authenticator_account.dart';
import 'package:auth_levels/features/authenticator/authenticator_accounts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const github = AuthenticatorAccount(
  issuer: 'GitHub',
  account: 'northjosh',
  secret: 'JBSWY3DPEHPK3PXP',
);
const joshAuth = AuthenticatorAccount(
  issuer: 'JoshAuth',
  account: 'test@example.com',
  secret: 'SYSOCPZNPUZ3X6HL',
);

void main() {
  late InMemorySecureStore store;
  late ProviderContainer container;

  ProviderContainer newContainer() => ProviderContainer(
    overrides: [secureStoreProvider.overrideWithValue(store)],
  );

  setUp(() {
    store = InMemorySecureStore();
    container = newContainer();
  });
  tearDown(() => container.dispose());

  Future<List<StoredAccount>> accounts() =>
      container.read(authenticatorAccountsProvider.future);
  AuthenticatorAccounts notifier() =>
      container.read(authenticatorAccountsProvider.notifier);

  test('starts empty with nothing stored', () async {
    expect(await accounts(), isEmpty);
  });

  test('add persists an entry and the ordered index', () async {
    await accounts();
    final stored = await notifier().add(github);
    expect(stored.account, github);
    expect(stored.id, isNotEmpty);

    expect(jsonDecode(store.values['otp:index']!), [stored.id]);
    final entry = jsonDecode(store.values['otp:${stored.id}']!) as Map;
    expect(entry['id'], stored.id);
    expect(entry['issuer'], 'GitHub');
    expect(entry['account'], 'northjosh');
    expect(entry['secret'], 'JBSWY3DPEHPK3PXP');
    expect(entry['algorithm'], 'SHA1');
    expect(entry['digits'], 6);
    expect(entry['period'], 30);
    expect(DateTime.parse(entry['createdAt'] as String).isUtc, isTrue);
  });

  test('accounts survive a restart in insertion order', () async {
    await accounts();
    await notifier().add(github);
    await notifier().add(joshAuth);

    final fresh = newContainer();
    addTearDown(fresh.dispose);
    final reloaded = await fresh.read(authenticatorAccountsProvider.future);
    expect(reloaded.map((s) => s.account.issuer), ['GitHub', 'JoshAuth']);
    expect(reloaded.first.account.secret, github.secret);
  });

  test('an unreadable entry is skipped, not fatal', () async {
    store.values['otp:index'] = jsonEncode(['bad', 'missing', 'good']);
    store.values['otp:bad'] = '{not json';
    store.values['otp:good'] = jsonEncode({
      'id': 'good',
      'issuer': 'GitHub',
      'account': 'northjosh',
      'secret': 'JBSWY3DPEHPK3PXP',
      'algorithm': 'SHA256',
      'digits': 8,
      'period': 60,
      'createdAt': '2026-09-11T10:00:00.000Z',
    });

    final loaded = await accounts();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'good');
    expect(loaded.single.account.algorithm, TotpAlgorithm.sha256);
    expect(loaded.single.account.digits, 8);
    expect(loaded.single.account.period, 60);
  });

  test('remove drops the entry and its index slot', () async {
    await accounts();
    final a = await notifier().add(github);
    final b = await notifier().add(joshAuth);

    await notifier().remove(a.id);

    expect((await accounts()).map((s) => s.id), [b.id]);
    expect(store.values.containsKey('otp:${a.id}'), isFalse);
    expect(jsonDecode(store.values['otp:index']!), [b.id]);
  });

  test('findDuplicate matches on issuer and account', () async {
    await accounts();
    final stored = await notifier().add(github);

    expect(notifier().findDuplicate(github)?.id, stored.id);
    expect(
      notifier()
          .findDuplicate(
            const AuthenticatorAccount(
              issuer: 'GitHub',
              account: 'northjosh',
              secret: 'GEZDGNBVGY3TQOJQ',
            ),
          )
          ?.id,
      stored.id,
    );
    expect(notifier().findDuplicate(joshAuth), isNull);
  });

  test('replace keeps the id and position but swaps the secret', () async {
    await accounts();
    final a = await notifier().add(github);
    await notifier().add(joshAuth);

    const rotated = AuthenticatorAccount(
      issuer: 'GitHub',
      account: 'northjosh',
      secret: 'GEZDGNBVGY3TQOJQ',
      digits: 8,
    );
    await notifier().replace(a.id, rotated);

    final list = await accounts();
    expect(list.map((s) => s.id).first, a.id);
    expect(list.first.account, rotated);
    expect(jsonDecode(store.values['otp:${a.id}']!)['secret'], rotated.secret);
  });
}
