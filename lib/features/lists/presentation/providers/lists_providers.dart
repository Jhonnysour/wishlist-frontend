import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/list_repository.dart';
import '../../domain/product_list.dart';

/// Las listas del usuario. `build` observa la sesión (vacío al cerrar sesión).
class ListsController extends AsyncNotifier<List<ProductList>> {
  @override
  Future<List<ProductList>> build() async {
    final loggedIn = ref.watch(authControllerProvider).value ?? false;
    if (!loggedIn) return const [];
    return ref.read(listRepositoryProvider).fetchLists();
  }

  Future<void> create(String name) async {
    final created = await ref.read(listRepositoryProvider).createList(name);
    final current = state.value ?? const <ProductList>[];
    state = AsyncData([...current, created]);
  }

  Future<void> rename(String id, String name) async {
    final updated = await ref.read(listRepositoryProvider).renameList(id, name);
    _replace(updated);
  }

  Future<void> remove(String id) async {
    await ref.read(listRepositoryProvider).deleteList(id);
    final current = state.value ?? const <ProductList>[];
    state = AsyncData(current.where((l) => l.id != id).toList());
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(listRepositoryProvider).fetchLists(),
    );
  }

  void _replace(ProductList updated) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData([
      for (final l in list)
        if (l.id == updated.id) updated else l,
    ]);
  }
}

final listsControllerProvider =
    AsyncNotifierProvider<ListsController, List<ProductList>>(
  ListsController.new,
);

/// Una lista por id (para leer su nombre/contador en la vista de sus productos).
final listByIdProvider = Provider.family<ProductList?, String>((ref, id) {
  final lists = ref.watch(listsControllerProvider).value ?? const <ProductList>[];
  return lists.firstWhereOrNull((l) => l.id == id);
});
