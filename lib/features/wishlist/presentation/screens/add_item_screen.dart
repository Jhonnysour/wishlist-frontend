import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../providers/wishlist_providers.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  String? _validateUrl(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Pega la URL del producto';
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.host.contains('.')) {
      return 'Ingresa una URL válida (http/https)';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'La URL debe empezar con http o https';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await ref
          .read(wishlistControllerProvider.notifier)
          .addByUrl(_urlCtrl.text.trim());
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Extrayendo el producto…')),
          );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocurrió un error inesperado.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _urlCtrl.text = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar producto')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pega el enlace de un producto de cualquier tienda. Lo '
                  'extraemos en segundo plano y aparecerá en tu lista.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _urlCtrl,
                  keyboardType: TextInputType.url,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'URL del producto',
                    hintText: 'https://…',
                    prefixIcon: const Icon(Icons.link),
                    suffixIcon: IconButton(
                      tooltip: 'Pegar',
                      icon: const Icon(Icons.content_paste),
                      onPressed: _pasteFromClipboard,
                    ),
                  ),
                  validator: _validateUrl,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Agregar a la lista'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
