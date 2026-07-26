import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../../../lists/presentation/providers/lists_providers.dart';
import '../providers/wishlist_providers.dart';
import '../widgets/item_card.dart';

/// Los productos de una lista. Apunta el `WishlistController` a esta lista.
class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    // Deja constancia de qué lista se está viendo, para que un enlace
    // compartido caiga aquí. No influye en qué items se cargan: de eso se
    // encarga el argumento de `wishlistControllerProvider`. Post-frame para no
    // modificar el provider durante el build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(currentListIdProvider.notifier).set(widget.listId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final name =
        ref.watch(listByIdProvider(widget.listId))?.name ?? 'Lista';
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/lists/${widget.listId}/add'),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: Column(
        children: [
          _FilterBar(listId: widget.listId),
          Expanded(child: _ItemList(listId: widget.listId)),
        ],
      ),
    );
  }
}

class _ItemList extends ConsumerWidget {
  const _ItemList({required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(wishlistControllerProvider(listId));
    final filter = ref.watch(wishlistFilterProvider(listId));
    final filtering = filter.query.isNotEmpty || filter.purchased != null;

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(wishlistControllerProvider(listId).notifier).refresh(),
      child: itemsAsync.when(
        // No parpadear a spinner al cambiar filtros: mantener la lista previa.
        // Solo aplica dentro de esta lista; abrirla por primera vez monta un
        // provider nuevo, sin valor previo, así que el spinner sí se muestra.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException
              ? error.message
              : 'No se pudo cargar la lista.',
          onRetry: () => ref.invalidate(wishlistControllerProvider(listId)),
        ),
        data: (items) => items.isEmpty
            ? _EmptyState(filtering: filtering)
            : ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 96),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  return ItemCard(
                    item: item,
                    onTap: () =>
                        context.push('/lists/$listId/item/${item.id}'),
                  );
                },
              ),
      ),
    );
  }
}

class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar({required this.listId});

  final String listId;

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Los filtros son por lista y sobreviven a salir y volver: el campo tiene
    // que mostrar la búsqueda guardada, no quedarse vacío con el filtro activo.
    _controller = TextEditingController(
      text: ref.read(wishlistFilterProvider(widget.listId)).query,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref
          .read(wishlistFilterProvider(widget.listId).notifier)
          .setQuery(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final purchased = ref.watch(
      wishlistFilterProvider(widget.listId).select((f) => f.purchased),
    );
    final notifier = ref.read(wishlistFilterProvider(widget.listId).notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar en tu lista',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        _debounce?.cancel();
                        notifier.setQuery('');
                        setState(() {}); // refrescar el suffixIcon
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _FilterChoice(
                label: 'Todos',
                selected: purchased == null,
                onSelected: () => notifier.setPurchased(null),
              ),
              _FilterChoice(
                label: 'Pendientes',
                selected: purchased == false,
                onSelected: () => notifier.setPurchased(false),
              ),
              _FilterChoice(
                label: 'Comprados',
                selected: purchased == true,
                onSelected: () => notifier.setPurchased(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtering});

  final bool filtering;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ListView para que el pull-to-refresh funcione aun estando vacío.
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
        Icon(
          filtering ? Icons.search_off : Icons.card_giftcard_outlined,
          size: 72,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          filtering ? 'Sin resultados' : 'Tu lista está vacía',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            filtering
                ? 'Prueba con otra búsqueda o cambia el filtro.'
                : 'Agrega tu primer deseo con el botón “Agregar”.',
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
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
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
