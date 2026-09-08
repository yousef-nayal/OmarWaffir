/// ══════════════════════════════════════════════════════════════════════════
/// API RESPONSE WRAPPER
/// ══════════════════════════════════════════════════════════════════════════
///
/// شكل الرد الموحّد المتوقع من الـ backend لكل نقاط النهاية (endpoints):
///   { "success": true, "data": {...}, "message": "...", "pagination": {...} }
///
/// راجع API_DOCUMENTATION.md في جذر المشروع لمعرفة الشكل الدقيق لكل endpoint.
/// ══════════════════════════════════════════════════════════════════════════
library;

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final PaginationMeta? pagination;

  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.pagination,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJson,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? true,
      data: json['data'] != null && fromJson != null
          ? fromJson(json['data'])
          : json['data'] as T?,
      message: json['message'] as String?,
      pagination: json['pagination'] != null
          ? PaginationMeta.fromJson(
              json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PaginationMeta {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const PaginationMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasNextPage => currentPage < lastPage;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: json['current_page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      perPage: json['per_page'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
    );
  }
}
