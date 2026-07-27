import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../lists/presentation/providers/lists_providers.dart';
import '../../../webview_capture/data/webview_capture_repository.dart';
import '../../../webview_capture/data/webview_capture_service.dart';
import '../../data/wishlist_repository.dart';
import '../../domain/item.dart';

/// Estado de los items de **una** lista.
///
/// Hay una instancia por `listId` (ver [wishlistControllerProvider]): así, abrir
/// otra lista monta un provider nuevo que arranca en `AsyncLoading` limpio, sin
/// arrastrar los items de la lista anterior. `build()` observa la sesión: al
/// iniciar sesión trae los items, al cerrarla la lista queda vacía. `addByUrl`
/// inserta el item PENDING de forma optimista y hace polling a `GET /items/{id}`
/// hasta que el scraping termina.
class WishlistController extends AsyncNotifier<List<Item>> {
  WishlistController(this.listId);

  /// La lista a la que pertenecen estos items (argumento de la family).
  final String listId;

  static const _pollInterval = Duration(milliseconds: 1800);
  static const _maxPollAttempts = 40; // ~72 s

  /// Items para los que ya se está intentando (o se intentó) la captura por
  /// WebView, para no dispararla dos veces sobre el mismo item.
  final Set<String> _capturingIds = {};

  @override
  Future<List<Item>> build() async {
    final loggedIn = ref.watch(authControllerProvider).value ?? false;
    if (!loggedIn) return const [];
    // Re-fetch cuando cambian los filtros de esta lista (búsqueda / comprados).
    final filter = ref.watch(wishlistFilterProvider(listId));
    return _fetch(filter);
  }

  Future<List<Item>> _fetch(WishlistFilter filter) {
    return ref.read(wishlistRepositoryProvider).fetchItems(
          listId: listId,
          q: filter.query.isEmpty ? null : filter.query,
          purchased: filter.purchased,
          limit: 50,
        );
  }

  /// Recarga la lista (pull-to-refresh). Mantiene la lista actual visible hasta
  /// que llega la nueva.
  Future<void> refresh() async {
    final filter = ref.read(wishlistFilterProvider(listId));
    state = await AsyncValue.guard(() => _fetch(filter));
  }

