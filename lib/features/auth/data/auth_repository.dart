import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/api_exception.dart';

/// Autenticación contra Supabase Auth.
///
/// El login sigue siendo por **username**: como Supabase inicia sesión por
/// email, primero resolvemos username -> email con un RPC (`get_email_by_username`)
/// y luego llamamos `signInWithPassword`.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Resuelve el username a email y hace login. Lanza [ApiException] con un
  /// mensaje amigable si el usuario no existe o las credenciales fallan.
  Future<void> login({
    required String username,
    required String password,
  }) async {
    final email = await _emailForUsername(username);
    if (email == null) {
      throw const ApiException('Usuario o contraseña incorrectos.');
    }
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw ApiException(e.message);
    }
  }

  /// Crea la cuenta en Supabase con el username en la metadata (un trigger de la
  /// base lo copia a `public.users`). Con la confirmación de email desactivada,
  /// la sesión queda activa de inmediato.
  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final available = await _isUsernameAvailable(username);
    if (!available) {
      throw const ApiException('Ese nombre de usuario ya está en uso.');
    }
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
    } on AuthException catch (e) {
      throw ApiException(e.message);
    }
  }

  Future<void> logout() => _client.auth.signOut();

  Future<String?> _emailForUsername(String username) async {
    try {
      final res = await _client.rpc(
        'get_email_by_username',
        params: {'p_username': username},
      );
      return res as String?;
    } on PostgrestException catch (e) {
      throw ApiException(e.message);
    }
  }

  Future<bool> _isUsernameAvailable(String username) async {
    try {
      final res = await _client.rpc(
        'check_username_available',
        params: {'p_username': username},
      );
      return res as bool? ?? false;
    } on PostgrestException catch (e) {
      throw ApiException(e.message);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(Supabase.instance.client),
);
