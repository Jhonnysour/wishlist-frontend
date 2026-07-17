import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/remote_image.dart';
import '../../domain/item.dart';

/// Tarjeta de un item de la wishlist. Se adapta al `status`:
/// - PENDING: placeholder "Extrayendo…".
/// - FAILED: mensaje de error con la URL original.
/// - COMPLETED: imagen, título, precio y dominio.
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, this.onTap});

  final Item item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(item: item),
              const SizedBox(width: 12),
              Expanded(child: _Details(item: item)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    const size = 76.0;
    if (item.status == ItemStatus.pending) {
      return _Box(
        size: size,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (item.status == ItemStatus.failed) {
      return _Box(
        size: size,
        child: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }
    return RemoteImage(
      url: item.images.isNotEmpty ? item.images.first : null,
      width: size,
      height: size,
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (item.status == ItemStatus.pending) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Extrayendo…',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(item.originalUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      );
    }

    if (item.status == ItemStatus.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No se pudo extraer el producto',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: scheme.error)),
          const SizedBox(height: 4),
          Text(item.originalUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      );
    }

    // COMPLETED
    final title = item.title?.trim().isNotEmpty == true
        ? item.title!.trim()
        : 'Producto sin título';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            decoration: item.purchased ? TextDecoration.lineThrough : null,
            color: item.purchased ? scheme.onSurfaceVariant : null,
          ),
        ),
        const SizedBox(height: 4),
        if (item.price != null)
          Text(
            '\$${item.price!.toStringAsFixed(2)}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (item.domainSource != null && item.domainSource!.isNotEmpty)
              Expanded(
                child: Text(
                  item.domainSource!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            if (item.purchased) const _PurchasedChip(),
          ],
        ),
      ],
    );
  }
}

class _PurchasedChip extends StatelessWidget {
  const _PurchasedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.purchased.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 13, color: AppTheme.purchased),
          const SizedBox(width: 4),
          Text(
            'Comprado',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.purchased,
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