  /// Encola un producto por URL en esta lista. Lanza [ApiException] si falla.
  Future<void> addByUrl(String url) async {
    final repo = ref.read(wishlistRepositoryProvider);
    final created = await repo.addItem(url, listId: listId); // 202 PENDING
    final current = state.value ?? const <Item>[];
    state = AsyncData([created, ...current]); // newest-first
    // Mantener el contador de la vista de listas al día, sin refetch.
    ref.read(listsControllerProvider.notifier).bumpCount(listId, 1);
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
          //
          // "No alcanzó" incluye el COMPLETED **sin precio**: MercadoLibre
          // responde a los scrapers con su muro anti-bot, que igual trae
          // og:title y og:image — suficiente para que el backend lo dé por
          // bueno. Mirando solo el status, el navegador del móvil (lo único
          // con opción real de pasar ese muro) nunca llegaba a intentarlo.
          if (fresh.status == ItemStatus.failed || fresh.price == null) {
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
    final diagnostics = ref.read(captureDiagnosticProvider.notifier);
    try {
      final capture =
          await ref.read(webViewCaptureServiceProvider).capture(item.originalUrl);
      // El item pudo borrarse mientras cargaba el WebView.
      final list = state.value;
      if (list == null || !list.any((it) => it.id == item.id)) return;
      if (!capture.ok) {
        diagnostics.set(item.id, capture.diagnostic, capture.finalUrl);
        _replace(item); // no se pudo capturar -> FAILED real
        return;
      }
      final updated = await ref
          .read(webViewCaptureRepositoryProvider)
          .retryFromHtml(item.id, capture.html!);
      // Capturamos una página pero el backend no sacó nada de ella: saber su
      // tamaño y de dónde salió distingue "no llegamos" de "llegamos al muro".
      if (updated.status == ItemStatus.failed) {
        final kb = (capture.html!.length / 1024).round();
        diagnostics.set(item.id, 'capturado $kb KB, sin datos', capture.finalUrl);
      } else {
        diagnostics.clear(item.id);
      }
      _replace(updated); // COMPLETED, o FAILED si tampoco alcanzó
    } on ApiException catch (e) {
      diagnostics.set(item.id, 'el servidor rechazó el HTML: ${e.message}', null);
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

  /// Fija (o borra, con `null`) el precio a mano. Lanza [ApiException] si falla.
  Future<void> updatePrice(String id, double? price) async {
    final updated =
        await ref.read(wishlistRepositoryProvider).updatePrice(id, price);
    _replace(updated);
  }

  /// Elimina el item (DELETE). Lanza [ApiException] si falla.
  Future<void> remove(String id) async {
    await ref.read(wishlistRepositoryProvider).deleteItem(id);
    final list = state.value ?? const <Item>[];
    state = AsyncData(list.where((it) => it.id != id).toList());
    ref.read(listsControllerProvider.notifier).bumpCount(listId, -1);
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

/// Los items de una lista, keyed por `listId`.
///
/// Que el `listId` sea parte de la identidad del provider (y no un estado
/// mutable aparte) es lo que garantiza que abrir otra lista empiece en un
/// `AsyncLoading` limpio: `when()` solo se salta el spinner cuando el estado de
/// carga arrastra un valor previo, y una lista recién abierta no tiene ninguno.
///
/// No es `autoDispose` a propósito: `addByUrl` hace polling de hasta ~72 s y
/// tiene que sobrevivir a que el usuario vuelva a la pantalla de listas.
final wishlistControllerProvider =
    AsyncNotifierProvider.family<WishlistController, List<Item>, String>(
  WishlistController.new,
);

/// La lista que se está viendo ahora mismo. La setea `WishlistScreen` al entrar.
///
/// Ya no decide qué items se cargan (de eso se encarga el argumento de
/// [wishlistControllerProvider]); solo sirve para que un enlace compartido caiga
/// en la lista que el usuario estaba viendo (ver `ShareIntentListener`).
class CurrentListId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final currentListIdProvider =
    NotifierProvider<CurrentListId, String?>(CurrentListId.new);

/// Por qué falló la captura por WebView de cada item, para poder mostrarlo.
///
/// Cuando la Capa 0 falla en el móvil no queda rastro alguno: el item sale como
/// "no se pudo extraer" y desde el PC es imposible saber si el WebView no cargó,
/// si lo redirigieron a la app de la tienda o si la página vino vacía —
/// comprobar cada hipótesis costaba compilar un APK. Vive solo en memoria: es
/// información de depuración de este intento, no algo que guardar.
class CaptureDiagnostics extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void set(String itemId, String? reason, String? finalUrl) {
    if (reason == null || reason.isEmpty) return;
    final where = (finalUrl == null || finalUrl.isEmpty) ? '' : '\n$finalUrl';
    state = {...state, itemId: '$reason$where'};
  }

  void clear(String itemId) {
    if (!state.containsKey(itemId)) return;
    state = {...state}..remove(itemId);
  }
}

final captureDiagnosticProvider =
    NotifierProvider<CaptureDiagnostics, Map<String, String>>(
  CaptureDiagnostics.new,
);

/// Un item de una lista por id (reactivo: se actualiza con el polling y las
/// acciones). Es `null` si el item ya no está en la lista (p. ej. tras borrar).
final itemByIdProvider =
    Provider.family<Item?, ({String listId, String itemId})>((ref, arg) {
  final list =
      ref.watch(wishlistControllerProvider(arg.listId)).value ?? const <Item>[];
  return list.where((it) => it.id == arg.itemId).firstOrNull;
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

/// Los filtros son por lista: cada una recuerda los suyos y ninguna hereda los
/// de otra al abrirla.
final wishlistFilterProvider =
    NotifierProvider.family<WishlistFilterNotifier, WishlistFilter, String>(
  (_) => WishlistFilterNotifier(),
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
