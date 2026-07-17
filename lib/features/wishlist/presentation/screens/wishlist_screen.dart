import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/wishlist_providers.dart';
import '../widgets/item_card.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(wishlistControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add'),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(wishlistControllerProvider.notifier).refresh(),
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: error is ApiException
                ? error.message
                : 'No se pudo cargar la lista.',
            onRetry: () =>
                ref.invalidate(wishlistControllerProvider),
          ),
          data: (items) => items.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 96),
                  itemCount: items.length,
                  itemBuilder: (context, i) => ItemCard(item: items[i]),
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ListView para que el pull-to-refresh funcione aun estando vacío.
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Icon(Icons.card_giftcard_outlined,
            size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('Tu lista está vacía',
            textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Agrega tu primer deseo con el botón “Agregar”.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Icon(Icons.cloud_off_outlined,
            size: 64, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(message,
              textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ),
      ],
    );
  }
}
