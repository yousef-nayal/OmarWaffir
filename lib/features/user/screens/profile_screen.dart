import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_provider.dart';
import '../../../core/constants/app_routes.dart';

// ══════════════════════════════════════════════════════════════════════════
// PROFILE SCREEN
// ✅ إعادة تنظيم شاملة لتطابق مخطط حالات الاستخدام (الحساب والإعدادات):
// شاشة الملف الشخصي أصبحت تحتوي حصرياً على 3 إجراءات فقط:
//   1) تعديل الملف الشخصي  (نافذة تعديل الاسم — انتقلت من UserSettingsScreen)
//   2) الإعدادات           (تفتح UserSettingsScreen، وهي التي تضم الآن كل
//                            بقية العناصر: تغيير الثيم، اللغة، الإشعارات،
//                            كلمة المرور، الموقع، المساعدة والدعم، عن
//                            التطبيق، سياسة الخصوصية، الشروط والأحكام)
//   3) تسجيل الخروج
// أُزيلت من هنا: المساعدة والدعم، عن التطبيق، سياسة الخصوصية، الشروط
// والأحكام — جميعها أصبحت ضمن شاشة الإعدادات فقط (راجع products_screen.dart).
// ══════════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    // ✅ إصلاح: كانت الشاشة تعرض MockData.users.first دائماً بغض النظر عن
    // هوية المستخدم المسجّل فعلياً. الآن تُقرأ الإحصائيات من المستخدم
    // الحالي المخزَّن في AppProvider (يأتي من استجابة تسجيل الدخول/OTP أو
    // GET /auth/me عند استعادة الجلسة).
    final user = provider.currentUser;

    // ✅ إصلاح RTL: هذه الشاشة مسجّلة كمسار مستقل (AppRoutes.profile) في
    // main.dart، وتُستخدم أيضاً كأحد أطفال IndexedStack داخل UserShell.
    // كانت تعتمد فقط على Directionality الذي توفّره UserShell عند الوصول
    // عبر شريط التنقل السفلي؛ أي وصول مباشر لها عبر AppRoutes.profile
    // (Navigator.pushNamed) كان سيُظهرها بلا اتجاه RTL مضمون. التغليف هنا
    // يجعلها صحيحة في كل الحالات بغض النظر عن كيفية الوصول إليها.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Text('الملف الشخصي',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: GestureDetector(
                                  onTap: provider.toggleDarkMode,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Icon(
                                        provider.isDarkMode
                                            ? Icons.light_mode_outlined
                                            : Icons.dark_mode_outlined,
                                        color: Colors.white,
                                        size: 20),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () => _confirmLogout(context, provider),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: const Icon(Icons.logout,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 12)
                            ],
                          ),
                          child: Center(
                            child: Text(
                                provider.userName.isNotEmpty
                                    ? provider.userName[0]
                                    : 'م',
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(provider.userName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(provider.userPhone,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(provider.userLocation,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Stats — من المستخدم الحقيقي بدل MockData.users.first
                  Row(
                    children: [
                      _StatBox(
                          value: '${user?.pricesCount ?? 0}',
                          label: 'أسعار أضفتها',
                          color: AppColors.primary),
                      const SizedBox(width: 10),
                      _StatBox(
                          value: '${user?.ratingsCount ?? 0}',
                          label: 'تقييماتك',
                          color: AppColors.success),
                      const SizedBox(width: 10),
                      _StatBox(
                          value: '${user?.reportsCount ?? 0}',
                          label: 'بلاغاتك',
                          color: AppColors.warning),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // ══════════════════════════════════════════════════════
                  // ✅ الحساب والإعدادات — 3 إجراءات فقط، مطابقة تماماً
                  // لمخطط حالات الاستخدام: تعديل الملف الشخصي، الإعدادات،
                  // تسجيل الخروج. كل ما عدا ذلك انتقل إلى داخل شاشة
                  // الإعدادات (UserSettingsScreen).
                  // ══════════════════════════════════════════════════════
                  const _SectionTitle('الحساب'),
                  _SettingsRow(
                      icon: Icons.person_outline,
                      label: 'تعديل الملف الشخصي',
                      onTap: () => _showEditProfile(context, provider)),
                  _SettingsRow(
                      icon: Icons.settings_outlined,
                      label: 'الإعدادات',
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.userSettings)),
                  const SizedBox(height: 8),
                  _SettingsRow(
                      icon: Icons.logout,
                      label: 'تسجيل الخروج',
                      onTap: () => _confirmLogout(context, provider),
                      isRed: true),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — نافذة "تعديل الملف الشخصي" انتقلت إلى هنا من
  // UserSettingsScreen (products_screen.dart) لأن الملف الشخصي أصبح نقطة
  // الدخول المباشرة لهذا الإجراء حسب مخطط حالات الاستخدام. تُستقبل
  // [context] كوسيط صريح بما أن ProfileScreen هي StatelessWidget.
  // ══════════════════════════════════════════════════════════════════════
  void _showEditProfile(BuildContext context, AppProvider provider) {
    final nameCtrl = TextEditingController(text: provider.userName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('تعديل الملف الشخصي',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'الاسم الكامل',
                        prefixIcon: Icon(Icons.person_outline))),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final navigator = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    if (nameCtrl.text.trim().isEmpty) return;
                    final ok = await provider.updateProfile(
                        name: nameCtrl.text.trim());
                    navigator.pop();
                    messenger.showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'تم تحديث الملف الشخصي'
                            : 'تعذّر التحديث، حاول مجدداً'),
                        backgroundColor:
                            ok ? AppColors.success : AppColors.error));
                  },
                  child: const Text('حفظ'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('خروج',
                    style: TextStyle(color: AppColors.error))),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await provider.logout();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.splash, (_) => false);
    }
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatBox(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
        child: Text(text,
            style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
}

// ══════════════════════════════════════════════════════════════════════════
// ✅ إصلاح RTL: كان ترتيب الأطفال [سهم التنقل، صف(تسمية+أيقونة)] ما يجعل
// السهم يظهر في أقصى اليمين والتسمية في أقصى اليسار — معكوس تماماً. القاعدة
// في RTL: أول عنصر في children يظهر في أقصى اليمين. الآن الترتيب أصبح
// [صف(تسمية+أيقونة)، سهم التنقل]، فتظهر التسمية+الأيقونة يمين والسهم يسار،
// بنفس منطق رأس home_screen.dart الصحيح أصلاً.
// ══════════════════════════════════════════════════════════════════════════
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isRed;
  const _SettingsRow(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.isRed = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderOf(context))),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ✅ التسمية + الأيقونة أولاً → تظهر في أقصى اليمين
                Row(children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isRed
                              ? AppColors.error
                              : AppColors.textPrimaryOf(context))),
                  const SizedBox(width: 10),
                  Icon(icon,
                      size: 20,
                      color: isRed ? AppColors.error : AppColors.primary),
                ]),
                // ✅ سهم التنقل أخيراً → يظهر في أقصى اليسار
                Icon(Icons.arrow_back_ios,
                    size: 14, color: AppColors.textHintOf(context)),
              ]),
        ),
      );
}