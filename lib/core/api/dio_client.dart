import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_controller.dart';
import '../config/env.dart';
import '../storage/token_storage.dart';

/// The shared Dio instance, pointed at the `/api/v1` base URL and wired with a
/// token interceptor.
///
/// Interceptor behavior:
///   - onRequest: attaches `Authorization: Bearer <token>` when a token exists.
///   - onError (401): clears the stored token so the next launch/redirect sends
///     the user back to login.
///
/// Note for the auth milestone: `POST /login` must be sent as
/// `contentType: Headers.formUrlEncodedContentType` (OAuth2 form, not JSON).
final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiV1BaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.read();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await tokenStorage.clear();
          // Reconstruye el estado de sesión: al releer el token (ya borrado)
          // pasa a "no autenticado" y go_router redirige a /login.
          ref.invalidate(authControllerProvider);
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
