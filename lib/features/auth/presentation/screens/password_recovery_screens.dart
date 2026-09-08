import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/app_provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════════════════
// هذا الملف يحتوي على 3 واجهات مترابطة لدورة استعادة/تفعيل الحساب:
//
//  1) OtpVerificationScreen  — تأكيد رقم الهاتف برمز مرسل بعد إنشاء حساب جديد
//     Route: AppRoutes.otpVerification   Arguments: String (رقم الهاتف)
//
//  2) ForgotPasswordScreen   — طلب رمز تحقق لاستعادة كلمة المرور (شاشة كاملة
//     بدل الـ bottom sheet السابق في LoginScreen)
//     Route: AppRoutes.forgotPassword    Arguments: Map? {'isAdmin': bool}
//     ✅ isAdmin (اختياري): يُمرَّر true عند فتح الشاشة من دخول الإدارة، لتمرير
//     نفس القيمة إلى ResetPasswordScreen وتحديد وجهة العودة بعد النجاح.
//
//  3) ResetPasswordScreen    — إدخال رمز التحقق + تعيين كلمة مرور جديدة
//     Route: AppRoutes.resetPassword     Arguments: String | Map
//     (Map يدعم: phone, fromSettings, isAdmin)
//
// التصميم مطابق تماماً لهوية auth_screens.dart (رأس متدرّج أزرق + شعار دائري
// أبيض + بطاقة بيضاء منحنية الحواف)، والملف مكتفٍ ذاتياً (لا يعتمد على أي
// عنصر خاص private من auth_screens.dart).
//
// ✅ يعتمد على 3 دوال جديدة في AppProvider (راجع نهاية الملف للتوثيق):
//    provider.verifyOtp(phone, code)
//    provider.resendOtp(phone)
//    provider.resetPassword(phone, code, newPassword)
// ══════════════════════════════════════════════════════════════════════════

// ───────────────────────── عناصر مشتركة (نفس هوية auth_screens.dart) ──────

class _AuthHeader extends StatelessWidget {
  final Widget icon;
  final double height;

