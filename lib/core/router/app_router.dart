import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/warmup/presentation/warmup_providers.dart';
import '../../features/warmup/presentation/warmup_screen.dart';
import '../../features/wishlist/presentation/screens/add_item_screen.dart';
import '../../features/wishlist/presentation/screens/item_detail_screen.dart';
import '../../features/wishlist/presentation/screens/wishlist_screen.dart';

/// Application router.
///
/// Rutas: `/` (lista), `/add` (alta), `/login`, `/register`. El `redirect`
/// protege la app según el estado de sesión (`authControllerProvider`) y un
/// `refreshListenable` reevalúa las rutas cada vez que ese estado cambia.
final routerProvider = Provider<GoRouter>((ref) {
  // Bump-based listenable: go_router reevalúa cuando cambia la sesión O el
  // estado de "server listo".
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++,
      fireImmediately: true);
  ref.listen(serverReadyProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      // Mientras se lee la sesión, no redirigir.
      if (auth.isLoading) return null;

      final loggedIn = auth.value ?? false;
      final serverReady = ref.read(serverReadyProvider);
      final loc = state.matchedLocation;
      final onAuthScreen = loc == '/login' || loc == '/register';
      final onWarmup = loc == '/warmup';

      if (!loggedIn) return onAuthScreen ? null : '/login';
      // Logueado: esperar a que el backend responda antes de entrar a la app.
      if (!serverReady) return onWarmup ? null : '/warmup';
      if (onAuthScreen || onWarmup) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const WishlistScreen(),
        routes: [
          GoRoute(
            path: 'add',
            name: 'add',
            builder: (context, state) => const AddItemScreen(),
          ),
          GoRoute(
            path: 'item/:id',
            name: 'item',
            builder: (context, state) =>
                ItemDetailScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/warmup',
        name: 'warmup',
        builder: (context, state) => const WarmupScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
    ],
  );
});
