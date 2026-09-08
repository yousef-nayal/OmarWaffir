import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffir_app/models/models.dart';
import 'package:waffir_app/features/auth/data/auth_service.dart';
import 'package:waffir_app/core/network/api_exception.dart';
import 'package:waffir_app/core/network/services/product_service.dart';
import 'package:waffir_app/core/network/services/store_service.dart';
import 'package:waffir_app/core/network/services/price_service.dart';
import 'package:waffir_app/core/network/services/report_service.dart';
import 'package:waffir_app/core/network/services/catalog_service.dart';
import 'package:waffir_app/core/network/services/admin_user_service.dart';
import 'package:waffir_app/core/config/app_config.dart';
import 'package:waffir_app/core/constants/aleppo_blocks.dart';
import 'mock_data.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AppProvider extends ChangeNotifier {
  final AuthService _authService;

  AppProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _loadPreferences(); // ✅ تحميل التفضيلات عند البدء
  }

  // ── State ──────────────────────────────────────────────────────────────
  AuthStatus _authStatus = AuthStatus.initial;
  bool _isDarkMode = false;
  bool _isAdmin = false;
  // ✅ الموقع أصبح مكوّناً من قسمين منفصلين وصريحين: الكتلة الإدارية
  // (userBlock — إحدى الكتل الخمس الرسمية لمحافظة حلب) والمنطقة/الحي
  // (userLocation — يجب أن يكون ضمن أحياء الكتلة المختارة، راجع
  // aleppo_blocks.dart). سابقاً كان userLocation نصاً حراً بصيغة
  // "حلب - المنطقة" بلا أي ربط رسمي بالكتلة.
  String _userBlock = AleppoBlocks.all.first.name; // "الكتلة الأولى"
  String _userLocation = AleppoBlocks.all.first.areas.first; // "ألمجي"
  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — المعرّف الحقيقي (locations.id) للموقع المختار حالياً. الكتلة
  // والحي أعلاه يبقيان للعرض فقط؛ هذا المعرّف هو ما يُرسَل للخادم في كل
  // استعلام حسّاس للموقع (GET /products?location_id=...). يُحفَظ في
  // SharedPreferences تحت المفتاح selected_location_id فيصمد بعد إغلاق
  // التطبيق، ويُملأ أول مرة من CatalogProvider.locationIdForArea أو من
  // users.location_id القادم من /auth/me.
  // ══════════════════════════════════════════════════════════════════════
  String? _selectedLocationId;
  String _userName = '';
  String _userPhone = '';
  String _userId = '';
  String? _errorMessage;
  // ✅ جديد — نحتفظ بالمستخدم الكامل (يشمل pricesCount/ratingsCount/
  // reportsCount) بدل الاكتفاء بالاسم والهاتف فقط. هذا ما يحتاجه
  // ProfileScreen بدل الاعتماد على MockData.users.first كما كان سابقاً.
  UserModel? _currentUser;

  // ── Getters ──────────────────────────────────────────────────────────
  AuthStatus get authStatus => _authStatus;
  bool get isDarkMode => _isDarkMode;
  bool get isAdmin => _isAdmin;
  bool get isLoggedIn => _authStatus == AuthStatus.authenticated;
  bool get isLoading => _authStatus == AuthStatus.loading;

  /// اسم الكتلة الإدارية الحالية للمستخدم (مثال: "الكتلة الخامسة")
  String get userBlock => _userBlock;

  /// اسم المنطقة/الحي الحالي للمستخدم (مثال: "الفرقان")
  String get userLocation => _userLocation;

  /// ✅ معرّف الموقع المختار الذي تُرسَل به الاستعلامات الحسّاسة للموقع.
  String? get selectedLocationId => _selectedLocationId;

  /// نص عرض جاهز يجمع الكتلة والمنطقة معاً: "الكتلة الخامسة — الفرقان"
  String get userLocationDisplay =>
      AleppoBlocks.displayLabel(block: _userBlock, area: _userLocation);
  String get userName => _userName;
  String get userPhone => _userPhone;
  String get userId => _userId;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;

  // ══════════════════════════════════════════════════════════════════════
  // PREFERENCES PERSISTENCE
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('dark_mode') ?? false;
    _userBlock = prefs.getString('user_block') ?? AleppoBlocks.all.first.name;
    _userLocation =
        prefs.getString('user_area') ?? AleppoBlocks.all.first.areas.first;
    _selectedLocationId = prefs.getString('selected_location_id');
    notifyListeners();
  }

  /// يُستدعى من SplashScreen للتحقق من وجود جلسة محفوظة (auto-login)
  Future<void> restoreSession() async {
    if (AppConfig.useMockData) return; // لا شيء لاستعادته في وضع العرض التجريبي
    final hasSession = await _authService.hasSavedSession();
    if (!hasSession) return;
    _setLoading();
    try {
      final user = await _authService.getCurrentUser();
      // ✅ الصلاحية تُقرأ من roleLevel الرقمي القادم من الخادم مباشرة، لا من
      // أي افتراض محلي: 1 = مسؤول، 2 = مسؤول رئيسي.
      _setUser(user, isAdmin: user.roleLevel >= 1);
    } catch (_) {
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // AUTH ACTIONS — النسخة الحقيقية (تُستخدم عندما AppConfig.useMockData = false)
  // ══════════════════════════════════════════════════════════════════════

  /// نقطة الدخول الوحيدة التي تستدعيها شاشات تسجيل الدخول.
  /// تتحول تلقائياً بين البيانات الوهمية والـ backend الحقيقي حسب
  /// [AppConfig.useMockData] — لا حاجة لتعديل أي شاشة عند ربط الـ backend.
  Future<bool> login({required String phone, required String password}) async {
    if (AppConfig.useMockData) {
      return loginMock(phone: phone);
    }
    _setLoading();
    try {
      final result = await _authService.login(phone: phone, password: password);
      _setUser(result.user, isAdmin: false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري — كانت هذه الدالة تبني نصاً حراً "الكتلة الخامسة -
  // الفرقان" وترسله للخادم عبر AuthService.register(sector: ...)، رغم أن
  // عمود User.location_id في قاعدة البيانات الفعلي مفتاح أجنبي إلزامي
  // يشير لصف محدد في جدول Location — لا يوجد أي عمود نصي لتخزين "قطاع"
  // على جدول User إطلاقاً.
  //
  // أُضيف الوسيط الاختياري [locationId]: يُحسَب في RegisterScreen قبل
  // استدعاء هذه الدالة عبر CatalogProvider.locationIdForArea(area)، الذي
  // يطابق اسم الحي المُختار مع قائمة المواقع الفعلية المُحمَّلة من الخادم.
  // في وضع العرض التجريبي لا حاجة له إطلاقاً (يُتجاهَل).
  // ══════════════════════════════════════════════════════════════════════
  Future<bool> register({
    required String name,
    required String phone,
    required String password,
    required String block,
    required String area,
    String? locationId,
  }) async {
    _userBlock = block;
    _userLocation = area;
    if (AppConfig.useMockData) {
      return loginMock(name: name, phone: phone);
    }
    if (locationId == null || locationId.isEmpty) {
      _setError('تعذّر تحديد الموقع، حاول اختيار المنطقة مجدداً');
      return false;
    }
    _setLoading();
    try {
      final result = await _authService.register(
        name: name,
        phone: phone,
        password: password,
        locationId: locationId,
      );
      // ✅ إصلاح جوهري — التسجيل لم يعد يُنشئ جلسة إطلاقاً: الخادم ينشئ حساباً
      // غير مؤكَّد ويرسل رمز التحقق فقط، بلا أي token. الحالة تبقى
      // unauthenticated حتى ينجح verifyOtp، فلا يمكن تخطي التفعيل بإعادة
      // تشغيل التطبيق. نحتفظ فقط بالرقم والموقع المختار لشاشة OTP.
      _userPhone = result.phone.isNotEmpty ? result.phone : phone;
      _userName = name;
      _selectedLocationId = locationId;
      _authStatus = AuthStatus.unauthenticated;
      await _persistLocation();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> adminLogin({
    required String username,
    required String password,
  }) async {
    if (AppConfig.useMockData) {
      return loginMock(isAdmin: true, phone: username);
    }
    _setLoading();
    try {
      final result =
          await _authService.adminLogin(username: username, password: password);
      // ✅ الخادم هو من يقرر الصلاحية: نقرأ roleLevel من الرد بدل افتراض
      // isAdmin=true لمجرد أن الطلب جاء من شاشة الإدارة.
      _setUser(result.user, isAdmin: result.user.roleLevel >= 1);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> forgotPassword(String phone) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 600));
      return true;
    }
    try {
      await _authService.forgotPassword(phone);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ دورة تفعيل الحساب (OTP) واستعادة كلمة المرور
  // (الـ 3 endpoints أدناه موثّقة الآن في docs/API_ADDENDUM.md)
  // ══════════════════════════════════════════════════════════════════════

  /// POST /auth/verify-otp — تأكيد رقم الهاتف بعد إنشاء حساب جديد
  Future<bool> verifyOtp({required String phone, required String code}) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (code.length == 6) {
        _authStatus = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      return false;
    }
    try {
      // ✅ الخادم يعيد هنا access/refresh token وبيانات المستخدم؛ AuthService
      // يحفظ الرموز، ونحن نضبط الجلسة الكاملة. هذه أول لحظة يصبح فيها الحساب
      // الجديد مُصادَقاً عليه فعلياً.
      final result = await _authService.verifyOtp(phone: phone, code: code);
      _setUser(result.user, isAdmin: result.user.roleLevel >= 1);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// POST /auth/resend-otp — إعادة إرسال رمز التحقق (تفعيل أو استعادة كلمة مرور)
  Future<bool> resendOtp({required String phone}) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }
    try {
      await _authService.resendOtp(phone: phone);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// PUT /auth/reset-password — إتمام تعيين كلمة مرور جديدة بعد رمز التحقق
  Future<bool> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 700));
      return true;
    }
    try {
      await _authService.resetPassword(
        phone: phone,
        code: code,
        newPassword: newPassword,
      );
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  // ✅ إصلاح جوهري: كانت هذه الدالة الوحيدة (مع changePassword أدناه) التي
  // تتجاهل AppConfig.useMockData وتستدعي _authService.updateProfile مباشرة
  // — أي طلب شبكة حقيقي دائماً، حتى في وضع العرض التجريبي. بما أنه لا يوجد
  // backend حقيقي متصل بعد، كان الطلب يفشل فوراً (ApiException من نوع
  // network/timeout)، وهذا هو السبب المباشر لظهور "تعذّر التحديث، حاول
  // مجدداً" عند تعديل الاسم من شاشة "الملف الشخصي". الآن تتبع نفس نمط بقية
  // دوال AppProvider (login, register, forgotPassword...): في وضع العرض
  // التجريبي تُحدَّث الحالة محلياً فوراً بلا أي اتصال شبكة.
  Future<bool> updateProfile({String? name, String? locationId}) async {
    final newName = name ?? _userName;
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      _userName = newName;
      if (_currentUser != null)
        _currentUser = _currentUser!.copyWith(name: newName);
      notifyListeners();
      return true;
    }
    try {
      final updated = await _authService.updateProfile(
        name: name,
        locationId: locationId,
      );
      _userName = updated.name;
      _currentUser = updated;
      if (updated.locationId != null) {
        _selectedLocationId = updated.locationId;
        await _persistLocation();
      }
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  // ✅ نفس الإصلاح أعلاه: كانت تتجاهل AppConfig.useMockData أيضاً.
  /// ✅ المسار الأساسي أصبح قائماً على رمز التحقق (OTP) كما تصف الأطروحة؛
  /// [currentPassword] يبقى مدعوماً للتوافق مع الشاشة القديمة.
  Future<bool> changePassword({
    String? code,
    String? currentPassword,
    required String newPassword,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }
    try {
      await _authService.changePassword(
        code: code,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// POST /auth/change-password/request-otp — ✅ جديد
  Future<bool> requestChangePasswordOtp() async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      return true;
    }
    try {
      await _authService.requestChangePasswordOtp();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // MOCK LOGIN — تعمل فقط عندما AppConfig.useMockData = true
  // احذف استخدامها من شاشات auth_screens.dart عند تفعيل الـ backend الحقيقي
  // (استبدلها بـ provider.login / provider.register / provider.adminLogin)
  // ══════════════════════════════════════════════════════════════════════

  Future<bool> loginMock({
    bool isAdmin = false,
    String name = 'محمد أحمد',
    String phone = '0944123456',
  }) async {
    _setLoading();
    await Future.delayed(const Duration(milliseconds: 500));
    final mockUser = UserModel(
      id: isAdmin ? 'admin-1' : 'user-1',
      name: isAdmin ? 'مدير النظام' : name,
      phone: phone,
      role: isAdmin ? 'admin' : 'user',
      // ✅ محدَّث — مستوى الصلاحية الرقمي الفعلي (1 = مسؤول، 2 = مسؤول
      // رئيسي). حساب العرض التجريبي الوحيد للمسؤولين يُمثَّل الآن كـ"مسؤول
      // رئيسي" (2) بدل "مسؤول عادي" (1): بما أن وضع العرض التجريبي لا يملك
      // مفهوم "عدة مستويات إدارية" أصلاً (حساب واحد فقط)، ومنذ إضافة حارس
      // الصلاحية على شاشة "إدارة المسؤولين" (المتاحة حصراً لمستوى 2)، كان
      // إبقاء هذه القيمة على 1 سيمنع أي مستخدم في وضع العرض التجريبي من
      // الوصول إليها إطلاقاً — فلا وجود لأي حساب تجريبي آخر بمستوى أعلى
      // ليُستخدَم بدلاً منه. في الوضع الحقيقي (useMockData = false) يأتي
      // roleLevel من الخادم مباشرة كما هو (راجع UserModel.fromJson)، فلا
      // تأثير لهذا التغيير على أي بيانات فعلية.
      roleLevel: isAdmin ? 2 : 0,
      location: userLocationDisplay,
      pricesCount: isAdmin ? 0 : 45,
      ratingsCount: isAdmin ? 0 : 56,
      reportsCount: isAdmin ? 0 : 3,
      // ✅ جديد — تاريخ إنشاء الحساب (يطابق عمود User.created_at الفعلي).
      // في وضع العرض التجريبي لا يوجد تاريخ تسجيل حقيقي محفوظ، فيُستخدَم
      // الوقت الحالي كأقرب قيمة منطقية بدل تركه فارغاً بلا أي عرض.
      createdAt: DateTime.now(),
    );
    _setUser(mockUser, isAdmin: isAdmin);
    return true;
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (_) {}
    _userName = '';
    _userPhone = '';
    _userId = '';
    _isAdmin = false;
    _currentUser = null;
    _authStatus = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Preferences ──────────────────────────────────────────────────────

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    // ✅ حفظ دائم
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
  }

  /// ✅ محدَّث — يستقبل الكتلة والمنطقة معاً. تُستخدم من: منتقي الموقع في
  /// الصفحة الرئيسية (showLocationPickerSheet)، وشاشة "تغيير الموقع" في
  /// الإعدادات. لا يزال بالإمكان تمرير [area] فقط عند التأكد أنها تنتمي إلى
  /// [block] الحالية (مثال نادر)، لكن الاستخدام الطبيعي دائماً يمرّر الاثنين.
  ///
  /// ✅ [locationId] هو المعرّف الحقيقي للحي المختار (يُحسَب في الشاشة عبر
  /// CatalogProvider.locationIdForArea). عند تمريره يُحفَظ محلياً ويُرسَل
  /// للخادم عبر PUT /auth/profile حتى يبقى موقع الحساب متزامناً مع الاختيار
  /// المحلي. الشاشات التي لم تُمرّره بعد تبقى تعمل كما هي تماماً.
  Future<void> updateLocation({
    required String block,
    required String area,
    String? locationId,
  }) async {
    _userBlock = block;
    _userLocation = area;
    if (locationId != null && locationId.isNotEmpty) {
      _selectedLocationId = locationId;
    }
    notifyListeners();
    await _persistLocation();

    // مزامنة صامتة مع الخادم: فشلها لا يجب أن يمنع تغيير الموقع محلياً.
    if (!AppConfig.useMockData &&
        isLoggedIn &&
        locationId != null &&
        locationId.isNotEmpty) {
      try {
        await _authService.updateProfile(locationId: locationId);
      } on ApiException {
        // نتجاهله عمداً — الاختيار المحلي هو ما يقود واجهة المستخدم.
      }
    }
  }

  Future<void> _persistLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_block', _userBlock);
    await prefs.setString('user_area', _userLocation);
    if (_selectedLocationId != null) {
      await prefs.setString('selected_location_id', _selectedLocationId!);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Private Helpers ───────────────────────────────────────────────────

  void _setLoading() {
    _authStatus = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setUser(UserModel user, {required bool isAdmin}) {
    _userName = user.name;
    _userPhone = user.phone;
    _userId = user.id;
    // ✅ نحاول استخراج الكتلة والمنطقة من location القادم من الخادم بصيغة
    // "الكتلة الخامسة - الفرقان"؛ إن تعذّر ذلك (مستخدم قديم مثلاً) نُبقي على
    // آخر كتلة/منطقة محفوظة محلياً بدل استبدالها بقيمة فارغة.
    if (user.location.isNotEmpty && user.location.contains(' - ')) {
      final parts = user.location.split(' - ');
      if (parts.length >= 2) {
        _userBlock = parts[0].trim();
        _userLocation = parts.sublist(1).join(' - ').trim();
      }
    }
    // ✅ الموقع المختار يتبع موقع الحساب القادم من الخادم، إلا إذا كان
    // المستخدم قد اختار موقعاً آخر محلياً في هذه الجلسة (فيبقى اختياره).
    if (user.locationId != null && user.locationId!.isNotEmpty) {
      _selectedLocationId ??= user.locationId;
    }
    _isAdmin = isAdmin;
    _currentUser = user;
    _authStatus = AuthStatus.authenticated;
    _errorMessage = null;
    notifyListeners();
    _persistLocation();
  }

  void _setError(String message) {
    _authStatus = AuthStatus.unauthenticated;
    _errorMessage = message;
    notifyListeners();
  }
}

// ══════════════════════════════════════════════════════════════════════════
// شِفرة مشتركة لكل الـ Providers أدناه
// ══════════════════════════════════════════════════════════════════════════
enum LoadingState { initial, loading, success, error }

// ══════════════════════════════════════════════════════════════════════════
// PRODUCT PROVIDER
// ══════════════════════════════════════════════════════════════════════════
class ProductProvider extends ChangeNotifier {
  final ProductService _service;
  ProductProvider({ProductService? service})
      : _service = service ?? ProductService();

  LoadingState _state = LoadingState.initial;
  List<ProductModel> _products = [];
  String? _errorMessage;
  bool _hasNextPage = false;
  int _currentPage = 1;
  String? _search;
  String? _category;
  String? _locationId;
  /// ✅ إجمالي المنتجات في الخادم (من pagination.total)، لا عدد ما
  /// حُمِّل محلياً — تعرضه الصفحة الرئيسية كـ"منتجات مراقبة".
  int _totalProducts = 0;

  LoadingState get state => _state;
  List<ProductModel> get products => _products;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == LoadingState.loading;
  bool get hasNextPage => _hasNextPage;
  int get totalProducts =>
      _totalProducts > 0 ? _totalProducts : _products.length;

  /// ✅ التصنيفات الفعلية القادمة من الخادم، مسبوقة دائماً بخيار "الكل".
  List<String> _categories = const ['الكل'];
  List<String> get categories => _categories;

  Future<void> loadCategories() async {
    if (AppConfig.useMockData) {
      _categories = [
        'الكل',
        ...{for (final p in MockData.products) p.category},
      ];
      notifyListeners();
      return;
    }
    try {
      final fetched = await _service.getCategories();
      _categories = ['الكل', ...fetched];
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  /// ✅ [locationId] معرّف الحي المختار — يُمرَّر من الشاشات عبر
  /// AppProvider.selectedLocationId حتى تعكس الأسعار السوقية المعروضة
  /// (real_price / avg_price / change_percent) متاجر ذلك الحي فقط. تغييره
  /// يُعيد تحميل القائمة من الصفحة الأولى تماماً كتغيير التصنيف أو البحث.
  Future<void> loadProducts({
    String? category,
    String? search,
    String? locationId,
    bool refresh = false,
  }) async {
    if (refresh ||
        category != _category ||
        search != _search ||
        locationId != _locationId) {
      _products = [];
      _currentPage = 1;
    }
    _category = category;
    _search = search;
    _locationId = locationId;
    _state = LoadingState.loading;
    notifyListeners();

    // ── وضع العرض التجريبي: استخدم MockData مباشرة ──────────────────────
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      _products = category == null || category == 'الكل'
          ? MockData.products
          : MockData.products.where((p) => p.category == category).toList();
      _totalProducts = _products.length;
      _hasNextPage = false;
      _state = LoadingState.success;
      notifyListeners();
      return;
    }

    // ── الوضع الحقيقي: يقرأ من الـ backend عبر ProductService ───────────
    try {
      final response = await _service.getProducts(
        search: search,
        category: category,
        locationId: locationId,
        page: _currentPage,
      );
      _products = [..._products, ...?response.data];
      _totalProducts = response.pagination?.total ?? _products.length;
      _hasNextPage = response.pagination?.hasNextPage ?? false;
      _currentPage++;
      _state = LoadingState.success;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _state = LoadingState.error;
    } finally {
      notifyListeners();
    }
  }

  /// ✅ جديد — تُستخدم من "إدارة المنتجات" في لوحة الإدارة
  Future<bool> createProduct({
    required String name,
    required String category,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      _products = [
        ..._products,
        ProductModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          category: category,
          officialPrice: 0,
          realPrice: 0,
          avgPrice: 0,
          unit: '',
          pricesCount: 0,
          changePercent: 0,
          isPriceUp: false,
        ),
      ];
      notifyListeners();
      return true;
    }
    try {
      final p = await _service.createProduct(name: name, category: category);
      _products = [..._products, p];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ جديد — تعديل منتج موجود، مطابقةً لعنصر "تعديل" الناقص سابقاً ضمن
  /// مخطط حالات الاستخدام لـ"إدارة المنتجات".
  Future<bool> updateProduct(
    String id, {
    required String name,
    required String category,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      _products = _products
          .map((p) => p.id == id
              ? ProductModel(
                  id: id,
                  name: name,
                  category: category,
                  officialPrice: p.officialPrice,
                  realPrice: p.realPrice,
                  avgPrice: p.avgPrice,
                  unit: p.unit,
                  pricesCount: p.pricesCount,
                  changePercent: p.changePercent,
                  isPriceUp: p.isPriceUp,
                )
              : p)
          .toList();
      notifyListeners();
      return true;
    }
    try {
      final updated =
          await _service.updateProduct(id, name: name, category: category);
      _products = _products.map((p) => p.id == id ? updated : p).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ جديد
  Future<bool> deleteProduct(String id) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      _products = _products.where((p) => p.id != id).toList();
      notifyListeners();
      return true;
    }
    try {
      await _service.deleteProduct(id);
      _products = _products.where((p) => p.id != id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// STORE PROVIDER
// ══════════════════════════════════════════════════════════════════════════
class StoreProvider extends ChangeNotifier {
  final StoreService _service;
  StoreProvider({StoreService? service}) : _service = service ?? StoreService();

  LoadingState _state = LoadingState.initial;
  List<StoreModel> _stores = [];
  String? _errorMessage;
  bool _hasNextPage = false;
  int _currentPage = 1;

  LoadingState get state => _state;
  List<StoreModel> get stores => _stores;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == LoadingState.loading;
  bool get hasNextPage => _hasNextPage;

  Future<void> loadStores({
    String? sector,
    String? search,
    bool refresh = false,
  }) async {
    if (refresh) {
      _stores = [];
      _currentPage = 1;
    }
    _state = LoadingState.loading;
    notifyListeners();

    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      _stores = MockData.stores.where((s) {
        final matchesSector =
            sector == null || sector == 'الكل' || s.sector == sector;
        final matchesSearch = search == null ||
            search.isEmpty ||
            s.name.contains(search) ||
            s.area.contains(search);
        return matchesSector && matchesSearch;
      }).toList();
      _hasNextPage = false;
      _state = LoadingState.success;
      notifyListeners();
      return;
    }

    try {
      final response = await _service.getStores(
        search: search,
        sector: sector,
        page: _currentPage,
      );
      _stores = [..._stores, ...?response.data];
      _hasNextPage = response.pagination?.hasNextPage ?? false;
      _currentPage++;
      _state = LoadingState.success;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _state = LoadingState.error;
    } finally {
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري — أُضيف الوسيط الاختياري [locationId]: معرّف الموقع
  // الحقيقي المطابق للحي المختار (يُحسَب في AddStoreScreen قبل الاستدعاء
  // عبر CatalogProvider.locationIdForArea). في وضع العرض التجريبي يبقى
  // غير مستخدَم — المتجر يُبنى محلياً بالاسم النصي [area]/[sector] كما كان
  // تماماً، فلا أي تغيير على تجربة العرض التجريبي أو شكلها.
  //
  // في الوضع الحقيقي أصبح locationId إلزامياً فعلياً (وليس فقط شكلياً)
  // لأن جدول Store في قاعدة البيانات الفعلية يتطلب location_id (مفتاح
  // أجنبي)، لا نصوص حرة area/sector كما كان يُرسَل سابقاً.
  // ══════════════════════════════════════════════════════════════════════
  Future<bool> createStore({
    required String name,
    required String address,
    required String area,
    required String sector,
    String? locationId,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      _stores = [
        ..._stores,
        StoreModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          address: address,
          area: area,
          sector: sector,
          isVerified: false,
        ),
      ];
      notifyListeners();
      return true;
    }
    if (locationId == null || locationId.isEmpty) {
      _errorMessage = 'تعذّر تحديد الموقع، حاول اختيار المنطقة مجدداً';
      notifyListeners();
      return false;
    }
    try {
      final s = await _service.createStore(
          locationId: locationId, name: name, address: address);
      _stores = [..._stores, s];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ جديد — توثيق/إلغاء توثيق متجر (استخدام إداري)
  Future<bool> setVerified(String id, bool verified) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      _stores = _stores
          .map((s) => s.id == id ? s.copyWith(isVerified: verified) : s)
          .toList();
      notifyListeners();
      return true;
    }
    try {
      await _service.verifyStore(id, verified: verified);
      _stores = _stores
          .map((s) => s.id == id ? s.copyWith(isVerified: verified) : s)
          .toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ جديد — تعديل بيانات متجر (استخدام إداري)، مطابقةً لعنصر "تعديل"
  /// في مخطط حالات الاستخدام لـ"إدارة المتاجر".
  Future<bool> updateStore(
    String id, {
    required String name,
    required String address,
    String? locationId,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      _stores = _stores
          .map((s) => s.id == id ? s.copyWith(name: name, address: address) : s)
          .toList();
      notifyListeners();
      return true;
    }
    try {
      final updated = await _service.updateStore(id,
          name: name, address: address, locationId: locationId);
      _stores = _stores.map((s) => s.id == id ? updated : s).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ جديد
  Future<bool> deleteStore(String id) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      _stores = _stores.where((s) => s.id != id).toList();
      notifyListeners();
      return true;
    }
    try {
      await _service.deleteStore(id);
      _stores = _stores.where((s) => s.id != id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ✅ جديد — PRICE PROVIDER
// يغطي: عرض أسعار منتج معيّن (ProductDetailScreen)، إرسال سعر جديد
// (AddPriceScreen)، التصويت (إعجاب/عدم إعجاب)، ومراجعة الإدارة
// (AdminPriceReviewScreen). كانت هذه كلها بلا أي Provider من قبل، والشاشات
// كانت تقرأ MockData.priceEntries مباشرة بغض النظر عن AppConfig.useMockData.
// ══════════════════════════════════════════════════════════════════════════
class PriceProvider extends ChangeNotifier {
  final PriceService _priceService;
  final ProductService _productService;
  PriceProvider({PriceService? priceService, ProductService? productService})
      : _priceService = priceService ?? PriceService(),
        _productService = productService ?? ProductService();

  LoadingState _state = LoadingState.initial;
  List<PriceEntry> _entries = [];
  String? _errorMessage;

  LoadingState get state => _state;
  List<PriceEntry> get entries => _entries;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == LoadingState.loading;

  /// GET /products/{id}/prices — لعرض كل الأسعار المسجّلة لمنتج معيّن
  ///
  /// ✅ إصلاح جوهري (السبب المباشر لعدم ظهور "الأسعار المسجلة"):
  /// • كانت الدالة تتجاهل [productId] تماماً في وضع العرض التجريبي وتعيد
  ///   نفس القائمة الثابتة MockData.priceEntries لأي منتج، بغض النظر عن
  ///   المنتج المطلوب فعلياً — والآن تُفلتَر المدخلات حسب productId فعلياً.
  ///   راجع الإصلاح المقابل في mock_data.dart حيث أُضيف productId الحقيقي
  ///   لكل مدخلة، بالإضافة إلى مدخلتين جديدتين لمنتج "رز أبيض" الذي لم يكن
  ///   له أي سعر مسجّل من الأساس.
  /// • لم تكن القائمة القديمة _entries تُصفَّر عند بدء تحميل منتج جديد،
  ///   فكانت أسعار منتج سابق تبقى ظاهرة للحظة أو يختلط عرضها مع منتج آخر.
  /// • _requestToken يحمي من مشكلة الطلبات غير المرتّبة: إن انتقل
  ///   المستخدم بسرعة بين منتجين، لا تعود نتيجة الطلب الأقدم لتكتب فوق
  ///   نتيجة الطلب الأحدث بعد اكتمالها.
  /// • وضع العرض التجريبي أصبح أيضاً محاطاً بـ try/catch (كان بلا حماية
  ///   إطلاقاً) حتى لا تتجمّد الشاشة صامتة في حال حدوث أي خطأ غير متوقع.
  int _requestToken = 0;

  Future<void> loadProductPrices(String productId) async {
    final myToken = ++_requestToken;
    _state = LoadingState.loading;
    _errorMessage = null;
    _entries = []; // ✅ تصفير فوري لمنع ظهور أسعار منتج سابق أثناء التحميل
    notifyListeners();

    if (AppConfig.useMockData) {
      try {
        await Future.delayed(const Duration(milliseconds: 300));
        if (myToken != _requestToken) return; // طلب أحدث تجاوز هذا الطلب
        _entries = MockData.priceEntries
            .where((e) => e.productId == productId)
            .toList();
        _state = LoadingState.success;
      } catch (_) {
        if (myToken != _requestToken) return;
        _errorMessage = 'حدث خطأ غير متوقع أثناء تحميل الأسعار';
        _state = LoadingState.error;
      } finally {
        if (myToken == _requestToken) notifyListeners();
      }
      return;
    }

    try {
      final result = await _productService.getProductPrices(productId);
      if (myToken != _requestToken) return;
      _entries = result;
      _state = LoadingState.success;
    } on ApiException catch (e) {
      if (myToken != _requestToken) return;
      _errorMessage = e.message;
      _state = LoadingState.error;
    } catch (e) {
      if (myToken != _requestToken) return;
      // ✅ يلتقط أي خطأ غير متوقع (parsing، null، إلخ) بدل تركه يعلّق
      // الحالة على "جارٍ التحميل" إلى الأبد بصمت.
      _errorMessage = 'حدث خطأ غير متوقع أثناء تحميل الأسعار';
      _state = LoadingState.error;
    } finally {
      if (myToken == _requestToken) notifyListeners();
    }
  }

  /// GET /prices — لمراجعة الإدارة
  Future<void> loadAdminPrices({String? status}) async {
    _state = LoadingState.loading;
    notifyListeners();
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      _entries = status == null || status == 'الكل'
          ? MockData.priceEntries
          : MockData.priceEntries.where((e) => e.status == status).toList();
      _state = LoadingState.success;
      notifyListeners();
      return;
    }
    try {
      final response = await _priceService.getPrices(status: status);
      _entries = response.data ?? [];
      _state = LoadingState.success;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _state = LoadingState.error;
    } finally {
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري — أُعيدت تسمية الوسيطَين [unit]/[brand] النصيَّين إلى
  // [unitId]/[brandId] (معرّفان حقيقيان)، و[quantity] بقي كاسم داخلي للـ
  // Dart لكن يُرسَل الآن للخادم تحت مفتاح amount (اسم العمود الفعلي في
  // قاعدة البيانات). راجع نفس الملاحظة الكاملة في PriceService.submitPrice.
  // ══════════════════════════════════════════════════════════════════════
  Future<bool> submitPrice({
    required String productId,
    required String storeId,
    required double price,
    required String unitId,
    required double quantity,
    required String brandId,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 800));
      return true;
    }
    try {
      await _priceService.submitPrice(
        productId: productId,
        storeId: storeId,
        price: price,
        unitId: unitId,
        amount: quantity,
        brandId: brandId,
      );
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// POST /prices/{id}/vote — تحديث متفائل (optimistic) لعدّاد التقييمات
  Future<bool> vote(String id, {required bool isUp}) async {
    final idx = _entries.indexWhere((e) => e.id == id);
    final previous = idx == -1 ? null : _entries[idx];
    if (idx != -1) {
      _entries[idx] = previous!.copyWith(
        thumbsUp: previous.thumbsUp + (isUp ? 1 : 0),
        thumbsDown: previous.thumbsDown + (isUp ? 0 : 1),
        totalRatings: previous.totalRatings + 1,
      );
      notifyListeners();
    }
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }
    try {
      await _priceService.votePrice(id, isUp: isUp);
      return true;
    } on ApiException catch (e) {
      // تراجع عن التحديث المتفائل عند الفشل
      if (idx != -1 && previous != null) {
        _entries[idx] = previous;
      }
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري — حلّت محل review(approve/reject) السابقة. جدول Price في
  // قاعدة البيانات الفعلية (Waffir_Database.txt) لا يحتوي عمود status
  // إطلاقاً، فلا يوجد أي مكان حقيقي لحفظ حالة "مقبول/مرفوض". مخطط حالات
  // الاستخدام يُدرج "حذف السعر" صراحة كالإجراء الإداري الوحيد ضمن "مراجعة
  // الأسعار" — فأصبح الحذف النهائي هو مسار المراجعة الفعلي المتوافق مع
  // كل من المخطط وقاعدة البيانات معاً.
  // ══════════════════════════════════════════════════════════════════════
  /// DELETE /prices/{id} — حذف سعر (مراجعة إدارية)
  Future<bool> deletePrice(String id) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      _entries = _entries.where((e) => e.id != id).toList();
      notifyListeners();
      return true;
    }
    try {
      await _priceService.deletePrice(id);
      _entries = _entries.where((e) => e.id != id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ✅ جديد — REPORT PROVIDER
// كانت ReportService مكتوبة بالكامل وموثّقة لكن غير مستخدمة من أي شاشة —
// لا في شاشة المستخدم (لا يوجد زر بلاغ فعلي) ولا في لوحة الإدارة (كانت
// تعرض MockData.reports مباشرة).
// ══════════════════════════════════════════════════════════════════════════
class ReportProvider extends ChangeNotifier {
  final ReportService _service;
  ReportProvider({ReportService? service})
      : _service = service ?? ReportService();

  LoadingState _state = LoadingState.initial;
  List<ReportModel> _reports = [];
  String? _errorMessage;

  LoadingState get state => _state;
  List<ReportModel> get reports => _reports;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == LoadingState.loading;

  Future<void> loadReports() async {
    _state = LoadingState.loading;
    notifyListeners();
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      _reports = MockData.reports;
      _state = LoadingState.success;
      notifyListeners();
      return;
    }
    try {
      final response = await _service.getReports();
      _reports = response.data ?? [];
      _state = LoadingState.success;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _state = LoadingState.error;
    } finally {
      notifyListeners();
    }
  }

  /// POST /reports — من زر البلاغ (🚩) في بطاقة السعر
  Future<bool> submitReport({
    required String priceEntryId,
    required String type,
    String? note,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }
    try {
      await _service.submitReport(
          priceEntryId: priceEntryId, type: type, note: note);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// DELETE /reports/{id} — حذف البلاغ نهائياً.
  Future<bool> deleteReport(String id) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      _reports = _reports.where((r) => r.id != id).toList();
      notifyListeners();
      return true;
    }
    try {
      await _service.deleteReport(id);
      _reports = _reports.where((r) => r.id != id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ✅ جديد — CATALOG PROVIDER
// يغطي كل "بيانات المرجع" الإدارية: الأسعار الرسمية، الوحدات، العلامات
// التجارية، المواقع، بالإضافة إلى إحصائيات لوحة التحكم والنشاط الأخير.
// كل هذه كانت تُقرأ من MockData مباشرة في admin_shell.dart وhome_screen.dart
// رغم أن CatalogService توفّرها بالكامل عبر الـ backend.
// ══════════════════════════════════════════════════════════════════════════
class CatalogProvider extends ChangeNotifier {
  final CatalogService _service;
  CatalogProvider({CatalogService? service})
      : _service = service ?? CatalogService();

  List<OfficialPrice> officialPrices = [];
  List<UnitModel> units = [];
  List<BrandModel> brands = [];
  List<LocationModel> locations = [];
  List<SectorModel> sectors = [];
  Map<String, dynamic> dashboardStats = {};
  List<Map<String, dynamic>> recentActivity = [];
  bool isLoading = false;
  String? errorMessage;
  // ✅ جديد — سجل تغييرات السعر الرسمي للمادة المفتوحة حالياً
  List<OfficialPriceHistoryEntry> officialPriceHistory = [];
  bool isLoadingHistory = false;
  String? historyErrorMessage;

  // ── الأسعار الرسمية ──────────────────────────────────────────────────
  Future<void> loadOfficialPrices({String? search}) async {
    isLoading = true;
    notifyListeners();
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      officialPrices = MockData.officialPrices;
      isLoading = false;
      notifyListeners();
      return;
    }
    try {
      officialPrices = await _service.getOfficialPrices(search: search);
    } on ApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري — كانت هذه الدالة تستقبل [productName]/[unit] كنصوص
  // حرة (من TextField في لوحة الإدارة) وترسلهما مباشرة، رغم أن مخطط قاعدة
  // البيانات الفعلي لجدول OfficialPrice لا يحتوي أي عمود نصي لاسم المنتج
  // أو الوحدة — فقط product_id/unit_id (مفتاحان أجنبيان). أي اسم مكتوب
  // يدوياً كان سيبقى بلا أي ربط حقيقي بجدول Product/Unit.
  //
  // الآن تستقبل معرّفين حقيقيين (productId/unitId، يُختاران من قوائم
  // منتجات/وحدات موجودة فعلاً)، مع [productName]/[unitName] كوسيطين
  // إضافيين يُستخدَمان فقط لبناء عنصر العرض الفوري محلياً في وضع العرض
  // التجريبي — لا يُرسَلان للخادم إطلاقاً في الوضع الحقيقي.
  // ══════════════════════════════════════════════════════════════════════
  Future<bool> addOfficialPrice({
    required String productId,
    required String productName,
    required String unitId,
    required String unitName,
    required double amount,
    required double price,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      officialPrices = [
        ...officialPrices,
        OfficialPrice(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          productId: productId,
          productName: productName,
          unitId: unitId,
          unit: unitName,
          quantity: amount,
          price: price,
          updatedAt: DateTime.now(),
        ),
      ];
      notifyListeners();
      return true;
    }
    try {
      final op = await _service.createOfficialPrice(
          productId: productId, unitId: unitId, amount: amount, price: price);
      officialPrices = [...officialPrices, op];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ جديد — تعديل سعر رسمي موجود، مطابقةً لعنصر "تعديل" في مخطط حالات
  /// الاستخدام لـ"إدارة الأسعار الرسمية".
  Future<bool> updateOfficialPrice(
    String id, {
    required String productId,
    required String productName,
    required String unitId,
    required String unitName,
    required double amount,
    required double price,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      officialPrices = officialPrices
          .map((op) => op.id == id
              ? OfficialPrice(
                  id: id,
                  productId: productId,
                  productName: productName,
                  unitId: unitId,
                  unit: unitName,
                  quantity: amount,
                  price: price,
                  updatedAt: DateTime.now())
              : op)
          .toList();
      notifyListeners();
      return true;
    }
    try {
      final updated = await _service.updateOfficialPrice(id,
          productId: productId, unitId: unitId, amount: amount, price: price);
      officialPrices =
          officialPrices.map((op) => op.id == id ? updated : op).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ جديد — حذف سعر رسمي، مطابقةً لعنصر "حذف" في نفس المخطط.
  Future<bool> deleteOfficialPrice(String id) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      officialPrices = officialPrices.where((op) => op.id != id).toList();
      notifyListeners();
      return true;
    }
    try {
      await _service.deleteOfficialPrice(id);
      officialPrices = officialPrices.where((op) => op.id != id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// GET /official-prices/{id}/history — ✅ جديد
  /// يُستدعى من OfficialPriceHistoryScreen عند فتح مادة معيّنة.
  Future<void> loadOfficialPriceHistory(String officialPriceId) async {
    isLoadingHistory = true;
    officialPriceHistory = [];
    historyErrorMessage = null;
    notifyListeners();
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      officialPriceHistory =
          MockData.officialPriceHistory[officialPriceId] ?? [];
      isLoadingHistory = false;
      notifyListeners();
      return;
    }
    try {
      officialPriceHistory =
          await _service.getOfficialPriceHistory(officialPriceId);
    } on ApiException catch (e) {
      historyErrorMessage = e.message;
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  // ── الوحدات ──────────────────────────────────────────────────────────
  Future<void> loadUnits() async {
    isLoading = true;
    notifyListeners();
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      units = MockData.units;
      isLoading = false;
      notifyListeners();
      return;
    }
    try {
      units = await _service.getUnits();
    } on ApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addUnit(String name) async {
    if (name.trim().isEmpty) return false;
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      units = [
        ...units,
        UnitModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            usageCount: 0)
      ];
      notifyListeners();
      return true;
    }
    try {
      final u = await _service.createUnit(name);
      units = [...units, u];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ جديد — كانت هذه العملية معطَّلة سابقاً (نافذة "قيد التطوير") لعدم
  /// وجود endpoint موثّق؛ أصبح موثّقاً الآن (راجع CatalogService.updateUnit)
  /// مطابقةً لعنصر "تعديل" في مخطط حالات الاستخدام لـ"إدارة الوحدات".
  Future<bool> updateUnit(String id, String name) async {
    if (name.trim().isEmpty) return false;
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      units = units
          .map((u) => u.id == id
              ? UnitModel(id: id, name: name, usageCount: u.usageCount)
              : u)
          .toList();
      notifyListeners();
      return true;
    }
    try {
      final updated = await _service.updateUnit(id, name);
      units = units.map((u) => u.id == id ? updated : u).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUnit(String id) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      units = units.where((u) => u.id != id).toList();
      notifyListeners();
      return true;
    }
    try {
      await _service.deleteUnit(id);
      units = units.where((u) => u.id != id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  // ── العلامات التجارية ────────────────────────────────────────────────
  Future<void> loadBrands() async {
    isLoading = true;
    notifyListeners();
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      brands = MockData.brands;
      isLoading = false;
      notifyListeners();
      return;
    }
    try {
      brands = await _service.getBrands();
    } on ApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addBrand(String name) async {
    if (name.trim().isEmpty) return false;
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      brands = [
        ...brands,
        BrandModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            productsCount: 0)
      ];
      notifyListeners();
      return true;
    }
    try {
      final b = await _service.createBrand(name);
      brands = [...brands, b];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ جديد — تعديل علامة تجارية موجودة (نفس منطق updateUnit أعلاه).
  Future<bool> updateBrand(String id, String name) async {
    if (name.trim().isEmpty) return false;
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      brands = brands
          .map((b) => b.id == id
              ? BrandModel(id: id, name: name, productsCount: b.productsCount)
              : b)
          .toList();
      notifyListeners();
      return true;
    }
    try {
      final updated = await _service.updateBrand(id, name);
      brands = brands.map((b) => b.id == id ? updated : b).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBrand(String id) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      brands = brands.where((b) => b.id != id).toList();
      notifyListeners();
      return true;
    }
    try {
      await _service.deleteBrand(id);
      brands = brands.where((b) => b.id != id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  // ── المواقع والقطاعات ────────────────────────────────────────────────
  Future<void> loadLocations({String? search}) async {
    isLoading = true;
    notifyListeners();
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      locations = MockData.locations;
      isLoading = false;
      notifyListeners();
      return;
    }
    try {
      locations = await _service.getLocations(search: search);
    } on ApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// ✅ محدَّث — [sector] هنا هو اسم الكتلة الإدارية (مثال: "الكتلة الخامسة")
  /// بدل نص محافظة حر كما كان سابقاً، تماشياً مع بقية التطبيق.
  Future<bool> addLocation({
    required String sector,
    required String area,
    required String landmark,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      locations = [
        ...locations,
        LocationModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sector: sector,
            area: area,
            landmark: landmark,
            storesCount: 0)
      ];
      notifyListeners();
      return true;
    }
    try {
      final sectorId = sectorIdForName(sector);
      if (sectorId == null) return false;
      final l =
          await _service.createLocation(sectorId: sectorId, district: area);
      locations = [...locations, l];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ جديد — تعديل موقع/حي موجود، مطابقةً لعنصر "تعديل" في مخطط حالات
  /// الاستخدام لـ"إدارة المواقع والكتل".
  Future<bool> updateLocation(
    String id, {
    required String sector,
    required String area,
    required String landmark,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      locations = locations
          .map((l) => l.id == id
              ? LocationModel(
                  id: id,
                  sector: sector,
                  area: area,
                  landmark: landmark,
                  storesCount: l.storesCount)
              : l)
          .toList();
      notifyListeners();
      return true;
    }
    try {
      final sectorId = sectorIdForName(sector);
      if (sectorId == null) return false;
      final updated =
          await _service.updateLocation(id, sectorId: sectorId, district: area);
      locations = locations.map((l) => l.id == id ? updated : l).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ جديد — حذف موقع/حي، مطابقةً لعنصر "حذف" في نفس المخطط.
  Future<bool> deleteLocation(String id) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      locations = locations.where((l) => l.id != id).toList();
      notifyListeners();
      return true;
    }
    try {
      await _service.deleteLocation(id);
      locations = locations.where((l) => l.id != id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — يبحث عن location_id الحقيقي المطابق لاسم حي معيّن ضمن قائمة
  // المواقع المُحمَّلة من الخادم (locations، عبر loadLocations أعلاه).
  //
  // يُستخدم عند التسجيل (RegisterScreen) أو اقتراح متجر جديد (AddStoreScreen)
  // لترجمة اختيار (الكتلة، الحي) القادم من منتقي الموقع الثابت
  // (AleppoBlocks — يبقى كما هو تماماً في الواجهة، بلا أي تغيير مرئي) إلى
  // location_id فعلي قبل الإرسال للـ backend. هذا ممكن لأن جدول Location
  // في قاعدة البيانات الفعلية يُبنى بنفس أسماء الأحياء المستخدمة في
  // AleppoBlocks تماماً (تم التحقق من هذا التطابق يدوياً على عيّنة البيانات
  // المُدرَجة في قاعدة البيانات).
  //
  // يُعيد null إن لم توجد قائمة المواقع بعد (لم تُحمَّل) أو لم يوجد الحي
  // ضمنها إطلاقاً — الشاشات المستدعية تعرض رسالة خطأ واضحة في هذه الحالة
  // بدل إرسال طلب بمعرّف فارغ للخادم.
  // ══════════════════════════════════════════════════════════════════════
  String? locationIdForArea(String area) {
    final trimmed = area.trim();
    if (trimmed.isEmpty) return null;
    for (final loc in locations) {
      if (loc.area.trim() == trimmed) return loc.id;
    }
    return null;
  }

  Future<void> loadSectors() async {
    if (AppConfig.useMockData) {
      sectors = AleppoBlocks.all
          .map((b) => SectorModel(id: b.number.toString(), name: b.name))
          .toList();
      notifyListeners();
      return;
    }
    try {
      sectors = await _service.getSectors();
      notifyListeners();
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
    }
  }

  String? sectorIdForName(String name) {
    final sector = sectors.where((s) => s.name == name).firstOrNull;
    if (sector != null) return sector.id;
    final location = locations.where((l) => l.sector == name).firstOrNull;
    return location?.sectorId;
  }

  Future<bool> addSector(String name, {String description = ''}) async {
    if (name.trim().isEmpty) return false;
    if (AppConfig.useMockData) {
      sectors = [
        ...sectors,
        SectorModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name.trim(),
          description: description,
        ),
      ];
      notifyListeners();
      return true;
    }
    try {
      sectors = [
        ...sectors,
        await _service.createSector(name: name.trim(), description: description)
      ];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSector(String oldName, String newName) async {
    final sector = sectors.where((s) => s.name == oldName).firstOrNull;
    if (sector == null) return false;
    if (AppConfig.useMockData) {
      sectors = sectors
          .map((s) => s.id == sector.id
              ? SectorModel(id: s.id, name: newName, description: s.description)
              : s)
          .toList();
      notifyListeners();
      return true;
    }
    try {
      final updated = await _service.updateSector(sector.id,
          name: newName, description: sector.description);
      sectors = sectors.map((s) => s.id == sector.id ? updated : s).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSector(String name) async {
    final sector = sectors.where((s) => s.name == name).firstOrNull;
    if (sector == null) return false;
    if (AppConfig.useMockData) {
      sectors = sectors.where((s) => s.id != sector.id).toList();
      notifyListeners();
      return true;
    }
    try {
      await _service.deleteSector(sector.id);
      sectors = sectors.where((s) => s.id != sector.id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  // ── لوحة التحكم ──────────────────────────────────────────────────────
  Future<void> loadDashboardStats() async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      dashboardStats = MockData.dashboardStats;
      notifyListeners();
      return;
    }
    try {
      dashboardStats = await _service.getDashboardStats();
      notifyListeners();
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
    }
  }

  Future<void> loadRecentActivity() async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      recentActivity = MockData.recentActivity;
      notifyListeners();
      return;
    }
    try {
      recentActivity = await _service.getRecentActivity();
      notifyListeners();
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ✅ جديد — ADMIN USERS PROVIDER
// كانت AdminUserService (حظر/رفع حظر/تغيير دور) مكتوبة بالكامل لكن غير
// مستخدمة من AdminUsersScreen التي كانت تعرض جدولاً بلا أي إجراء إطلاقاً.
// ══════════════════════════════════════════════════════════════════════════
class AdminUsersProvider extends ChangeNotifier {
  final AdminUserService _service;
  AdminUsersProvider({AdminUserService? service})
      : _service = service ?? AdminUserService();

  List<UserModel> users = [];
  bool isLoading = false;
  String? errorMessage;

  /// ✅ جديد — قائمة المسؤولين فقط (role == 'admin')، تُستخدم في شاشة
  /// "عرض المسؤولين" الجديدة ضمن الإعدادات (راجع مخطط حالات الاستخدام:
  /// عرض المسؤولين --extend--> إضافة/تعديل/بحث/حذف مسؤول). تُشتقّ من نفس
  /// [users] المُحمَّلة عبر loadUsers، فلا حاجة لطلب شبكة منفصل.
  List<UserModel> get admins => users.where((u) => u.role == 'admin').toList();

  Future<void> loadUsers({String? search, String? status}) async {
    isLoading = true;
    notifyListeners();
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      users = MockData.users.where((u) {
        final matchesSearch = search == null ||
            search.isEmpty ||
            u.name.contains(search) ||
            u.phone.contains(search);
        return matchesSearch;
      }).toList();
      isLoading = false;
      notifyListeners();
      return;
    }
    try {
      final response = await _service.getUsers(search: search, status: status);
      users = response.data ?? [];
    } on ApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setBlocked(String id, bool blocked) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      users = users
          .map((u) => u.id == id ? u.copyWith(isActive: !blocked) : u)
          .toList();
      notifyListeners();
      return true;
    }
    try {
      await _service.setUserBlocked(id, blocked: blocked);
      users = users
          .map((u) => u.id == id ? u.copyWith(isActive: !blocked) : u)
          .toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setRole(String id, String role) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      users =
          users.map((u) => u.id == id ? u.copyWith(role: role) : u).toList();
      notifyListeners();
      return true;
    }
    try {
      await _service.setUserRole(id, role);
      users =
          users.map((u) => u.id == id ? u.copyWith(role: role) : u).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ جديد — إضافة مستخدم جديد مباشرة من لوحة الإدارة، مطابقةً لعنصر
  /// "إضافة" ضمن الأفعال الموحّدة في مخطط حالات الاستخدام لـ"إدارة
  /// المستخدمين". [role] اختياري ('admin' عند استخدامها من شاشة "عرض
  /// المسؤولين" لإنشاء حساب مسؤول جديد مباشرة).
  Future<bool> createUser({
    required String name,
    required String phone,
    required String password,
    required String locationId,
    String role = 'user',
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      users = [
        ...users,
        UserModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          phone: phone,
          role: role,
          // ✅ جديد — يُبقي roleLevel متسقاً مع role النصي عند الإنشاء من
          // لوحة الإدارة (بنفس منطق loginMock أعلاه)، بدل تركه صفراً
          // افتراضياً حتى مع role == 'admin'.
          roleLevel: role == 'admin' ? 1 : 0,
          isActive: true,
          // ✅ جديد — تاريخ إنشاء الحساب الفعلي لحظة إضافته من لوحة الإدارة.
          createdAt: DateTime.now(),
        ),
      ];
      notifyListeners();
      return true;
    }
    try {
      final u = await _service.createUser(
          name: name,
          phone: phone,
          password: password,
          locationId: locationId,
          role: role);
      users = [...users, u];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ محدَّث — تعديل بيانات مستخدم (الاسم، ورقم الهاتف، وكلمة المرور
  /// اختيارياً)، مطابقةً لعنصر "تعديل" ضمن الأفعال الموحّدة التي يُدرجها
  /// مخطط حالات الاستخدام لكل من "إدارة المستخدمين" و"عرض المسؤولين"
  /// (كلتاهما تعتمدان على نفس هذا الـ Provider، راجع AdminAdminsScreen في
  /// admin_shell.dart).
  ///
  /// ✅ [phone] اختياري: يتيح لنافذة "تعديل معلومات المسؤول" تحديث رقم
  /// الهاتف مع الاسم دفعة واحدة. في وضع العرض التجريبي يُحدَّث محلياً فوراً
  /// عبر UserModel.copyWith، وفي الوضع الحقيقي يُمرَّر إلى
  /// AdminUserService.updateUser ليُرسَل للخادم. ترك [phone] فارغاً أو null
  /// يُبقي رقم الهاتف الحالي كما هو دون أي تغيير.
  ///
  /// ✅ [password] اختياري أيضاً: عند تمريره غير فارغ يُرسَل مع نفس الطلب
  /// لتحديث كلمة مرور المستخدم/المسؤول في نفس العملية (راجع
  /// AdminUserService.updateUser). في وضع العرض التجريبي لا توجد كلمة مرور
  /// فعلية محفوظة محلياً، فيُتجاهَل الحقل بأمان دون أي تأثير على الحالة.
  ///
  /// ℹ️ ملاحظة دمج — AdminUserService.updateUser يدعم أيضاً [locationId]
  /// اختيارياً على مستوى الخدمة (لتعديل موقع المستخدم)، لكنه لم يُمرَّر بعد
  /// من هذا الـ Provider لأن أي شاشة إدارية حالية لا تطلبه. يمكن إضافته هنا
  /// بنفس النمط عند الحاجة مستقبلاً دون أي تعديل إضافي على طبقة الخدمة.
  Future<bool> updateUser(
    String id, {
    required String name,
    String? phone,
    String? password,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      users = users
          .map((u) => u.id == id
              ? u.copyWith(
                  name: name,
                  phone: (phone != null && phone.isNotEmpty) ? phone : null)
              : u)
          .toList();
      notifyListeners();
      return true;
    }
    try {
      final updated = await _service.updateUser(id,
          name: name, phone: phone, password: password);
      users = users.map((u) => u.id == id ? updated : u).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ✅ جديد — حذف مستخدم نهائياً، مطابقةً لعنصر "حذف" في نفس المخطط.
  Future<bool> deleteUser(String id) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      users = users.where((u) => u.id != id).toList();
      notifyListeners();
      return true;
    }
    try {
      await _service.deleteUser(id);
      users = users.where((u) => u.id != id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }
}
