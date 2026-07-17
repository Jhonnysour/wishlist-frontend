// Smoke test: the app boots to the placeholder home screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wishlist_frontend/main.dart';

void main() {
  testWidgets('boots to the placeholder home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WishlistApp()));
    await tester.pumpAndSettle();

    expect(find.text('Wishlist'), findsOneWidget);
    expect(find.textContaining('Scaffold ready'), findsOneWidget);
  });
}
