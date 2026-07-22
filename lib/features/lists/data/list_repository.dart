import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import '../domain/product_list.dart';

/// CRUD de listas contra los endpoints `/lists`.
class ListRepository {
  ListRepository(this._dio);

  final Dio _dio;

  Future<List<ProductList>> fetchLists() async {
    try {
      final res = await _dio.get<List<dynamic>>('/lists');
      return (res.data ?? [])
          .map((e) => ProductList.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ProductList> createList(String name) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/lists',
        data: {'name': name},
      );
      return ProductList.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ProductList> renameList(String id, String name) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/lists/$id',
        data: {'name': name},
      );
      return ProductList.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> deleteList(String id) async {
    try {
      await _dio.delete<void>('/lists/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final listRepositoryProvider = Provider<ListRepository>(
  (ref) => ListRepository(ref.watch(dioProvider)),
);
