import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Application router.
///
/// Scaffold stage: a single placeholder home route plus a placeholder `/login`.
/// The auth milestone will add:
///   - a `refreshListenable` bound to the auth controller, and
///   - a `redirect` that sends unauthenticated users to `/login`.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Wishlist',
          message: 'Scaffold ready. Wishlist features come next.',
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Sign in',
          message: 'Login screen placeholder (auth milestone).',
        ),
      ),
    ],
    // TODO(auth): add refreshListenable + redirect wired to authController.
    redirect: (context, state) => null,
  );
});

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.checklist_rounded,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
