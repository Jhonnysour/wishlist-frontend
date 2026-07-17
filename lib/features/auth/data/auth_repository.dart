import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';

/// Habla con los endpoints de autenticación del backend.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  /// `POST /login` — OAuth2 **form-urlencoded** (username + password), NO JSON.
  /// Devuelve el `access_token`.
  Future<String> login({
    required String username,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/login',
        data: {'username': username, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final token = res.data?['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const ApiException('El servidor no devolvió un token de acceso.');
      }
      return token;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /users` — JSON. 201 crea la cuenta; 400 si el usuario ya existe.
  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/users',
        data: {'email': email, 'username': username, 'password': password},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);
