import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_exception.dart';

/// ══════════════════════════════════════════════════════════════════════════
/// API CLIENT
/// ══════════════════════════════════════════════════════════════════════════
///
/// لماذا Dio وليس http الافتراضي؟
///   - Interceptors: تضيف الـ token تلقائياً لكل طلب
///   - Retry / Token Refresh: تجديد الـ JWT دون تدخل المستخدم
///   - CancelToken: إلغاء الطلبات عند مغادرة الشاشة
///   - FormData: رفع الملفات بسهولة
///   - Timeout موحّد بمكان واحد
///
/// ملاحظة لمطوّر الـ backend:
///   Base URL يُمرَّر عبر --dart-define=API_BASE_URL=https://your-api.com/v1
///   راجع API_DOCUMENTATION.md لمعرفة كل الـ endpoints المطلوبة وشكل الـ JSON.
/// ══════════════════════════════════════════════════════════════════════════

class ApiClient {
  // ── Singleton ──────────────────────────────────────────────────────────
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal() {
    _init();
  }

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  // ── Constants ─────────────────────────────────────────────────────────
  // غيّر هذا عند نشر التطبيق، أو مرّره عبر --dart-define=API_BASE_URL=...
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://api.waffir.sy/v1');
  static const Duration _timeout = Duration(seconds: 30);

  String get baseUrl => _baseUrl;

  // ── Init ──────────────────────────────────────────────────────────────
  void _init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: _timeout,
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // اللغة: مهم لتلقي رسائل الخطأ بالعربية من الـ backend
          'Accept-Language': 'ar',
        },
      ),
    );

    // الترتيب مهم: AuthInterceptor يُضاف قبل LogInterceptor
    _dio.interceptors.add(_AuthInterceptor(_dio, _storage));

    // فعّل هذا فقط في بيئة التطوير
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugLog(obj.toString()),
      ));
    }
  }

  // ── Public Methods ────────────────────────────────────────────────────

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return _parse<T>(response.data, fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.post(path, data: data);
      return _parse<T>(response.data, fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put(path, data: data);
      return _parse<T>(response.data, fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<T> patch<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.patch(path, data: data);
      return _parse<T>(response.data, fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<T> delete<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(path, data: data);
      return _parse<T>(response.data, fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// رفع ملف (صورة إيصال مثلاً) — جاهز لأي endpoint يستقبل multipart/form-data
  Future<T> upload<T>(
    String path, {
    required String filePath,
    required String fieldName,
    Map<String, dynamic>? extraFields,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final formData = FormData.fromMap({
        ...?extraFields,
        fieldName: await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(path, data: formData);
      return _parse<T>(response.data, fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  T _parse<T>(dynamic data, T Function(dynamic)? fromJson) {
    if (fromJson != null) return fromJson(data);
    return data as T;
  }

  /// حفظ الـ tokens بعد تسجيل الدخول
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: 'access_token', value: accessToken),
      _storage.write(key: 'refresh_token', value: refreshToken),
    ]);
  }

  /// حذف الـ tokens عند تسجيل الخروج
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: 'access_token'),
      _storage.delete(key: 'refresh_token'),
    ]);
  }

  /// هل يوجد مستخدم مسجّل دخول (توكن محفوظ)؟ — يستخدمها SplashScreen
  Future<bool> hasValidSession() async {
    final token = await _storage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }
}

// ══════════════════════════════════════════════════════════════════════════
// AUTH INTERCEPTOR
// ══════════════════════════════════════════════════════════════════════════
//
// لماذا Interceptor وليس إضافة الـ token يدوياً في كل طلب؟
//   لأن لكل طلب في كل service ستضطر لكتابة نفس السطر.
//   الـ Interceptor يفعل ذلك مرة واحدة للجميع،
//   ويتولى أيضاً تجديد الـ token تلقائياً.
// ══════════════════════════════════════════════════════════════════════════

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  bool _isRefreshing = false;

  // قائمة انتظار الطلبات التي فشلت بسبب انتهاء الـ token
  final List<_PendingRequest> _pendingRequests = [];

  _AuthInterceptor(this._dio, this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // إذا كان الخطأ 401 (Unauthorized) وليس طلب تجديد الـ token نفسه
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/refresh')) {
      if (_isRefreshing) {
        // أضف الطلب إلى قائمة الانتظار
        _pendingRequests.add(_PendingRequest(err.requestOptions, handler));
        return;
      }
      await _handleTokenRefresh(err, handler);
      return;
    }
    handler.next(err);
  }

  Future<void> _handleTokenRefresh(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    _isRefreshing = true;
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) {
        _rejectAll();
        handler.next(err);
        return;
      }

      // طلب تجديد الـ token
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Authorization': null}),
      );

      final newAccessToken = response.data['access_token'] as String;
      final newRefreshToken = response.data['refresh_token'] as String?;

      await _storage.write(key: 'access_token', value: newAccessToken);
      if (newRefreshToken != null) {
        await _storage.write(key: 'refresh_token', value: newRefreshToken);
      }

      // أعد تنفيذ الطلب الأصلي بالـ token الجديد
      err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      final retryResponse = await _dio.fetch(err.requestOptions);
      handler.resolve(retryResponse);

      // أعد تنفيذ الطلبات المعلّقة
      _resolveAll(newAccessToken);
    } catch (_) {
      // فشل تجديد الـ token: اطرد المستخدم
      await _storage.deleteAll();
      _rejectAll();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  void _resolveAll(String token) {
    for (final req in _pendingRequests) {
      req.options.headers['Authorization'] = 'Bearer $token';
      _dio.fetch(req.options).then(req.handler.resolve).catchError(
        (Object error, StackTrace stackTrace) {
          if (error is DioException) {
            req.handler.reject(error);
          } else {
            req.handler.reject(
                DioException(requestOptions: req.options, error: error));
          }
        },
      );
    }
    _pendingRequests.clear();
  }

  void _rejectAll() {
    for (final req in _pendingRequests) {
      req.handler.next(DioException(requestOptions: req.options));
    }
    _pendingRequests.clear();
  }
}

class _PendingRequest {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
  _PendingRequest(this.options, this.handler);
}

void debugLog(String msg) {
  // ignore: avoid_print
  if (kDebugMode) print('[ApiClient] $msg');
}
