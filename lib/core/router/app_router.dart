import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/wishlist/presentation/screens/add_item_screen.dart';
import '../../features/wishlist/presentation/screens/wishlist_screen.dart';

/// Application router.
///
/// Rutas: `/` (lista), `/add` (alta), `/login`, `/register`. El `redirect`
/// protege la app según el estado de sesión (`authControllerProvider`) y un
/// `refreshListenable` reevalúa las rutas cada vez que ese estado cambia.
final routerProvider = Provider<GoRouter>((ref) {
  // Puente entre el provider de sesión y el refreshListenable de go_router.
  final authListenable = ValueNotifier<AsyncValue<bool>>(const AsyncLoading());
  ref.listen<AsyncValue<bool>>(
    authControllerProvider,
    (_, next) => authListenable.value = next,
    fireImmediately: true,
  );
  ref.onDispose(authListenable.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = authListenable.value;
      // Mientras se lee el token del almacenamiento seguro, no redirigir.
      if (auth.isLoading) return null;

      final loggedIn = auth.value ?? false;
      final loc = state.matchedLocation;
      final onAuthScreen = loc == '/login' || loc == '/register';

      if (!loggedIn) return onAuthScreen ? null : '/login';
      if (onAuthScreen) return '/';
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
        ],
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
