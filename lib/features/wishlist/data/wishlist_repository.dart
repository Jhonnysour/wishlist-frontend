import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import '../domain/item.dart';

/// CRUD de la wishlist contra los endpoints `/items`.
class WishlistRepository {
  WishlistRepository(this._dio);

  final Dio _dio;

  /// `GET /items` — lista (más nuevos primero). Filtros opcionales `q` y
  /// `purchased`; paginación con `limit` (1-100) y `offset`.
  Future<List<Item>> fetchItems({
    String? listId,
    String? q,
    bool? purchased,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/items',
        queryParameters: {
          'list_id': ?listId,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          'purchased': ?purchased,
          'limit': limit,
          'offset': offset,
        },
      );
      return (res.data ?? [])
          .map((e) => Item.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /items/{id}` — un item (para el polling del scraping).
  Future<Item> fetchItem(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/items/$id');
      return Item.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /items` — encola el scraping en una lista. Responde 202 (PENDING).
  /// Si `listId` es null, el backend lo agrega a la lista por defecto.
  Future<Item> addItem(String url, {String? listId}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/items',
        data: {'url': url, 'list_id': ?listId},
      );
      return Item.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /items/{id}` — marca/desmarca como comprado.
  Future<Item> setPurchased(String id, bool purchased) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/items/$id',
        data: {'purchased': purchased},
      );
      return Item.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /items/{id}` — cura las imágenes: *images* es un subconjunto
  /// reordenado de las actuales (la primera es la portada).
  Future<Item> updateImages(String id, List<String> images) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/items/$id',
        data: {'images': images},
      );
      return Item.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /items/{id}` — renombra el item (el backend recorta y exige no vacío).
  Future<Item> updateTitle(String id, String title) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/items/$id',
        data: {'title': title},
      );
      return Item.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /items/{id}` — fija el precio a mano, para las tiendas cuyo precio
  /// ningún scraper alcanza. `null` lo borra.
  Future<Item> updatePrice(String id, double? price) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/items/$id',
        data: {'price': price},
      );
      return Item.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `DELETE /items/{id}` — elimina el item (204).
  Future<void> deleteItem(String id) async {
    try {
      await _dio.delete<void>('/items/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final wishlistRepositoryProvider = Provider<WishlistRepository>(
  (ref) => WishlistRepository(ref.watch(dioProvider)),
);
