import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import '../../../core/config/env.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import 'warmup_providers.dart';

/// Pantalla de arranque: espera a que el backend responda (en la capa gratis
/// puede estar dormido y tardar ~50s la primera vez) mostrando "Encendiendo el
/// servidor…". Cuando `/health` responde, marca el server listo y el router
/// transiciona solo a la lista.
class WarmupScreen extends ConsumerStatefulWidget {
  const WarmupScreen({super.key});

  @override
  ConsumerState<WarmupScreen> createState() => _WarmupScreenState();
}

class _WarmupScreenState extends ConsumerState<WarmupScreen> {
  /// Presupuesto total antes de rendirse y ofrecer "Reintentar".
  static const _budget = Duration(seconds: 120);
  static const _gap = Duration(seconds: 2);

  /// Tras esto, si el server aún no responde, mostramos el mensaje "Encendiendo
  /// el servidor…". Antes, solo el logo (evita el parpadeo cuando está caliente).
  static const _slowAfter = Duration(milliseconds: 2500);

  bool _failed = false;
  bool _slow = false;
  bool _started = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    // Solo pinguear si ya hay sesión. Durante la carga de sesión (o si el
    // usuario está deslogueado) se muestra solo el logo; el redirect llevará a
    // /login si no hay sesión. Así no se despierta el server sin necesidad.
    if (ref.read(authControllerProvider).value == true) _startWarmUp();
  }

  void _startWarmUp() {
    if (_started) return;
    _started = true;
    _warmUp();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<bool> _ping() async {
    try {
      final res = await ref.read(dioProvider).getUri<dynamic>(
            Uri.parse('${Env.apiBaseUrl}/health'),
          );
      return res.statusCode == 200;
    } on DioException {
      return false;
    }
  }

  Future<void> _warmUp() async {
    if (mounted) setState(() => _failed = false);
    _slowTimer?.cancel();
    _slow = false;
    _slowTimer = Timer(_slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
    final deadline = DateTime.now().add(_budget);
    while (mounted && DateTime.now().isBefore(deadline)) {
      if (await _ping()) {
        _slowTimer?.cancel();
        // El router redirige a la lista al marcar el server listo.
        ref.read(serverReadyProvider.notifier).markReady();
        return;
      }
      await Future<void>.delayed(_gap);
    }
    _slowTimer?.cancel();
    if (mounted) setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    // Si la sesión se resuelve estando en el splash, arrancar el warmup.
    ref.listen(authControllerProvider, (_, next) {
      if (next.value == true) _startWarmUp();
    });
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo (mismo del login): es el splash mientras el server despierta.
              Icon(Icons.checklist_rounded,
                  size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              if (_failed) ...[
                Icon(Icons.cloud_off_outlined,
                    size: 40, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text('No se pudo conectar con el servidor.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _warmUp,
                  child: const Text('Reintentar'),
                ),
              ] else if (_slow) ...[
                // Solo si el arranque tarda: feedback de que estamos esperando.
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 20),
                Text('Encendiendo el servidor…',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'La primera vez del día puede tardar hasta ~1 minuto.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
