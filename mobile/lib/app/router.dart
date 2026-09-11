import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/authenticator/codes_screen.dart';
import '../features/requests/request_detail_screen.dart';
import 'shell.dart';

/// Route paths, kept in one place so features never spell them by hand.
abstract final class Routes {
  static const codes = '/codes';
  static const account = '/account';
  static const requests = '/requests';
  static const requestIdParam = 'requestId';

  static String request(String requestId) => '$requests/$requestId';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.codes,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.codes,
                builder: (context, state) => const CodesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.account,
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '${Routes.requests}/:${Routes.requestIdParam}',
        builder: (context, state) => RequestDetailScreen(
          requestId: state.pathParameters[Routes.requestIdParam]!,
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
