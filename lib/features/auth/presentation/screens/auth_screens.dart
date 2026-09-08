import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/app_provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/aleppo_blocks.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════
// عناصر مشتركة لكل شاشات المصادقة (تصميم موحّد واحترافي)
// ══════════════════════════════════════════════════════════════════════════

/// الرأس المتدرّج الأزرق المشترك بين كل شاشات تسجيل الدخول/الإنشاء،
/// بنفس هوية شاشة السبلاش والشاشة الرئيسية.
class _AuthHeader extends StatelessWidget {
  final Widget icon;
  final List<Color> gradientColors;
  final double height;

  const _AuthHeader({
    required this.icon,
    this.gradientColors = const [Color(0xFF1D4ED8), Color(0xFF2563EB)],
    this.height = 225,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: icon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ إصلاح وضوح الشعار: كانت الأيقونة تجلس بالضبط على الخط الفاصل بين
// التدرّج الأزرق والبطاقة البيضاء (بسبب Matrix4.translationValues(0,-28,0)
// في _AuthCard سابقاً)، فيختلط نصفها العلوي بالخلفية الزرقاء ونصفها السفلي
// بالبطاقة البيضاء، ما يجعلها تبدو باهتة/غير واضحة. الحل: إطار أبيض
// سميك (halo) حول الأيقونة بالكامل + ظل أقوى وأعمق يفصلها بوضوح تام
// عن أي خلفية خلفها، مع تكبير حجمها قليلاً — بالإضافة إلى تقليل ارتفاع
// تراكب البطاقة إلى -4 (بدل -28) وزيادة ارتفاع الرأس المتدرّج وهامش
// الشعار السفلي، ليحصل الشعار على مساحة أكبر بوضوح تام فوق البطاقة.
Widget _iconAvatar(IconData icon, {Color bg = Colors.white}) => Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Icon(icon, color: AppColors.primary, size: 38),
    );

/// بطاقة بيضاء منحنية الحواف العلوية تحمل محتوى الفورم — بنفس أسلوب
/// الشاشة الرئيسية والملف الشخصي (رأس ملون + بطاقة بيضاء متداخلة).
/// ✅ إصلاح: كانت البطاقة ترتفع فتغطي جزءاً من شعار الرأس (icon avatar)
/// فيبدو مقصوصاً/غير واضح خلفها. تم تقليل التراكب أكثر (-4 فقط) مع زيادة
/// ارتفاع الرأس المتدرّج، ليحصل الشعار على مساحة أوضح وأكبر فوق البطاقة.
class _AuthCard extends StatelessWidget {
  final Widget child;
  const _AuthCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: child,
    );
  }
}

InputDecoration _fieldDecoration(BuildContext context,
    {required String label, required IconData icon, Widget? suffix}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
    suffixIcon: suffix,
  );
}

