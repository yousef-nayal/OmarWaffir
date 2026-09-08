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
  Future<AuthResult> register({
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
    final result = AuthResult.fromJson(response);
    await _api.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    return result;
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

  /// PUT /auth/profile
  Future<UserModel> updateProfile({required String name}) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/auth/profile',
      data: {'name': name},
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

  /// POST /auth/verify-otp — ✅ جديد — تأكيد رقم الهاتف بعد إنشاء حساب جديد
  Future<void> verifyOtp({
    required String phone,
    required String code,
  }) async {
    await _api.post<void>(
      '/auth/verify-otp',
      data: {'phone_number': phone, 'code': code},
    );
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

  /// PUT /auth/change-password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.put<void>(
      '/auth/change-password',
      data: {
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
