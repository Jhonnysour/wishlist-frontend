import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/remote_image.dart';
import '../../domain/item.dart';
import '../providers/wishlist_providers.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({super.key, required this.listId, required this.id});

  /// La lista a la que pertenece el item.
  final String listId;
  final String id;

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  bool _working = false;

  /// El controller de la lista que contiene este item.
  WishlistController get _controller =>
      ref.read(wishlistControllerProvider(widget.listId).notifier);

  Future<void> _togglePurchased() async {
    setState(() => _working = true);
    try {
      await _controller.togglePurchased(widget.id);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo actualizar el producto.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: const Text('¿Seguro que quieres quitarlo de tu lista?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _working = true);
    try {
      await _controller.remove(widget.id);
      if (mounted) context.pop(); // vuelve a la lista
    } on ApiException catch (e) {
      _snack(e.message);
      if (mounted) setState(() => _working = false);
    } catch (_) {
      _snack('No se pudo eliminar el producto.');
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _editTitle(String? currentTitle) async {
    final controller = TextEditingController(text: currentTitle ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar título'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 255,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Título del producto'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return; // cancelado
    final trimmed = result.trim();
    if (trimmed.isEmpty) {
      _snack('El título no puede estar vacío.');
      return;
    }
    if (trimmed == (currentTitle ?? '').trim()) return; // sin cambios

    setState(() => _working = true);
    try {
      await _controller.updateTitle(widget.id, trimmed);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo actualizar el título.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _editImages(List<String> current) async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => _ImageEditorScreen(images: current)),
    );
    if (result == null) return; // cancelado
    setState(() => _working = true);
    try {
      await _controller.updateImages(widget.id, result);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudieron actualizar las imágenes.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(
      itemByIdProvider((listId: widget.listId, itemId: widget.id)),
    );

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Este producto ya no está disponible.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle'),
        actions: [
          if (item.status == ItemStatus.completed && item.images.isNotEmpty)
            IconButton(
              tooltip: 'Editar imágenes',
              icon: const Icon(Icons.photo_library_outlined),
              onPressed: _working ? null : () => _editImages(item.images),
            ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: _working ? null : _delete,
          ),
        ],
      ),
      bottomNavigationBar: item.status == ItemStatus.completed
          ? _PurchaseBar(
              purchased: item.purchased,
              working: _working,
              onPressed: _working ? null : _togglePurchased,
            )
          : null,
      body: _Body(item: item, onEditTitle: () => _editTitle(item.title)),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.item, required this.onEditTitle});

  final Item item;
  final VoidCallback onEditTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (item.status == ItemStatus.pending) {
      return const _Centered(
        icon: Icons.hourglass_top,
        title: 'Extrayendo el producto…',
        subtitle: 'Esto tarda unos segundos. La información aparecerá sola.',
      );
    }
    if (item.status == ItemStatus.failed) {
      return _Centered(
        icon: Icons.error_outline,
        iconColor: scheme.error,
        title: 'No se pudo extraer el producto',
        subtitle: item.originalUrl,
      );
    }

    // COMPLETED
    final title = item.title?.trim().isNotEmpty == true
        ? item.title!.trim()
        : 'Producto sin título';
    return ListView(
      children: [
        if (item.images.isNotEmpty) _Gallery(images: item.images),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.headlineSmall),
                  ),
                  IconButton(
                    tooltip: 'Editar título',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEditTitle,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (item.price != null)
                    Text(
                      '\$${item.price!.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const Spacer(),
                  if (item.purchased) const _PurchasedChip(),
                ],
              ),
              if (item.description != null &&
                  item.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Descripción', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(item.description!.trim(),
                    style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              _SourceRow(item: item),
            ],
          ),
        ),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images});

  final List<String> images;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => RemoteImage(
              url: widget.images[i],
              fit: BoxFit.contain,
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.images.length; i++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.25),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.link, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.domainSource != null && item.domainSource!.isNotEmpty)
                Text(item.domainSource!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              Text(item.originalUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Copiar enlace',
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: item.originalUrl));
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Enlace copiado.')),
              );
          },
        ),
      ],
    );
  }
}

