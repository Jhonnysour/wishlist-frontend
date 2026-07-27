import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resultado de una captura: el HTML, o el motivo por el que no lo hubo.
///
/// El motivo existe porque cuando la Capa 0 falla en el móvil no queda ningún
/// rastro: el item aparece como "no se pudo extraer" y desde el PC no hay forma
/// de saber si el WebView no cargó, si lo redirigieron o si la página vino
/// vacía. Cada hipótesis costaba un APK nuevo, así que la captura ahora explica
/// su propio fracaso.
class CaptureResult {
  const CaptureResult({this.html, this.diagnostic, this.finalUrl});

  final String? html;

  /// Por qué no hay HTML, en una línea legible. Null si la captura salió bien.
  final String? diagnostic;

  /// Dónde acabó el WebView: distingue "nos sirvieron el muro" de "nos
  /// mandaron al login o a otra página".
  final String? finalUrl;

  bool get ok => html != null && html!.isNotEmpty;
}

/// Carga una URL en un WebView headless (sin UI) y devuelve el HTML ya
/// renderizado por un navegador real.
///
/// Es la Capa 0: para páginas cuyo precio nunca llega a un scraper de servidor
/// (Amazon sirve una variante sin el bloque de precio), el navegador del móvil
/// sí ve el precio real. Se dispara cuando el scraping de servidor termina en
/// FAILED o se queda sin precio, así que el camino feliz nunca paga este costo.
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

  /// Captura la página y, si no puede, explica por qué.
  Future<CaptureResult> capture(String url) async {
    final completer = Completer<CaptureResult>();
    HeadlessInAppWebView? headless;
    Timer? timeoutTimer;
    String? lastUrl = url;
    String? blockedScheme;

    Future<void> finish(CaptureResult result) async {
      if (completer.isCompleted) return;
      timeoutTimer?.cancel();
      completer.complete(result);
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

    /// Lee el DOM y cierra: con HTML si lo hay, con el motivo si no.
    Future<void> finishWithDom(
      InAppWebViewController? controller,
      String reasonIfEmpty,
    ) async {
      final html = await readDom(controller);
      await finish(
        (html != null && html.isNotEmpty)
            ? CaptureResult(html: html, finalUrl: lastUrl)
            : CaptureResult(
                diagnostic: blockedScheme == null
                    ? reasonIfEmpty
                    : '$reasonIfEmpty (se bloqueó $blockedScheme)',
                finalUrl: lastUrl,
              ),
      );
    }

    headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        userAgent: _userAgent,
        useShouldOverrideUrlLoading: true,
      ),
      // Las tiendas grandes empujan al visitante móvil hacia su app nativa. El
      // WebView no sabe abrir esos esquemas, así que la navegación muere con un
      // error de marco principal y perdíamos la página web que ya estaba ahí.
      // Cancelarlas deja la web en pie para poder leerla.
      shouldOverrideUrlLoading: (controller, action) async {
        final scheme = action.request.url?.scheme.toLowerCase();
        if (scheme == null || scheme == 'http' || scheme == 'https') {
          return NavigationActionPolicy.ALLOW;
        }
        blockedScheme = '$scheme://';
        return NavigationActionPolicy.CANCEL;
      },
      onLoadStop: (controller, uri) async {
        lastUrl = uri?.toString() ?? lastUrl;
        await Future<void>.delayed(_settle);
        await finishWithDom(controller, 'la página cargó pero el DOM vino vacío');
      },
      // Android's WebViewClient calls onReceivedError for *any* failed
      // resource — an ad, a tracker, an image — not just the page itself.
      // Aborting on all of them discarded pages that had rendered perfectly
      // well: MercadoLibre never got captured at all because something in its
      // ad/tracking soup always fails. Only a main-frame error means there is
      // no page to read — and even then, read the DOM first: the failure may
      // be a redirect we cancelled, with the real page still loaded.
      onReceivedError: (controller, request, error) async {
        if (!(request.isForMainFrame ?? false)) return;
        lastUrl = request.url.toString();
        await finishWithDom(
          controller,
          'error de página: ${error.type} ${error.description}',
        );
      },
    );

    // On timeout, read whatever is in the DOM instead of giving up: pages that
    // keep polling in the background never reach onLoadStop, yet their markup
    // has been complete for a while.
    timeoutTimer = Timer(_timeout, () async {
      await finishWithDom(
        headless?.webViewController,
        'timeout de ${_timeout.inSeconds}s sin DOM legible',
      );
    });
    await headless.run();
    return completer.future;
  }
}

final webViewCaptureServiceProvider = Provider<WebViewCaptureService>(
  (ref) => WebViewCaptureService(),
);
