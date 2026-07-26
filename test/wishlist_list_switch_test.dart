// Al abrir una lista nunca deben verse los items de la lista anterior.
//
// Regresión de `d399e68`: con un único controller global, cambiar de lista solo
// producía un estado de carga que arrastraba el valor previo, y el
// `.when(skipLoadingOnReload: true, …)` de `_ItemList` lo pintaba igual. Ahora
// el `listId` es parte de la identidad del provider, así que cada lista arranca
// en una carga limpia.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wishlist_frontend/features/auth/presentation/providers/auth_controller.dart';
import 'package:wishlist_frontend/features/wishlist/data/wishlist_repository.dart';
import 'package:wishlist_frontend/features/wishlist/domain/item.dart';
import 'package:wishlist_frontend/features/wishlist/presentation/providers/wishlist_providers.dart';

/// Sesión activa sin tocar Supabase.
class _AlwaysLoggedIn extends AuthController {
  @override
  Future<bool> build() async => true;
}

class _FakeWishlistRepository extends WishlistRepository {
  _FakeWishlistRepository(this.itemsByList) : super(Dio());

  final Map<String, List<Item>> itemsByList;

  @override
  Future<List<Item>> fetchItems({
    String? listId,
    String? q,
    bool? purchased,
    int limit = 20,
    int offset = 0,
  }) async {
    // Latencia mínima: sin ella el fetch resolvería antes del primer read y el
    // test no vería el estado de carga que es justo lo que se quiere afirmar.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final all = itemsByList[listId] ?? const <Item>[];
    if (purchased == null) return all;
    return all.where((it) => it.purchased == purchased).toList();
  }
}

Item _item(String id) => Item(
      id: id,
      originalUrl: 'https://example.com/$id',
      status: ItemStatus.completed,
    );

/// Lo que `_ItemList` hace con el estado: devuelve qué se pinta en pantalla.
String _render(AsyncValue<List<Item>> value) => value.when(
      skipLoadingOnReload: true,
      loading: () => 'spinner',
      error: (_, _) => 'error',
      data: (items) => items.map((it) => it.id).join(','),
    );

void main() {
  late ProviderContainer container;

  setUp(() async {
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AlwaysLoggedIn.new),
        wishlistRepositoryProvider.overrideWithValue(
          _FakeWishlistRepository({
            'A': [_item('a1'), _item('a2')],
            'B': [_item('b1')],
            'vacia': const [],
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    // La sesión ya está resuelta antes de navegar por las listas, como en la
    // app. Sin esto el controller se construiría con `loggedIn == false`.
    await container.read(authControllerProvider.future);
  });

  /// Entrar a una lista: suscribe el provider igual que hace `_ItemList` al
  /// montarse (un `ProviderContainer` sin listeners no recomputa por su cuenta)
  /// y devuelve lo que se pintaría en el primer frame.
  String open(String listId) {
    container.listen(wishlistControllerProvider(listId), (_, _) {});
    return _render(container.read(wishlistControllerProvider(listId)));
  }

  test('abrir otra lista no muestra los items de la anterior', () async {
    open('A');
    await container.read(wishlistControllerProvider('A').future);
    expect(_render(container.read(wishlistControllerProvider('A'))), 'a1,a2');

    // Primer frame de la lista B, con A ya cargada en memoria.
    expect(open('B'), 'spinner');
    expect(
      container.read(wishlistControllerProvider('B')).hasValue,
      isFalse,
      reason: 'no debe arrastrar el valor de A',
    );

    await container.read(wishlistControllerProvider('B').future);
    expect(_render(container.read(wishlistControllerProvider('B'))), 'b1');
  });

  test('una lista vacía tampoco hereda los items de la anterior', () async {
    open('A');
    await container.read(wishlistControllerProvider('A').future);

    expect(open('vacia'), 'spinner');
    await container.read(wishlistControllerProvider('vacia').future);
    expect(_render(container.read(wishlistControllerProvider('vacia'))), '');
  });

  test('volver a una lista ya cargada la muestra al instante', () async {
    open('A');
    await container.read(wishlistControllerProvider('A').future);
    open('B');
    await container.read(wishlistControllerProvider('B').future);

    expect(open('A'), 'a1,a2');
  });

  test('filtrar dentro de una lista no parpadea a spinner', () async {
    open('A');
    await container.read(wishlistControllerProvider('A').future);

    container.read(wishlistFilterProvider('A').notifier).setPurchased(true);

    expect(
      _render(container.read(wishlistControllerProvider('A'))),
      'a1,a2',
      reason: 'mantiene la lista previa mientras recarga',
    );
  });

  test('cada lista tiene sus propios filtros', () async {
    container.read(wishlistFilterProvider('A').notifier).setPurchased(true);
    container.read(wishlistFilterProvider('A').notifier).setQuery('regalo');

    final b = container.read(wishlistFilterProvider('B'));
    expect(b.purchased, isNull);
    expect(b.query, isEmpty);
  });
}
