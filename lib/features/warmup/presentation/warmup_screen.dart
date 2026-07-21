import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import '../../../core/config/env.dart';
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

  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _warmUp();
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
    final deadline = DateTime.now().add(_budget);
    while (mounted && DateTime.now().isBefore(deadline)) {
      if (await _ping()) {
        // El router redirige a la lista al marcar el server listo.
        ref.read(serverReadyProvider.notifier).markReady();
        return;
      }
      await Future<void>.delayed(_gap);
    }
    if (mounted) setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _failed
                ? [
                    Icon(Icons.cloud_off_outlined,
                        size: 64, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text('No se pudo conectar con el servidor.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _warmUp,
                      child: const Text('Reintentar'),
                    ),
                  ]
                : [
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 24),
                    Text('Encendiendo el servidor…',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'La primera vez del día puede tardar hasta ~1 minuto.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
