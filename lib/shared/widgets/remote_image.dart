import 'package:flutter/material.dart';

/// Imagen remota con manejo de fallos.
///
/// Las imágenes de producto son URLs de terceros; algunas tiendas bloquean el
/// hotlinking y responden **403**, por eso siempre se usa un `errorBuilder`
/// con un placeholder. También muestra un indicador mientras carga.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);
    Widget child;

    if (url == null || url!.isEmpty) {
      child = _Placeholder(width: width, height: height);
    } else {
      child = Image.network(
        url!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            _Placeholder(width: width, height: height),
        loadingBuilder: (context, widget, progress) {
          if (progress == null) return widget;
          return _Placeholder(
            width: width,
            height: height,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }

    return ClipRRect(borderRadius: radius, child: child);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.width, this.height, this.child});

  final double? width;
  final double? height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: scheme.surfaceContainerHighest,
      child: child ??
          Icon(
            Icons.image_not_supported_outlined,
            color: scheme.onSurfaceVariant,
            size: 28,
          ),
    );
  }
}
