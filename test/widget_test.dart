// Smoke test: sin token, la app redirige a la pantalla de login.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wishlist_frontend/core/storage/token_storage.dart';
import 'package:wishlist_frontend/main.dart';

/// TokenStorage en memoria: FlutterSecureStorage no tiene plugin en tests.
class _FakeTokenStorage extends TokenStorage {
  _FakeTokenStorage([this._token]) : super(const FlutterSecureStorage());

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

void main() {
  testWidgets('sin token, arranca en la pantalla de login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: const WishlistApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