class _PurchaseBar extends StatelessWidget {
  const _PurchaseBar({
    required this.purchased,
    required this.working,
    required this.onPressed,
  });

  final bool purchased;
  final bool working;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: FilledButton.icon(
        onPressed: onPressed,
        style: purchased
            ? FilledButton.styleFrom(backgroundColor: AppTheme.purchased)
            : null,
        icon: working
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(purchased
                ? Icons.check_circle
                : Icons.shopping_cart_checkout),
        label: Text(purchased
            ? 'Comprado — marcar como pendiente'
            : 'Marcar como comprado'),
      ),
    );
  }
}

class _PurchasedChip extends StatelessWidget {
  const _PurchasedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.purchased.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 15, color: AppTheme.purchased),
          const SizedBox(width: 5),
          Text('Comprado',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.purchased)),
        ],
      ),
    );
  }
}

/// Editor de imágenes: elegir cuáles conservar y cuál es la portada.
///
/// Devuelve (via `Navigator.pop`) la lista curada — subconjunto reordenado con
/// la portada primero — o `null` si se cancela. El backend valida que sea un
/// subconjunto de las imágenes actuales.
class _ImageEditorScreen extends StatefulWidget {
  const _ImageEditorScreen({required this.images});

  final List<String> images;

  @override
  State<_ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<_ImageEditorScreen> {
  late final Set<String> _kept = {...widget.images};
  late String? _cover = widget.images.isNotEmpty ? widget.images.first : null;

  /// Lista final: portada primero, luego el resto de las conservadas en su
  /// orden original.
  List<String> _result() {
    final kept = widget.images.where(_kept.contains).toList();
    if (_cover != null && kept.remove(_cover)) kept.insert(0, _cover!);
    return kept;
  }

  void _toggleKeep(String url) {
    setState(() {
      if (_kept.remove(url)) {
        if (_cover == url) {
          _cover = _kept.isEmpty
              ? null
              : widget.images.firstWhere(_kept.contains);
        }
      } else {
        _kept.add(url);
        _cover ??= url;
      }
    });
  }

  void _setCover(String url) {
    setState(() {
      _kept.add(url);
      _cover = url;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar imágenes'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_result()),
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Toca una imagen para quitarla o volver a incluirla. Usa la '
              'estrella para elegir la portada.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: widget.images.length,
              itemBuilder: (context, i) {
                final url = widget.images[i];
                final kept = _kept.contains(url);
                final isCover = _cover == url;
                return _EditableTile(
                  url: url,
                  kept: kept,
                  isCover: isCover,
                  onTap: () => _toggleKeep(url),
                  onSetCover: () => _setCover(url),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableTile extends StatelessWidget {
  const _EditableTile({
    required this.url,
    required this.kept,
    required this.isCover,
    required this.onTap,
    required this.onSetCover,
  });

  final String url;
  final bool kept;
  final bool isCover;
  final VoidCallback onTap;
  final VoidCallback onSetCover;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: kept ? 1 : 0.35,
              child: RemoteImage(url: url, borderRadius: BorderRadius.zero),
            ),
            // Estado "conservar" (esquina superior derecha).
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                kept ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22,
                color: kept ? scheme.primary : Colors.white70,
                shadows: const [Shadow(blurRadius: 3, color: Colors.black54)],
              ),
            ),
            // Portada / botón para hacerla portada (esquina inferior izquierda).
            Positioned(
              left: 4,
              bottom: 4,
              child: isCover
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Portada',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    )
                  : GestureDetector(
                      onTap: onSetCover,
                      child: const Icon(Icons.star_border,
                          size: 22,
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 3, color: Colors.black54)
                          ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 64, color: iconColor ?? theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
