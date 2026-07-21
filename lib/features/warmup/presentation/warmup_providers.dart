import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` una vez que el backend respondió al menos una vez en esta sesión de
/// app. El router muestra la pantalla de warm-up hasta que esto sea `true`
/// (en la capa gratis de Render el server puede estar dormido al abrir la app).
class ServerReady extends Notifier<bool> {
  @override
  bool build() => false;

  void markReady() => state = true;
}

final serverReadyProvider = NotifierProvider<ServerReady, bool>(ServerReady.new);
