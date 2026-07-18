import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// hide Headers: dio and postgrest (via supabase_flutter) both export it; we
// want dio's here (Headers.jsonContentType).
import 'package:supabase_flutter/supabase_flutter.dart' hide Headers;

import '../../features/auth/presentation/providers/auth_controller.dart';
import '../config/env.dart';

/// The shared Dio instance, pointed at the `/api/v1` base URL and wired with a
/// Supabase-session interceptor.
///
/// Interceptor behavior:
///   - onRequest: attaches `Authorization: Bearer <token>` from the current
///     Supabase session (refreshed automatically by the SDK) when present.
///   - onError (401): signs the session out so go_router redirects to login.
final dioProvider = Provider<Dio>((ref) {
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
      onRequest: (options, handler) {
        final token =
            Supabase.instance.client.auth.currentSession?.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await Supabase.instance.client.auth.signOut();
          // Reconstruye el estado de sesión -> go_router redirige a /login.
          ref.invalidate(authControllerProvider);
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
