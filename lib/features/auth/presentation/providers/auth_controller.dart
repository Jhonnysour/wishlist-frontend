import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';

/// Estado de sesión de la app: `true` cuando hay una sesión de Supabase activa.
///
/// Se sincroniza con `onAuthStateChange`, así el refresh automático del token y
/// el cierre de sesión (incluido el que dispara un 401 en el interceptor de Dio)
/// se reflejan sin manejo manual del token.
class AuthController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final auth = Supabase.instance.client.auth;
    final sub = auth.onAuthStateChange.listen((data) {
      state = AsyncData(data.session != null);
    });
    ref.onDispose(sub.cancel);
    return auth.currentSession != null;
  }

  /// Inicia sesión (username -> email -> Supabase). Lanza [ApiException] si falla.
  Future<void> login({
    required String username,
    required String password,
  }) async {
    await ref
        .read(authRepositoryProvider)
        .login(username: username, password: password);
    state = const AsyncData(true);
  }

  /// Crea la cuenta y, con la confirmación de email desactivada, deja la sesión
  /// activa. Lanza [ApiException] si falla.
  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) async {
    await ref
        .read(authRepositoryProvider)
        .register(email: email, username: username, password: password);
    state = AsyncData(
      Supabase.instance.client.auth.currentSession != null,
    );
  }

  /// Cierra la sesión de Supabase.
  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(false);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, bool>(AuthController.new);
