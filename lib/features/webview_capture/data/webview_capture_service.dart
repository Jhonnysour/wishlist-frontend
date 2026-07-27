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

    Future<String?> readDom(InAppWebViewController? controller) async {
      if (controller == null) return null;
      try {
        final html = await controller.evaluateJavascript(
          source: 'document.documentElement.outerHTML',
        );
        return html is String ? html : html?.toString();
      } catch (_) {
        return null;
      }
    }

    headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(userAgent: _userAgent),
      onLoadStop: (controller, uri) async {
        await Future<void>.delayed(_settle);
        await finish(await readDom(controller));
      },
      // Android's WebViewClient calls onReceivedError for *any* failed
      // resource — an ad, a tracker, an image — not just the page itself.
      // Aborting on all of them discarded pages that had rendered perfectly
      // well: MercadoLibre never got captured at all because something in its
      // ad/tracking soup always fails. Only a main-frame error means there is
      // no page to read.
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame ?? false) finish(null);
      },
    );

    // On timeout, read whatever is in the DOM instead of giving up: pages that
    // keep polling in the background never reach onLoadStop, yet their markup
    // has been complete for a while.
    timeoutTimer = Timer(
      _timeout,
      () async => finish(await readDom(headless?.webViewController)),
    );
    await headless.run();
    return completer.future;
  }
}

final webViewCaptureServiceProvider = Provider<WebViewCaptureService>(
  (ref) => WebViewCaptureService(),
);
