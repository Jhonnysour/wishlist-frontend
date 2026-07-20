import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../webview_capture/data/webview_capture_repository.dart';
import '../../../webview_capture/data/webview_capture_service.dart';
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

  /// Items para los que ya se está intentando (o se intentó) la captura por
  /// WebView, para no dispararla dos veces sobre el mismo item.
  final Set<String> _capturingIds = {};

  @override
  Future<List<Item>> build() async {
    final loggedIn = ref.watch(authControllerProvider).value ?? false;
    if (!loggedIn) return const [];
    // Re-fetch cuando cambian los filtros (búsqueda / comprados).
    final filter = ref.watch(wishlistFilterProvider);
    return _fetch(filter);
  }

  Future<List<Item>> _fetch(WishlistFilter filter) {
    return ref.read(wishlistRepositoryProvider).fetchItems(
          q: filter.query.isEmpty ? null : filter.query,
          purchased: filter.purchased,
          limit: 50,
        );
  }

  /// Recarga la lista (pull-to-refresh). Mantiene la lista actual visible hasta
  /// que llega la nueva.
  Future<void> refresh() async {
    final filter = ref.read(wishlistFilterProvider);
    state = await AsyncValue.guard(() => _fetch(filter));
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
        if (fresh.status != ItemStatus.pending) {
          // Capa 0: si el scraping de servidor no alcanzó, reintentar con el
          // HTML que ve un navegador real (Amazon y similares).
          if (fresh.status == ItemStatus.failed) {
            unawaited(_captureFallback(fresh));
          }
          return;
        }
      } on ApiException {
        // Fallo transitorio: se reintenta en la próxima vuelta.
      }
    }
  }

  /// Carga la página en un WebView headless, captura su HTML y pide al backend
  /// re-extraer desde ahí. Se intenta una sola vez por item.
  Future<void> _captureFallback(Item item) async {
    if (_capturingIds.contains(item.id)) return;
    _capturingIds.add(item.id);
    // Mientras el WebView captura la página, mostrar "extrayendo…" en vez del
    // error: el FAILED del servidor es prematuro si la Capa 0 aún puede
    // recuperarlo. Como este `_replace` corre en el mismo turno que el que
    // puso FAILED, el mensaje de error ni llega a pintarse.
    _replace(item.copyWith(status: ItemStatus.pending));
    try {
      final html =
          await ref.read(webViewCaptureServiceProvider).capture(item.originalUrl);
      // El item pudo borrarse mientras cargaba el WebView.
      final list = state.value;
      if (list == null || !list.any((it) => it.id == item.id)) return;
      if (html == null || html.isEmpty) {
        _replace(item); // no se pudo capturar -> FAILED real
        return;
      }
      final updated = await ref
          .read(webViewCaptureRepositoryProvider)
          .retryFromHtml(item.id, html);
      _replace(updated); // COMPLETED, o FAILED si tampoco alcanzó
    } on ApiException {
      _replace(item); // restaura FAILED
    } finally {
      _capturingIds.remove(item.id);
    }
  }

  /// Marca/desmarca como comprado (PATCH). Lanza [ApiException] si falla.
  Future<void> togglePurchased(String id) async {
    final list = state.value;
    if (list == null) return;
    final current = list.where((it) => it.id == id).firstOrNull;
    if (current == null) return;
    final updated = await ref
        .read(wishlistRepositoryProvider)
        .setPurchased(id, !current.purchased);
    _replace(updated);
  }

  /// Cura las imágenes del item (subset reordenado; la primera es portada).
  /// Lanza [ApiException] si falla.
  Future<void> updateImages(String id, List<String> images) async {
    final updated = await ref
        .read(wishlistRepositoryProvider)
        .updateImages(id, images);
    _replace(updated);
  }

  /// Renombra el item. Lanza [ApiException] si falla.
  Future<void> updateTitle(String id, String title) async {
    final updated =
        await ref.read(wishlistRepositoryProvider).updateTitle(id, title);
    _replace(updated);
  }

  /// Elimina el item (DELETE). Lanza [ApiException] si falla.
  Future<void> remove(String id) async {
    await ref.read(wishlistRepositoryProvider).deleteItem(id);
    final list = state.value ?? const <Item>[];
    state = AsyncData(list.where((it) => it.id != id).toList());
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

/// Un item de la lista por id (reactivo: se actualiza con el polling y las
/// acciones). Es `null` si el item ya no está en la lista (p. ej. tras borrar).
final itemByIdProvider = Provider.family<Item?, String>((ref, id) {
  final list = ref.watch(wishlistControllerProvider).value ?? const <Item>[];
  return list.where((it) => it.id == id).firstOrNull;
});

/// Filtros de la lista: texto de búsqueda (`q`) y estado de compra
/// (`null` = todos, `true` = comprados, `false` = pendientes).
typedef WishlistFilter = ({String query, bool? purchased});

class WishlistFilterNotifier extends Notifier<WishlistFilter> {
  @override
  WishlistFilter build() => (query: '', purchased: null);

  void setQuery(String query) {
    if (query == state.query) return;
    state = (query: query, purchased: state.purchased);
  }

  void setPurchased(bool? purchased) {
    state = (query: state.query, purchased: purchased);
  }
}

final wishlistFilterProvider =
    NotifierProvider<WishlistFilterNotifier, WishlistFilter>(
  WishlistFilterNotifier.new,
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
