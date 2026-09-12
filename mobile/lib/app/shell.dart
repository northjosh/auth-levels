import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/requests/push_requests.dart';

/// Two-tab scaffold: Codes (authenticator) and Account (pairing, requests,
/// activity). The Account icon carries a red dot while a Push Request is
/// open.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(
      openPushRequestsProvider.select((open) => open.isNotEmpty),
    );
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.pin_outlined),
            selectedIcon: Icon(Icons.pin),
            label: 'Codes',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pending,
              child: const Icon(Icons.shield_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pending,
              child: const Icon(Icons.shield),
            ),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
