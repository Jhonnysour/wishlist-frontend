import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/token_storage.dart';
import '../../data/auth_repository.dart';

/// Estado de sesión de la app.
///
/// Como el backend no expone un endpoint `/me`, la sesión se determina por la
/// presencia de un token válido en el almacenamiento seguro. El valor es
/// `true` cuando hay sesión, `false` cuando no.
class AuthController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    return token != null && token.isNotEmpty;
  }

  /// Inicia sesión y persiste el token. Lanza [ApiException] si falla.
  Future<void> login({
    required String username,
    required String password,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final token = await repo.login(username: username, password: password);
    await ref.read(tokenStorageProvider).write(token);
    state = const AsyncData(true);
  }

  /// Crea la cuenta y, si tiene éxito, inicia sesión automáticamente.
  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.register(email: email, username: username, password: password);
    await login(username: username, password: password);
  }

  /// Cierra la sesión y limpia el token.
  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(false);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, bool>(AuthController.new);
