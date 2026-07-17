import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over [FlutterSecureStorage] for the JWT access token.
///
/// The token is issued by `POST /login` and expires after 24h; on a 401 the
/// Dio interceptor clears it (see `core/api/dio_client.dart`).
class TokenStorage {
  TokenStorage(this._storage);

  static const _key = 'access_token';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String token) => _storage.write(key: _key, value: token);

  Future<void> clear() => _storage.delete(key: _key);
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(const FlutterSecureStorage()),
);
