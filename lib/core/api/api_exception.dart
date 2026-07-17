import 'package:dio/dio.dart';

/// Normalized error surfaced to the UI/repositories, so callers don't have to
/// reason about raw [DioException]s.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isValidation => statusCode == 422;

  /// Maps a [DioException] into a user-friendly [ApiException].
  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException('The server took too long to respond.');
      case DioExceptionType.connectionError:
        return const ApiException(
          'Could not reach the server. Check the connection and base URL.',
        );
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        return ApiException(
          _messageForStatus(status, e.response?.data),
          statusCode: status,
        );
      case DioExceptionType.cancel:
        return const ApiException('Request cancelled.');
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return ApiException(e.message ?? 'Unexpected network error.');
    }
  }

  static String _messageForStatus(int? status, Object? data) {
    // FastAPI errors usually look like {"detail": "..."} or a validation list.
    final detail = data is Map ? data['detail'] : null;
    switch (status) {
      case 400:
        return detail?.toString() ?? 'Invalid request.';
      case 401:
        return 'Session expired. Please sign in again.';
      case 404:
        return 'Not found.';
      case 422:
        return detail is String ? detail : 'The data provided is invalid.';
      default:
        return detail?.toString() ?? 'Request failed (${status ?? 'no status'}).';
    }
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
