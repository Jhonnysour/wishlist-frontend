import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../wishlist/presentation/providers/wishlist_providers.dart';
import '../../domain/product_list.dart';
import '../providers/lists_providers.dart';

/// Pantalla principal: las listas del usuario. Tocar una entra a sus productos.
class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(listsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis listas'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nueva lista'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(listsControllerProvider.notifier).refresh(),
        child: listsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            message: e is ApiException ? e.message : 'No se pudieron cargar las listas.',
            onRetry: () => ref.invalidate(listsControllerProvider),
          ),
          data: (lists) => lists.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 96),
                  itemCount: lists.length,
                  itemBuilder: (context, i) => _ListCard(list: lists[i]),
                ),
        ),
      ),
    );
  }
}

class _ListCard extends ConsumerWidget {
  const _ListCard({required this.list});

  final ProductList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final n = list.itemCount;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.list_alt, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(list.name, style: theme.textTheme.titleMedium),
        subtitle: Text(n == 1 ? '1 producto' : '$n productos'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'rename') _renameDialog(context, ref, list);
            if (v == 'delete') _deleteDialog(context, ref, list);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Renombrar')),
            PopupMenuItem(value: 'delete', child: Text('Eliminar')),
          ],
        ),
        onTap: () {
          // Cada lista tiene su propio `wishlistControllerProvider(listId)`, así
          // que la pantalla destino arranca en carga limpia sin que haya que
          // resetear nada aquí. Esto solo deja anotada la lista visible, para
          // que un enlace compartido caiga en ella.
          ref.read(currentListIdProvider.notifier).set(list.id);
          context.push('/lists/${list.id}');
        },
      ),
    );
  }
}

Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final name = await _nameDialog(context, title: 'Nueva lista');
  if (name == null) return;
  try {
    await ref.read(listsControllerProvider.notifier).create(name);
  } on ApiException catch (e) {
    _snack(messenger, e.message);
  } catch (_) {
    _snack(messenger, 'No se pudo crear la lista.');
  }
}

Future<void> _renameDialog(
    BuildContext context, WidgetRef ref, ProductList list) async {
  final messenger = ScaffoldMessenger.of(context);
  final name =
      await _nameDialog(context, title: 'Renombrar lista', initial: list.name);
  if (name == null || name == list.name) return;
  try {
    await ref.read(listsControllerProvider.notifier).rename(list.id, name);
  } on ApiException catch (e) {
    _snack(messenger, e.message);
  } catch (_) {
    _snack(messenger, 'No se pudo renombrar la lista.');
  }
}

Future<void> _deleteDialog(
    BuildContext context, WidgetRef ref, ProductList list) async {
  final messenger = ScaffoldMessenger.of(context);
  final n = list.itemCount;
  final detail = n == 0
      ? 'Esta lista está vacía.'
      : n == 1
          ? 'Esto también borrará 1 producto.'
          : 'Esto también borrará $n productos.';
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Eliminar “${list.name}”'),
      content: Text('$detail\n\nEsta acción no se puede deshacer.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (confirm != true) return;
  try {
    await ref.read(listsControllerProvider.notifier).remove(list.id);
  } on ApiException catch (e) {
    _snack(messenger, e.message);
  } catch (_) {
    _snack(messenger, 'No se pudo eliminar la lista.');
  }
}

/// Diálogo de texto reutilizable; devuelve el nombre recortado o null si cancela.
Future<String?> _nameDialog(BuildContext context,
    {required String title, String initial = ''}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 100,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nombre de la lista'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  controller.dispose();
  final name = result?.trim();
  return (name == null || name.isEmpty) ? null : name;
}

void _snack(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
        Icon(Icons.playlist_add, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('Aún no tienes listas',
            textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Crea tu primera lista con el botón “Nueva lista”.',
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
        Icon(Icons.cloud_off_outlined, size: 64, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(message,
              textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.tonal(onPressed: onRetry, child: const Text('Reintentar')),
        ),
      ],
    );
  }
}
