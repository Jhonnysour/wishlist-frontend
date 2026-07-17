import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/wishlist_providers.dart';

/// Key global del ScaffoldMessenger, para mostrar SnackBars desde fuera del
/// árbol de una pantalla (al procesar un enlace compartido).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Escucha los enlaces que llegan desde la hoja de "Compartir" de Android.
///
/// Envuelve la app. Publica la URL compartida en [pendingSharedUrlProvider] y,
/// cuando hay sesión activa, dispara el mismo flujo que el alta manual
/// (`WishlistController.addByUrl`) navegando a la lista.
class ShareIntentListener extends ConsumerStatefulWidget {
  const ShareIntentListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShareIntentListener> createState() =>
      _ShareIntentListenerState();
}

class _ShareIntentListenerState extends ConsumerState<ShareIntentListener> {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  @override
  void initState() {
    super.initState();
    // Comparticiones mientras la app está viva.
    _sub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_onShared, onError: (_) {});
    // Compartición que abrió la app estando cerrada.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _onShared(files);
      ReceiveSharingIntent.instance.reset();
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onShared(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final url = _firstUrl(files);
    if (url == null) {
      scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No se encontró un enlace válido.')),
        );
      return;
    }
    ref.read(pendingSharedUrlProvider.notifier).set(url);
    // Los listeners de build reaccionan; además forzamos un intento tras el
    // primer frame para el caso de apertura en frío.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeProcess());
  }

  /// Procesa la URL pendiente solo si hay sesión activa; si no, la deja en
  /// espera hasta que el usuario inicie sesión.
  void _maybeProcess() {
    final url = ref.read(pendingSharedUrlProvider);
    if (url == null) return;
    final loggedIn = ref.read(authControllerProvider).value ?? false;
    if (!loggedIn) return;

    ref.read(pendingSharedUrlProvider.notifier).set(null);
    _addShared(url);
  }

  Future<void> _addShared(String url) async {
    final messenger = scaffoldMessengerKey.currentState;
    ref.read(routerProvider).go('/');
    try {
      await ref.read(wishlistControllerProvider.notifier).addByUrl(url);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Extrayendo el producto…')),
        );
    } on ApiException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo agregar el producto compartido.'),
        ),
      );
    }
  }

  static final _urlRegExp = RegExp(r'https?://[^\s]+');

  String? _firstUrl(List<SharedMediaFile> files) {
    for (final f in files) {
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        final match = _urlRegExp.firstMatch(f.path);
        if (match != null) return match.group(0);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Reacciona a un enlace nuevo (app viva) y al cambio de sesión (enlace en
    // espera + login posterior).
    ref.listen(pendingSharedUrlProvider, (_, _) => _maybeProcess());
    ref.listen(authControllerProvider, (_, _) => _maybeProcess());
    return widget.child;
  }
}
