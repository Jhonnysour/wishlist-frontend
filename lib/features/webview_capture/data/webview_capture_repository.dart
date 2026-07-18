import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import '../../wishlist/domain/item.dart';

/// Envía al backend el HTML capturado por el WebView (Capa 0).
class WebViewCaptureRepository {
  WebViewCaptureRepository(this._dio);

  final Dio _dio;

  /// `POST /items/{id}/retry-from-html` — reextrae el item desde el HTML ya
  /// renderizado. La extracción es síncrona en el servidor, así que devuelve
  /// el item actualizado (COMPLETED con precio, o FAILED si tampoco alcanzó).
  Future<Item> retryFromHtml(String id, String html) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/items/$id/retry-from-html',
        data: {'html': html},
      );
      return Item.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final webViewCaptureRepositoryProvider = Provider<WebViewCaptureRepository>(
  (ref) => WebViewCaptureRepository(ref.watch(dioProvider)),
);
