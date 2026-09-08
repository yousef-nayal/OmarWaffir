import 'package:waffir_app/models/models.dart';
import 'package:waffir_app/core/network/api_client.dart';

/// خدمة المصادقة — راجع API_DOCUMENTATION.md → قسم "المصادقة (Auth)"
/// لمعرفة الشكل الدقيق المطلوب لكل endpoint وكل حقل.
class AuthService {
  final ApiClient _api;

  AuthService({ApiClient? api}) : _api = api ?? ApiClient();

  /// POST /auth/login
  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'phone_number': phone, 'password': password},
    );
    final result = AuthResult.fromJson(response);
    await _api.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    return result;
  }

  // ══════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري — كانت هذه الدالة تستقبل [sector] كنص حر مدمج بصيغة
  // "الكتلة الخامسة - الفرقان" وترسله كما هو، رغم أن عمود User.location_id
  // في قاعدة البيانات الفعلي مفتاح أجنبي إلزامي يشير لصف محدد في جدول
  // Location — لا يوجد أي عمود نصي لتخزين "قطاع/كتلة" على جدول User
  // إطلاقاً. إرسال نص حر بهذا الشكل لا يملك مكاناً حقيقياً ليُخزَّن فيه.
  //
  // الآن تستقبل locationId (معرّف حقيقي، يُحسَب في RegisterScreen عبر
  // CatalogProvider.locationIdForArea) وترسله مباشرة بدل sector.
  // ══════════════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري ثانٍ — التسجيل لم يعد يُصدِر أي جلسة.
  //
  // الخادم ينشئ حساباً غير مؤكَّد ويرسل رمز التحقق فقط، بلا access/refresh
  // token إطلاقاً (راجع POST /auth/register في docs/FINAL_API_CONTRACT.md).
  // كان الكود السابق يفترض وجود الرموز في الرد ويحفظها فوراً، ما كان يعني
  // عملياً أن حساباً غير مؤكَّد يستطيع استخدام التطبيق بالكامل بمجرد إعادة
  // تشغيله. الرموز تُحفَظ الآن في [verifyOtp] فقط — بعد تأكيد رقم الهاتف.
  // ══════════════════════════════════════════════════════════════════
  Future<RegistrationResult> register({
    required String name,
    required String phone,
    required String password,
    required String locationId,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'name': name,
        'phone_number': phone,
        'password': password,
        'password_confirmation': password,
        'location_id': locationId,
      },
    );
    return RegistrationResult.fromJson(response);
  }

  /// POST /auth/admin/login — يقبل رقم هاتف أو بريد إلكتروني في حقل username
  Future<AuthResult> adminLogin({
    required String username,
    required String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/admin/login',
      data: {'username': username, 'password': password},
    );
    final result = AuthResult.fromJson(response);
    await _api.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    return result;
  }

  /// POST /auth/logout
  Future<void> logout() async {
    try {
      await _api.post<void>('/auth/logout');
    } catch (_) {
      // نتابع تسجيل الخروج محلياً حتى لو فشل الطلب (مثلاً بلا انترنت)
    } finally {
      await _api.clearTokens();
    }
  }

  /// PUT /auth/profile — الاسم و/أو موقع الحساب.
  ///
  /// ✅ [locationId] اختياري: يُرسَل فقط عند تغيير المنطقة من الإعدادات، حتى
  /// يبقى موقع الحساب على الخادم متزامناً مع الموقع المختار محلياً.
  Future<UserModel> updateProfile({
    String? name,
    String? locationId,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/auth/profile',
      data: {
        if (name != null && name.isNotEmpty) 'name': name,
        if (locationId != null && locationId.isNotEmpty)
          'location_id': locationId,
      },
    );
    return UserModel.fromJson(
        response['data'] as Map<String, dynamic>? ?? response);
  }

  /// POST /auth/forgot-password
  Future<void> forgotPassword(String phone) async {
    await _api.post<void>(
      '/auth/forgot-password',
      data: {'phone_number': phone},
    );
  }

  /// POST /auth/verify-otp — تأكيد رقم الهاتف بعد إنشاء حساب جديد.
  ///
  /// ✅ هذه هي النقطة الوحيدة التي تُصدَر فيها جلسة لحساب جديد: الخادم يعيد
  /// access/refresh token مع بيانات المستخدم، ونحفظها هنا.
  Future<AuthResult> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/verify-otp',
      data: {'phone_number': phone, 'code': code},
    );
    final result = AuthResult.fromJson(response);
    await _api.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    return result;
  }

  /// POST /auth/resend-otp — ✅ جديد — إعادة إرسال رمز التحقق
  Future<void> resendOtp({required String phone}) async {
    await _api.post<void>(
      '/auth/resend-otp',
      data: {'phone_number': phone},
    );
  }

  /// PUT /auth/reset-password — ✅ جديد — إتمام تعيين كلمة مرور جديدة
  /// بعد الحصول على رمز التحقق من /auth/forgot-password
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    await _api.put<void>(
      '/auth/reset-password',
      data: {
        'phone_number': phone,
        'code': code,
        'new_password': newPassword,
        'new_password_confirmation': newPassword,
      },
    );
  }

  /// POST /auth/change-password/request-otp — ✅ جديد — يرسل رمز تحقق إلى
  /// رقم هاتف المستخدم الحالي قبل تغيير كلمة المرور من الإعدادات.
  Future<void> requestChangePasswordOtp() async {
    await _api.post<void>('/auth/change-password/request-otp');
  }

  /// PUT /auth/change-password
  ///
  /// ✅ المسار الأساسي أصبح قائماً على رمز التحقق ([code]) كما تصف الأطروحة.
  /// [currentPassword] ما زال مقبولاً من الخادم للتوافق مع الشاشة القديمة.
  Future<void> changePassword({
    String? code,
    String? currentPassword,
    required String newPassword,
  }) async {
    await _api.put<void>(
      '/auth/change-password',
      data: {
        if (code != null && code.isNotEmpty) 'code': code,
        if (currentPassword != null && currentPassword.isNotEmpty)
          'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPassword,
      },
    );
  }

  /// GET /auth/me — جلب بيانات المستخدم الحالي (تُستخدم في السبلاش عند وجود توكن محفوظ)
  Future<UserModel> getCurrentUser() async {
    final response = await _api.get<Map<String, dynamic>>('/auth/me');
    return UserModel.fromJson(
        response['data'] as Map<String, dynamic>? ?? response);
  }

  Future<bool> hasSavedSession() => _api.hasValidSession();
}

/// ✅ جديد — نتيجة POST /auth/register: لا تحتوي أي رموز جلسة، فقط تأكيد أن
/// الحساب أُنشئ ويحتاج تفعيلاً عبر رمز التحقق.
class RegistrationResult {
  final bool requiresVerification;
  final String phone;

  const RegistrationResult({
    required this.requiresVerification,
    required this.phone,
  });

  factory RegistrationResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return RegistrationResult(
      requiresVerification: data['requires_verification'] as bool? ?? true,
      phone: data['phone_number'] as String? ?? '',
    );
  }
}

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return AuthResult(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
    );
  }
}
