// Smoke test: sin sesión de Supabase, la app arranca en la pantalla de login.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wishlist_frontend/main.dart';

void main() {
  setUp(() async {
    // Supabase persiste la sesión en SharedPreferences; sin plugin en tests,
    // usamos el mock en memoria (vacío -> sin sesión previa).
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_test',
    );
  });

  tearDown(() async {
    await Supabase.instance.dispose();
  });

  testWidgets('sin sesión, arranca en la pantalla de login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WishlistApp()));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
