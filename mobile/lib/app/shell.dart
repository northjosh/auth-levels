import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Two-tab scaffold: Codes (authenticator) and Account (pairing, requests, activity).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pin_outlined),
            selectedIcon: Icon(Icons.pin),
            label: 'Codes',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
