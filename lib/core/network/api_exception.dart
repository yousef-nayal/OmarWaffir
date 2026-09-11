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

    // ✅ هل جاء الرد من خادمنا أصلاً؟ ردودنا دائماً JSON بحقل message.
    // أي رد آخر (HTML أو فارغ) يعني أن وسيطاً بيننا وبين الخادم ردّ
    // قبل أن يصل الطلب (نفق dev tunnel خاص، بروكسي، بوابة شبكة).
    final isApiResponse = data is Map<String, dynamic>;

    if (data is Map<String, dynamic>) {
      backendMessage = data['message'] as String?;
      if (data['errors'] is Map<String, dynamic>) {
        validationErrors = data['errors'] as Map<String, dynamic>;
      }
    }

    switch (status) {
      case 401:
        // ✅ إصلاح — كانت هذه الحالة تتجاهل رسالة الخادم دائماً وتعرض "انتهت
        // جلستك" لأي 401، بما في ذلك فشل تسجيل الدخول بكلمة مرور خاطئة —
        // فيرى المستخدم "انتهت جلستك" وهو لم يبدأ جلسة أصلاً. الخادم يرسل
        // رسالة عربية دقيقة لكل حالة (بيانات دخول خاطئة / انتهاء الجلسة)،
        // فنعرضها كما هي ونحتفظ بالنص العام كبديل عند غيابها فقط.
        // ✅ إضافة — 401 بلا جسم JSON لم يأتِ من خادمنا، فلا علاقة له بانتهاء
        // الجلسة. إظهار "انتهت جلستك" في هذه الحالة يضلّل تماماً — وقع
        // ذلك فعلاً مع نفق VS Code مضبوط على Private: النفق يردّ 401
        // قبل أن يصل طلب تسجيل الدخول إلى Laravel.
        return ApiException(
          type: ApiErrorType.unauthorized,
          message: backendMessage ??
              (isApiResponse
                  ? 'انتهت جلستك. يرجى تسجيل الدخول مجدداً.'
                  : 'تعذّر الوصول إلى الخادم: رُفض الطلب قبل وصوله. تحقق من رابط الخادم.'),
          statusCode: status,
        );
      case 403:
        // ✅ نفس الإصلاح — الخادم يميّز بين حالات 403 مختلفة تماماً:
        // "الحساب محظور"، "يجب تأكيد رقم الهاتف أولاً"، "هذا الحساب لا يملك
        // صلاحية الدخول للوحة الإدارة"، "لا يمكنك تقييم سعر أضفته بنفسك".
        // إخفاؤها جميعاً خلف نص واحد عام كان يجعل سبب الرفض غامضاً.
        return ApiException(
          type: ApiErrorType.forbidden,
          message: backendMessage ?? 'لا تملك صلاحية للقيام بهذا الإجراء.',
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