Widget _primaryButton({
  required String label,
  required bool loading,
  required VoidCallback? onPressed,
  Color? color,
}) {
  return SizedBox(
    height: 54,
    child: ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: (color != null
              ? ElevatedButton.styleFrom(
                  backgroundColor: color,
                  elevation: 2,
                  shadowColor: color.withValues(alpha: 0.5))
              : ElevatedButton.styleFrom(
                  elevation: 2,
                  shadowColor: AppColors.primary.withValues(alpha: 0.5)))
          .copyWith(
        // ✅ إصلاح: كانت حشوة الزر الافتراضية ضيقة جداً مع بعض التسميات
        // الطويلة (مثل "دخول لوحة الإدارة")، ما قد يقصّ جزءاً من النص.
        // حشوة أفقية صريحة + FittedBox أدناه يضمنان ظهور النص كاملاً دوماً.
        padding:
            WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 20)),
      ),
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.4),
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
    ),
  );
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// LOGIN
// ══════════════════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final provider = context.read<AppProvider>();
    setState(() => _isLoading = true);
    final success = await provider.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.userHome, (_) => false);
    } else {
      _showError(
          context, provider.errorMessage ?? 'تعذّر تسجيل الدخول، حاول مجدداً');
    }
  }

  // ✅ استُبدلت النافذة المنبثقة (bottom sheet) بشاشة كاملة احترافية
  // (ForgotPasswordScreen) ضمن password_recovery_screens.dart، تتضمن دورة
  // كاملة: طلب رمز → إدخال الرمز + كلمة مرور جديدة.
  void _showForgotPassword() {
    Navigator.pushNamed(context, AppRoutes.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              _AuthHeader(icon: _iconAvatar(Icons.storefront_rounded)),
              _AuthCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✅ عنوان أكبر وأثقل وزناً لضمان وضوحه بالكامل
                      Text('مرحباً بك 👋',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryOf(context))),
                      const SizedBox(height: 6),
                      Text('سجل دخولك لمتابعة الأسعار',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: _fieldDecoration(context,
                            label: 'رقم الهاتف', icon: Icons.phone_outlined),
                        validator: (v) => (v == null || v.trim().length < 8)
                            ? 'أدخل رقم هاتف صحيح'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        decoration: _fieldDecoration(context,
                            label: 'كلمة المرور',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: AppColors.textHintOf(context)),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            )),
                        validator: (v) => (v == null || v.length < 4)
                            ? 'كلمة المرور قصيرة جداً'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPassword,
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _primaryButton(
                          label: 'دخول',
                          loading: _isLoading,
                          onPressed: _submit),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('ليس لديك حساب؟ ',
                              style: TextStyle(
                                  color: AppColors.textSecondaryOf(context))),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(
                                context, AppRoutes.register),
                            child: const Text('إنشاء حساب جديد',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// REGISTER
// ══════════════════════════════════════════════════════════════════════════════
// ✅ إصلاح جوهري جديد — كان اختيار الموقع هنا يعتمد على قائمتين منسدلتين
// منفصلتين ومتتاليتين: "الكتلة" ثم "الحي" (cascading dropdown)، بشكل مختلف
// تماماً عن بقية شاشات التطبيق (AddPriceScreen، AddStoreScreen، شريحة
// الموقع بالصفحة الرئيسية، صف "تغيير الموقع" بالإعدادات) التي توحّدت جميعها
// على نفس منتقي الموقع (showLocationPickerSheet من common_widgets.dart):
// حقل واحد "الكتلة والمنطقة" يفتح نافذة سفلية تعرض الكتل الخمس قابلة للطي،
// كل كتلة تُظهر أحياءها عند فتحها، ويُختار الحي مباشرة من داخلها.
//
// الآن أصبحت شاشة "إنشاء حساب" تستخدم نفس هذا المنتقي الموحّد بالضبط —
// حقل واحد فقط يجمع الكتلة والمنطقة معاً، وحُذف سطر "المنطقة" المنفصل
// نهائياً، بما يطابق تماماً هوية بقية التطبيق. باقي منطق الشاشة (تحميل
// المواقع الحقيقية من الخادم وترجمة الحي إلى location_id عبر
// CatalogProvider.locationIdForArea قبل الإرسال) بقي كما هو تماماً بلا أي
// تغيير.
// ══════════════════════════════════════════════════════════════════════════════
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  // ✅ محدَّث — الكتلة والمنطقة أصبحتا حقلاً واحداً يُختاران معاً عبر
  // منتقي الموقع الموحّد (نفس نمط بقية شاشات التطبيق)، بدل قائمتين
  // منسدلتين منفصلتين. تبقيان null حتى يختار المستخدم فعلياً.
  String? _selectedBlock;
  String? _selectedArea;

  @override
  void initState() {
    super.initState();
    // ✅ جديد — تحميل قائمة المواقع الحقيقية من الخادم (GET /locations)
    // فور فتح شاشة التسجيل، حتى تكون جاهزة لترجمة الحي المختار إلى
    // location_id فعلي عند الضغط على "إنشاء حساب" لاحقاً، بدل انتظار
    // الإرسال ثم اكتشاف عدم توفر البيانات.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalogProvider = context.read<CatalogProvider>();
      if (catalogProvider.locations.isEmpty) {
        catalogProvider.loadLocations();
      }
    });
  }

  /// ✅ جديد — يفتح منتقي الموقع الموحّد (نفس المكوّن المستخدم في شريحة
  /// الموقع بالصفحة الرئيسية، صف "تغيير الموقع" بالإعدادات، AddPriceScreen،
  /// وAddStoreScreen)، ويستقبل الكتلة والمنطقة معاً عند الاختيار.
  void _pickLocation() {
    showLocationPickerSheet(
      context,
      currentBlock: _selectedBlock ?? '',
      currentArea: _selectedArea ?? '',
      onSelect: (block, area) => setState(() {
        _selectedBlock = block;
        _selectedArea = area;
      }),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // ✅ جديد — التحقق من اختيار الكتلة والمنطقة معاً قبل المتابعة، بما أن
    // الحقل أصبح اختيارياً شكلياً (بلا قيمة افتراضية مبدئية) حتى يفتح
    // المستخدم منتقي الموقع بنفسه، بنفس أسلوب AddPriceScreen وAddStoreScreen.
    if (_selectedBlock == null || _selectedArea == null) {
      _showError(context, 'يرجى اختيار الكتلة الإدارية والمنطقة');
      return;
    }
    final provider = context.read<AppProvider>();
    // ✅ جديد — ترجمة الحي المختار إلى location_id حقيقي قبل الإرسال. في
    // وضع العرض التجريبي (AppConfig.useMockData) هذه القيمة تُتجاهَل تماماً
    // داخل AppProvider.register، فلا تأثير لها على تجربة العرض التجريبي.
    final locationId =
        context.read<CatalogProvider>().locationIdForArea(_selectedArea!);
    setState(() => _isLoading = true);
    final phone = _phoneController.text.trim();
    final success = await provider.register(
      name: _nameController.text.trim(),
      phone: phone,
      password: _passwordController.text,
      block: _selectedBlock!,
      area: _selectedArea!,
      locationId: locationId,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      // ✅ بعد إنشاء الحساب مباشرة: تأكيد رقم الهاتف برمز التفعيل (OTP)
      // بدل الدخول المباشر للتطبيق.
      Navigator.pushReplacementNamed(context, AppRoutes.otpVerification,
          arguments: phone);
    } else {
      _showError(
          context, provider.errorMessage ?? 'تعذّر إنشاء الحساب، حاول مجدداً');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              _AuthHeader(
                  icon: _iconAvatar(Icons.person_add_alt_1_rounded),
                  height: 198),
              _AuthCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('إنشاء حساب جديد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryOf(context))),
                      const SizedBox(height: 6),
                      Text('انضم إلى وفّر وتابع الأسعار',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: _fieldDecoration(context,
                            label: 'الاسم الكامل', icon: Icons.person_outline),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'أدخل اسمك الكامل'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: _fieldDecoration(context,
                            label: 'رقم الهاتف', icon: Icons.phone_outlined),
                        validator: (v) => (v == null || v.trim().length < 8)
                            ? 'أدخل رقم هاتف صحيح'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      // ══════════════════════════════════════════════════
                      // ✅ محدَّث — حقل واحد "الكتلة والمنطقة" يفتح منتقي
                      // الموقع الموحّد، بدل قائمتين منسدلتين منفصلتين
                      // ("الكتلة" ثم "المنطقة"). هذا يطابق تماماً نفس نمط
                      // اختيار الموقع في بقية شاشات التطبيق.
                      // ══════════════════════════════════════════════════
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8, right: 4),
                          child: Text('الكتلة والمنطقة',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      AppColors.textPrimaryOf(context))),
                        ),
                      ),
                      _LocationPickerField(
                        block: _selectedBlock,
                        area: _selectedArea,
                        onTap: _pickLocation,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        decoration: _fieldDecoration(context,
                            label: 'كلمة المرور',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: AppColors.textHintOf(context)),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            )),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscureConfirm,
                        decoration: _fieldDecoration(context,
                            label: 'تأكيد كلمة المرور',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: AppColors.textHintOf(context)),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            )),
                        validator: (v) => v != _passwordController.text
                            ? 'كلمتا المرور غير متطابقتين'
                            : null,
                      ),
                      const SizedBox(height: 22),
                      _primaryButton(
                          label: 'إنشاء حساب',
                          loading: _isLoading,
                          onPressed: _submit),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('لديك حساب بالفعل؟ ',
                              style: TextStyle(
                                  color: AppColors.textSecondaryOf(context))),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text('تسجيل الدخول',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ✅ جديد — نسخة محلية من نفس حقل اختيار الموقع الموحّد الموجود في بقية
// شاشات التطبيق (products_screen.dart، add_store_screen.dart) — بنفس
// الشكل والسلوك تماماً، لكن كعنصر خاص بهذا الملف لأن الأصل مُعرَّف بشكل
// خاص (private) في كل ملف على حدة.
// ══════════════════════════════════════════════════════════════════════════
class _LocationPickerField extends StatelessWidget {
  final String? block;
  final String? area;
  final VoidCallback onTap;

  const _LocationPickerField({
    required this.block,
    required this.area,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = block != null && area != null;
    final label =
        hasValue ? AleppoBlocks.displayLabel(block: block!, area: area!) : null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hasValue ? AppColors.primary : AppColors.borderOf(context),
              width: hasValue ? 1.4 : 1),
        ),
        child: Row(children: [
          Icon(Icons.location_on_outlined,
              size: 20,
              color:
                  hasValue ? AppColors.primary : AppColors.textHintOf(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label ?? 'اختر الكتلة الإدارية والمنطقة',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                color: hasValue
                    ? AppColors.textPrimaryOf(context)
                    : AppColors.textHintOf(context),
              ),
            ),
          ),
          Icon(Icons.keyboard_arrow_down,
              size: 20, color: AppColors.textHintOf(context)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ADMIN LOGIN
// ✅ جديد — أُضيف زر "نسيت كلمة المرور؟" أسفل حقل كلمة المرور، محاذى لأقصى
// اليمين (طبيعي في واجهة عربية RTL)، يفتح نفس دورة الاستعادة الموجودة أصلاً
// (ForgotPasswordScreen → ResetPasswordScreen) لكن مع تمرير isAdmin: true
// حتى تُعيد الدورة المستخدم إلى شاشة دخول الإدارة بعد النجاح، بدل شاشة
// تسجيل الدخول العادية.
// ══════════════════════════════════════════════════════════════════════════
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final provider = context.read<AppProvider>();
    setState(() => _isLoading = true);
    final success = await provider.adminLogin(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.adminDashboard, (_) => false);
    } else {
      _showError(context, provider.errorMessage ?? 'بيانات الدخول غير صحيحة');
    }
  }

  // ✅ جديد — يفتح دورة استعادة كلمة المرور نفسها المستخدمة في تسجيل دخول
  // المستخدم العادي، مع تمرير isAdmin: true لتمييز الوجهة النهائية بعد النجاح.
  void _showForgotPassword() {
    Navigator.pushNamed(
      context,
      AppRoutes.forgotPassword,
      arguments: const {'isAdmin': true},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _AuthHeader(
                // ✅ إطار أبيض + ظل أقوى ليتضح الشعار تماماً فوق الخلفية
                // الداكنة جداً لهذه الشاشة
                icon: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 10)),
                    ],
                  ),
                  child: const Icon(Icons.shield_outlined,
                      color: Colors.white, size: 36),
                ),
                gradientColors: const [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                height: 212,
              ),
              Container(
                width: double.infinity,
                // ✅ لا يوجد أي تراكب مع الرأس الآن (بلا transform سلبي)، حتى لا
                // يُقطع شعار الدرع خلف بطاقة تسجيل دخول الإدارة الداكنة أبداً،
                // مع رأس أطول قليلاً يمنح الشعار مساحة أوضح وأكبر فوق البطاقة.
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFF111827),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✅ عنوان أثقل وزناً وأكبر قليلاً لوضوح تام على الخلفية الداكنة
                      const Text('لوحة الإدارة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 6),
                      const Text('تسجيل دخول المسؤولين',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFFB9C6DE),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 26),
                      TextFormField(
                        controller: _usernameController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(color: Colors.white),
                        decoration: _darkFieldDecoration(
                            label: 'رقم الهاتف', icon: Icons.phone_outlined),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'هذا الحقل مطلوب'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        style: const TextStyle(color: Colors.white),
                        decoration: _darkFieldDecoration(
                          label: 'كلمة المرور',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: Colors.white38),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'أدخل كلمة المرور'
                            : null,
                      ),
                      // ✅ جديد — نسيت كلمة المرور، محاذى لأقصى اليمين
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPassword,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryLight,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 8),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'نسيت كلمة المرور؟',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primaryLight
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined,
                                color: AppColors.primaryLight, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'هذه الصفحة مخصصة للمسؤولين فقط. الدخول غير المصرح به ممنوع.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.blue.shade100),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _primaryButton(
                        label: 'دخول لوحة الإدارة',
                        loading: _isLoading,
                        onPressed: _submit,
                        color: AppColors.primaryLight,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _darkFieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
    );
  }
}