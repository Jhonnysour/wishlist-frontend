import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/wishlist_repository.dart';
import '../../domain/item.dart';

/// Estado de la lista de deseos.
///
/// `build()` observa la sesión: al iniciar sesión trae los items, al cerrarla
/// la lista queda vacía. `addByUrl` inserta el item PENDING de forma optimista
/// y hace polling a `GET /items/{id}` hasta que el scraping termina.
class WishlistController extends AsyncNotifier<List<Item>> {
  static const _pollInterval = Duration(milliseconds: 1800);
  static const _maxPollAttempts = 40; // ~72 s

  @override
  Future<List<Item>> build() async {
    final loggedIn = ref.watch(authControllerProvider).value ?? false;
    if (!loggedIn) return const [];
    return ref.read(wishlistRepositoryProvider).fetchItems(limit: 50);
  }

  /// Recarga la lista (pull-to-refresh). Mantiene la lista actual visible hasta
  /// que llega la nueva.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(wishlistRepositoryProvider).fetchItems(limit: 50),
    );
  }

  /// Encola un producto por URL. Lanza [ApiException] si el POST falla.
  Future<void> addByUrl(String url) async {
    final repo = ref.read(wishlistRepositoryProvider);
    final created = await repo.addItem(url); // 202 PENDING
    final current = state.value ?? const <Item>[];
    state = AsyncData([created, ...current]); // newest-first
    unawaited(_poll(created.id));
  }

  /// Hace polling del scraping hasta COMPLETED/FAILED o agotar los intentos.
  Future<void> _poll(String id) async {
    final repo = ref.read(wishlistRepositoryProvider);
    for (var attempt = 0; attempt < _maxPollAttempts; attempt++) {
      await Future<void>.delayed(_pollInterval);
      // El item pudo borrarse o la lista recargarse: si ya no está, cortar.
      final list = state.value;
      if (list == null || !list.any((it) => it.id == id)) return;
      try {
        final fresh = await repo.fetchItem(id);
        _replace(fresh);
        if (fresh.status != ItemStatus.pending) return;
      } on ApiException {
        // Fallo transitorio: se reintenta en la próxima vuelta.
      }
    }
  }

  void _replace(Item updated) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData([
      for (final it in list)
        if (it.id == updated.id) updated else it,
    ]);
  }
}

final wishlistControllerProvider =
    AsyncNotifierProvider<WishlistController, List<Item>>(
  WishlistController.new,
);

/// URL recibida desde la hoja de "Compartir" de Android que aún no se procesa.
///
/// El listener de share la publica aquí; se consume cuando hay sesión activa
/// (ver `ShareIntentListener`). Así, un enlace compartido sin sesión queda a la
/// espera y se agrega automáticamente tras iniciar sesión.
class PendingSharedUrl extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? url) => state = url;
}

final pendingSharedUrlProvider =
    NotifierProvider<PendingSharedUrl, String?>(PendingSharedUrl.new);