  const _AuthHeader({
    required this.icon,
    this.height = 210,
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
          colors: const [Color(0xFF1D4ED8), Color(0xFF2563EB)],
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

void _showSuccessSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

String _formatCountdown(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ───────────────────────── مربعات إدخال رمز التحقق (OTP) ──────────────────
// ✅ تصميم احترافي: 6 مربعات بصرية + حقل إدخال خفي واحد يلتقط كل الأرقام
// (بما في ذلك اللصق الكامل للرمز عبر النسخ). هذا يتجنّب تعقيد إدارة التنقل
// بين focus nodes متعددة، ويبقى موثوقاً 100% على كل الأجهزة.

class _OtpBoxInput extends StatefulWidget {
  final ValueChanged<String> onChanged;
  const _OtpBoxInput({super.key, required this.onChanged});

  @override
  State<_OtpBoxInput> createState() => _OtpBoxInputState();
}

class _OtpBoxInputState extends State<_OtpBoxInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// يُستدعى من الشاشة الأم لمسح الرمز (مثلاً بعد إدخال خاطئ أو إعادة إرسال)
  void clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final border = AppColors.borderOf(context);
    final surface = AppColors.surfaceOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Directionality(
            textDirection:
                TextDirection.ltr, // ترتيب الأرقام دوماً من اليسار لليمين
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                final text = _controller.text;
                final filled = i < text.length;
                final isCursor = i == text.length && _focusNode.hasFocus;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 44,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCursor || filled ? AppColors.primary : border,
                      width: isCursor ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    filled ? text[i] : '',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textPrimary),
                  ),
                );
              }),
            ),
          ),
          // حقل الإدخال الحقيقي — غير مرئي لكنه يلتقط لوحة المفاتيح واللصق
          Opacity(
            opacity: 0,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(border: InputBorder.none),
                onChanged: (v) {
                  setState(() {});
                  widget.onChanged(v);
                  if (v.length == 6) {
                    FocusScope.of(context).unfocus();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// 1) OTP VERIFICATION — تأكيد رقم الهاتف بعد إنشاء حساب جديد
// ══════════════════════════════════════════════════════════════════════════
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpKey = GlobalKey<_OtpBoxInputState>();
  String _code = '';
  bool _isVerifying = false;
  bool _isResending = false;
  int _secondsLeft = 60;
  Timer? _timer;
  String _phone = '';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _phone = (ModalRoute.of(context)?.settings.arguments as String?) ?? '';
      _initialized = true;
      _startTimer();
    }
  }

  void _startTimer() {
    _secondsLeft = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      _showError(context, 'أدخل رمز التحقق كاملاً (6 أرقام)');
      return;
    }
    final provider = context.read<AppProvider>();
    setState(() => _isVerifying = true);
    final ok = await provider.verifyOtp(phone: _phone, code: _code);
    if (!mounted) return;
    setState(() => _isVerifying = false);
    if (ok) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.userHome, (_) => false);
    } else {
      _showError(
          context, provider.errorMessage ?? 'رمز التحقق غير صحيح، حاول مجدداً');
      _otpKey.currentState?.clear();
      setState(() => _code = '');
    }
  }

  Future<void> _resend() async {
    final provider = context.read<AppProvider>();
    setState(() => _isResending = true);
    final ok = await provider.resendOtp(phone: _phone);
    if (!mounted) return;
    setState(() => _isResending = false);
    if (ok) {
      _otpKey.currentState?.clear();
      setState(() => _code = '');
      _startTimer();
      _showSuccessSnack(context, 'تم إرسال رمز جديد إلى هاتفك');
    } else {
      _showError(
          context, provider.errorMessage ?? 'تعذّر إعادة الإرسال، حاول لاحقاً');
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
                  icon: _iconAvatar(Icons.mark_email_read_outlined),
                  height: 210),
              _AuthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('تأكيد رقم الهاتف',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryOf(context))),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        text: 'أرسلنا رمز تحقق مكوّن من 6 أرقام إلى\n',
                        style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 13.5,
                            height: 1.6),
                        children: [
                          TextSpan(
                              text: _phone,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    _OtpBoxInput(
                        key: _otpKey,
                        onChanged: (v) => setState(() => _code = v)),
                    const SizedBox(height: 14),
                    Center(
                      child: _isResending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : TextButton(
                              onPressed: _secondsLeft == 0 ? _resend : null,
                              child: Text(
                                _secondsLeft == 0
                                    ? 'إعادة إرسال الرمز'
                                    : 'إعادة الإرسال خلال ${_formatCountdown(_secondsLeft)}',
                                style: TextStyle(
                                    color: _secondsLeft == 0
                                        ? AppColors.primary
                                        : AppColors.textHintOf(context)),
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    _primaryButton(
                        label: 'تأكيد',
                        loading: _isVerifying,
                        onPressed: _verify),
                    const SizedBox(height: 18),
                  ],
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
// 2) FORGOT PASSWORD — طلب رمز تحقق لاستعادة كلمة المرور
// ✅ تقبل الآن Map اختيارياً كـ arguments بالشكل: {'isAdmin': bool}
// حتى تُميّز ما إذا كان الطلب قادماً من دخول الإدارة أو من المستخدم العادي،
// وتمرّر هذه القيمة بدورها إلى ResetPasswordScreen لتحديد وجهة العودة
// النهائية بعد نجاح إعادة تعيين كلمة المرور.
// ══════════════════════════════════════════════════════════════════════════
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  // ✅ جديد — true عندما يُفتح هذا المسار من زر "نسيت كلمة المرور؟" في
  // شاشة دخول الإدارة (AdminLoginScreen)، ويُستخدم لتوجيه المستخدم إلى
  // شاشة دخول الإدارة (بدل شاشة تسجيل الدخول العادية) بعد إتمام العملية.
  bool _isAdmin = false;
  bool _argsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _isAdmin = args['isAdmin'] as bool? ?? false;
      }
      _argsInitialized = true;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final provider = context.read<AppProvider>();
    setState(() => _isLoading = true);
    final phone = _phoneController.text.trim();
    final ok = await provider.forgotPassword(phone);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.resetPassword,
        arguments: {'phone': phone, 'isAdmin': _isAdmin},
      );
    } else {
      _showError(context,
          provider.errorMessage ?? 'تعذّر إرسال رمز التحقق، حاول مجدداً');
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
                  icon: _iconAvatar(Icons.lock_reset_outlined), height: 210),
              _AuthCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('نسيت كلمة المرور؟',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryOf(context))),
                      const SizedBox(height: 10),
                      Text(
                          'لا تقلق، أدخل رقم هاتفك المسجّل وسنرسل لك رمز تحقق لإعادة تعيين كلمة المرور',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 13.5,
                              height: 1.6)),
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
                      const SizedBox(height: 26),
                      _primaryButton(
                          label: 'إرسال رمز التحقق',
                          loading: _isLoading,
                          onPressed: _submit),
                      const SizedBox(height: 18),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios, size: 14),
                          label: const Text('العودة لتسجيل الدخول'),
                        ),
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
// 3) RESET PASSWORD — إدخال رمز التحقق + تعيين كلمة مرور جديدة
// ✅ أصبحت تقبل isAdmin ضمن الـ Map الممرَّرة كـ arguments، وتستخدمها في
// _showSuccessDialog لإعادة توجيه المستخدم إلى شاشة دخول الإدارة تحديداً
// (بدل شاشة تسجيل الدخول العادية) عندما يكون الطلب قادماً من هناك.
// ══════════════════════════════════════════════════════════════════════════
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpKey = GlobalKey<_OtpBoxInputState>();
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _code = '';
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  bool _isResending = false;
  int _secondsLeft = 60;
  Timer? _timer;
  String _phone = '';
  bool _initialized = false;
  // ✅ true عندما يُفتح هذا المسار من "تغيير كلمة المرور" داخل الإعدادات
  // (مستخدم مسجّل دخوله بالفعل) بدل مسار "نسيت كلمة المرور" قبل تسجيل
  // الدخول. يُستخدم لتحديد الوجهة بعد نجاح العملية.
  bool _fromSettings = false;
  // ✅ جديد — true عندما تكون الدورة كلها قادمة من دخول الإدارة (سواء عبر
  // "نسيت كلمة المرور" في AdminLoginScreen). يُستخدم لتحديد ما إذا كانت
  // إعادة التوجيه بعد النجاح يجب أن تذهب إلى شاشة دخول الإدارة بدل شاشة
  // تسجيل الدخول العادية للمستخدمين.
  bool _isAdmin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _phone = args['phone'] as String? ?? '';
        _fromSettings = args['fromSettings'] as bool? ?? false;
        _isAdmin = args['isAdmin'] as bool? ?? false;
      } else {
        _phone = (args as String?) ?? '';
      }
      _initialized = true;
      _startTimer();
    }
  }

  void _startTimer() {
    _secondsLeft = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.length != 6) {
      _showError(context, 'أدخل رمز التحقق كاملاً (6 أرقام)');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final provider = context.read<AppProvider>();
    setState(() => _isSubmitting = true);
    // ✅ مساران مختلفان لنفس الشاشة:
    //  • من الإعدادات (جلسة مفتوحة) → PUT /auth/change-password برمز تحقق
    //    صادر عن POST /auth/change-password/request-otp.
    //  • من "نسيت كلمة المرور" (بلا جلسة) → PUT /auth/reset-password.
    final ok = _fromSettings
        ? await provider.changePassword(
            code: _code,
            newPassword: _newPasswordController.text,
          )
        : await provider.resetPassword(
            phone: _phone,
            code: _code,
            newPassword: _newPasswordController.text,
          );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      _showSuccessDialog();
    } else {
      _showError(
          context,
          provider.errorMessage ??
              'تعذّر تعيين كلمة المرور، تحقق من الرمز وحاول مجدداً');
    }
  }

  Future<void> _resend() async {
    final provider = context.read<AppProvider>();
    setState(() => _isResending = true);
    // ✅ نفس التفريع أعلاه: رمز تغيير كلمة المرور للمستخدم المسجّل دخوله،
    // ورمز الاستعادة لمن لا يملك جلسة.
    final ok = _fromSettings
        ? await provider.requestChangePasswordOtp()
        : await provider.forgotPassword(_phone);
    if (!mounted) return;
    setState(() => _isResending = false);
    if (ok) {
      _otpKey.currentState?.clear();
      setState(() => _code = '');
      _startTimer();
      _showSuccessSnack(context, 'تم إرسال رمز جديد إلى هاتفك');
    } else {
      _showError(
          context, provider.errorMessage ?? 'تعذّر إعادة الإرسال، حاول لاحقاً');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline,
                    color: AppColors.success, size: 34),
              ),
              const SizedBox(height: 16),
              Text('تم تغيير كلمة المرور',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(ctx)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                  _fromSettings
                      ? 'تم تحديث كلمة مرورك بنجاح'
                      : 'يمكنك الآن تسجيل الدخول بكلمة المرور الجديدة',
                  style: TextStyle(
                      color: AppColors.textSecondaryOf(ctx), fontSize: 13.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // ✅ عند تغيير كلمة المرور من داخل الإعدادات (والمستخدم
                    // مسجّل دخوله بالفعل) نعود إلى شاشة الإعدادات بدل
                    // إجباره على الخروج وتسجيل الدخول من جديد، على عكس
                    // مسار "نسيت كلمة المرور" الذي لا يوجد فيه جلسة مفتوحة.
                    if (_fromSettings) {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    } else {
                      // ✅ إن كان الطلب قادماً من دخول الإدارة، نعيد المستخدم
                      // إلى شاشة دخول الإدارة تحديداً بدل شاشة تسجيل الدخول
                      // العادية للمستخدمين.
                      Navigator.pushNamedAndRemoveUntil(
                          context,
                          _isAdmin ? AppRoutes.adminLogin : AppRoutes.login,
                          (_) => false);
                    }
                  },
                  style:
                      ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: Text(_fromSettings ? 'حسناً' : 'تسجيل الدخول'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                  icon: _iconAvatar(Icons.vpn_key_outlined), height: 198),
              _AuthCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('تعيين كلمة مرور جديدة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryOf(context))),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          text: 'أدخل رمز التحقق المرسل إلى\n',
                          style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 13.5,
                              height: 1.6),
                          children: [
                            TextSpan(
                                text: _phone,
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      _OtpBoxInput(
                          key: _otpKey,
                          onChanged: (v) => setState(() => _code = v)),
                      const SizedBox(height: 10),
                      Center(
                        child: _isResending
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : TextButton(
                                onPressed: _secondsLeft == 0 ? _resend : null,
                                child: Text(
                                  _secondsLeft == 0
                                      ? 'إعادة إرسال الرمز'
                                      : 'إعادة الإرسال خلال ${_formatCountdown(_secondsLeft)}',
                                  style: TextStyle(
                                      color: _secondsLeft == 0
                                          ? AppColors.primary
                                          : AppColors.textHintOf(context)),
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Divider(color: AppColors.borderOf(context)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscure,
                        decoration: _fieldDecoration(context,
                            label: 'كلمة المرور الجديدة',
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
                            label: 'تأكيد كلمة المرور الجديدة',
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
                        validator: (v) => v != _newPasswordController.text
                            ? 'كلمتا المرور غير متطابقتين'
                            : null,
                      ),
                      const SizedBox(height: 26),
                      _primaryButton(
                          label: 'تعيين كلمة المرور',
                          loading: _isSubmitting,
                          onPressed: _submit),
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
