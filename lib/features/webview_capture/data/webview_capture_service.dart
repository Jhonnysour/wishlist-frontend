import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Carga una URL en un WebView headless (sin UI) y devuelve el HTML ya
/// renderizado por un navegador real.
///
/// Es la Capa 0: para páginas cuyo precio nunca llega a un scraper de servidor
/// (Amazon sirve una variante sin el bloque de precio), el navegador del móvil
/// sí ve el precio real. Se dispara solo cuando el scraping de servidor termina
/// en FAILED, así que el camino feliz (10/11 sitios) nunca paga este costo.
class WebViewCaptureService {
  /// Margen tras `onLoadStop` para que el JS de la página inyecte el precio
  /// antes de leer el DOM.
  static const _settle = Duration(seconds: 3);

  /// Tope duro: si la página no carga/estabiliza, no dejamos el WebView colgado.
  static const _timeout = Duration(seconds: 30);

  /// UA de Chrome real: algunos sitios sirven una variante degradada a UAs que
  /// parecen bots.
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  /// Devuelve el `outerHTML` de la página, o `null` si no se pudo capturar.
  Future<String?> capture(String url) async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? headless;
    Timer? timeoutTimer;

    Future<void> finish(String? html) async {
      if (completer.isCompleted) return;
      timeoutTimer?.cancel();
      completer.complete(html);
      await headless?.dispose();
    }

    headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(userAgent: _userAgent),
      onLoadStop: (controller, uri) async {
        await Future<void>.delayed(_settle);
        try {
          final html = await controller.evaluateJavascript(
            source: 'document.documentElement.outerHTML',
          );
          await finish(html is String ? html : html?.toString());
        } catch (_) {
          await finish(null);
        }
      },
      onReceivedError: (controller, request, error) => finish(null),
    );

    timeoutTimer = Timer(_timeout, () => finish(null));
    await headless.run();
    return completer.future;
  }
}

final webViewCaptureServiceProvider = Provider<WebViewCaptureService>(
  (ref) => WebViewCaptureService(),
);
