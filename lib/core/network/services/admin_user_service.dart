import '../../../models/models.dart';
import '../api_client.dart';
import '../api_response.dart';

/// خدمة إدارة المستخدمين — راجع API_DOCUMENTATION.md → "إدارة المستخدمين"
class AdminUserService {
  final ApiClient _api;
  AdminUserService({ApiClient? api}) : _api = api ?? ApiClient();

  /// GET /admin/users?search=&status=&page=&per_page=
  Future<ApiResponse<List<UserModel>>> getUsers({
    String? search,
    String? status, // active | blocked
    int page = 1,
    int perPage = 20,
  }) {
    return _api.get<ApiResponse<List<UserModel>>>(
      '/admin/users',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null) 'status': status,
        'page': page,
        'per_page': perPage,
      },
      fromJson: (json) => ApiResponse.fromJson(
        json as Map<String, dynamic>,
        (data) => (data as List).map((e) => UserModel.fromJson(e)).toList(),
      ),
    );
  }

  /// PATCH /admin/users/{id}/block أو /unblock
  Future<void> setUserBlocked(String id, {required bool blocked}) {
    final action = blocked ? 'block' : 'unblock';
    return _api.patch<void>('/admin/users/$id/$action');
  }

  /// PATCH /admin/users/{id}/role — ترقية/تخفيض صلاحية مستخدم
  ///
  /// ✅ محدَّث — بعد فحص Waffir_Database.txt: عمود User.role هو tinyint
  /// بقيمة افتراضية 0 (راجع التوضيح الكامل في models.dart._parseRole).
  /// نُرسل الآن القيمة الرقمية الفعلية مباشرة (عبر UserModel.roleToInt)
  /// بدل النص 'admin'/'user'، لتفادي أي افتراض غير مؤكد بأن طبقة الـ API
  /// تترجم النص داخلياً.
  Future<void> setUserRole(String id, String role) {
    return _api.patch<void>('/admin/users/$id/role',
        data: {'role': UserModel.roleToInt(role)});
  }

  /// POST /admin/users — ✅ جديد — إضافة مستخدم جديد مباشرة من لوحة الإدارة
  /// (بدل مسار التسجيل الذاتي عبر OTP)، مطابقةً لعنصر "إضافة" ضمن الأفعال
  /// الموحّدة في مخطط حالات الاستخدام لـ"إدارة المستخدمين". role يُرسَل
  /// كرقم مباشر (0 = مستخدم عادي افتراضياً) مطابقةً لعمود User.role tinyint.
  Future<UserModel> createUser({
    required String name,
    required String phone,
    required String password,
    required String locationId,
    String role = 'user',
  }) {
    return _api.post<UserModel>(
      '/admin/users',
      data: {
        'name': name,
        'phone_number': phone,
        'password': password,
        'location_id': locationId,
        'role': UserModel.roleToInt(role),
      },
      fromJson: (json) =>
          UserModel.fromJson((json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  /// DELETE /admin/users/{id} — ✅ جديد — حذف مستخدم نهائياً (استخدام إداري)
  /// مطابقةً لعنصر "حذف" ضمن الأفعال الخمسة الموحّدة (عرض/إضافة/تعديل/
  /// بحث/حذف) التي يُدرجها مخطط حالات الاستخدام لكل شاشة إدارية، بما فيها
  /// "إدارة المستخدمين".
  Future<void> deleteUser(String id) {
    return _api.delete<void>('/admin/users/$id');
  }

  /// PUT /admin/users/{id} — ✅ محدَّث (نسخة مدمجة) — تعديل بيانات مستخدم
  /// (الاسم، رقم الهاتف، الموقع، وكلمة المرور)، جامعةً بين تعديلين
  /// متوازيين طُبِّقا على هذا الملف في نفس الجلسة:
  ///
  /// 1. إضافة الوسيط الاختياري [phone] — يسمح لنافذة "تعديل معلومات
  ///    المسؤول" (AdminAdminsScreen في admin_shell.dart) بتعديل رقم هاتف
  ///    المسؤول من نفس النافذة، بدل الاقتصار على الاسم فقط. يُرسَل تحت
  ///    مفتاح phone_number لمطابقة نفس التسمية المستخدمة في createUser
  ///    أعلاه.
  /// 2. إبقاء الوسيط الاختياري [password] — يتيح تغيير كلمة المرور مباشرة
  ///    من نفس نافذة التعديل دون المرور بدورة "نسيت كلمة المرور" الكاملة.
  ///
  /// [phone] و[password] و[locationId] اختياريون تماماً: لا يُرسَل أيٌّ
  /// منهم للخادم إلا إذا زوّده المستدعي فعلياً بقيمة غير فارغة، فلا يتأثر
  /// أي استدعاء سابق لهذه الدالة كان يمرّر الاسم فقط.
  Future<UserModel> updateUser(
    String id, {
    required String name,
    String? phone,
    String? password,
    String? locationId,
  }) {
    return _api.put<UserModel>(
      '/admin/users/$id',
      data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone_number': phone,
        if (password != null && password.isNotEmpty) 'password': password,
        if (locationId != null && locationId.isNotEmpty)
          'location_id': locationId,
      },
      fromJson: (json) =>
          UserModel.fromJson((json as Map<String, dynamic>)['data'] ?? json),
    );
  }
}