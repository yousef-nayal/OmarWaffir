import 'package:dio/dio.dart';

enum ApiErrorType {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  server,
  unknown,
}

class ApiException implements Exception {
  final ApiErrorType type;
  final String message;
  final String? devMessage;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  const ApiException({
    required this.type,
    required this.message,
    this.devMessage,
    this.statusCode,
    this.errors,
  });

  factory ApiException.fromDio(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown) {
      return const ApiException(
        type: ApiErrorType.network,
        message: 'تعذّر الاتصال بالإنترنت. تحقق من الاتصال وحاول مجدداً.',
      );
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const ApiException(
        type: ApiErrorType.timeout,
        message: 'استغرق الطلب وقتاً طويلاً. حاول مجدداً.',
      );
    }

    final status = e.response?.statusCode;
    final data = e.response?.data;

    String? backendMessage;
    Map<String, dynamic>? validationErrors;

    if (data is Map<String, dynamic>) {
      backendMessage = data['message'] as String?;
      if (data['errors'] is Map<String, dynamic>) {
        validationErrors = data['errors'] as Map<String, dynamic>;
      }
    }

    switch (status) {
      case 401:
        return ApiException(
          type: ApiErrorType.unauthorized,
          message: 'انتهت جلستك. يرجى تسجيل الدخول مجدداً.',
          statusCode: status,
        );
      case 403:
        return ApiException(
          type: ApiErrorType.forbidden,
          message: 'لا تملك صلاحية للقيام بهذا الإجراء.',
          statusCode: status,
        );
      case 404:
        return ApiException(
          type: ApiErrorType.notFound,
          message: backendMessage ?? 'العنصر المطلوب غير موجود.',
          statusCode: status,
        );
      case 422:
        return ApiException(
          type: ApiErrorType.validation,
          message: backendMessage ?? 'يرجى التحقق من البيانات المدخلة.',
          statusCode: status,
          errors: validationErrors,
        );
      default:
        if (status != null && status >= 500) {
          return ApiException(
            type: ApiErrorType.server,
            message: 'حدث خطأ في الخادم. حاول مجدداً لاحقاً.',
            devMessage: backendMessage,
            statusCode: status,
          );
        }
        return ApiException(
          type: ApiErrorType.unknown,
          message: backendMessage ?? 'حدث خطأ غير متوقع.',
          statusCode: status,
        );
    }
  }

  @override
  String toString() => 'ApiException($type, $statusCode): $message';
}
