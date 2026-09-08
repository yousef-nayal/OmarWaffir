import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/utils/app_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/aleppo_blocks.dart';
import '../../models/models.dart';
import 'package:provider/provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ADMIN SHELL
// ✅ إصلاح جوهري شامل لهذا الملف: كانت كل شاشة إدارية (النظرة العامة،
// مراجعة الأسعار، البلاغات، المستخدمين، المنتجات، المتاجر، المواقع،
// الوحدات، العلامات، الأسعار الرسمية) تقرأ MockData.xxx مباشرة، رغم وجود
// خدمات كاملة وموثّقة (AdminUserService, ReportService, PriceService,
// CatalogService, ProductService, StoreService) لم تكن تُستدعى من أي مكان.
// تبديل AppConfig.useMockData إلى false لم يكن يغيّر شيئاً هنا سابقاً.
// الآن كل شاشة تمر عبر Provider مخصص (راجع core/utils/app_provider.dart)
// يتحول تلقائياً بين البيانات الوهمية والـ backend الحقيقي، بالإضافة إلى
// إجراءات فعلية (موافقة/رفض سعر، حظر مستخدم، توثيق متجر، حذف عنصر...) كانت
// كلها بلا استجابة سابقاً.
//
// ✅ جديد — أُضيف فلتر "الحي" (المنطقة) بجانب فلتر "الكتلة الإدارية"
// الموجود مسبقاً في: إدارة المتاجر، مراجعة الأسعار، إدارة البلاغات،
// وإدارة المواقع. صف فلاتر الأحياء يظهر فقط بعد اختيار كتلة محددة (بنفس
// نمط stores_screen.dart)، ويُعاد ضبطه تلقائياً إلى "الكل" عند تغيير
// الكتلة لمنع بقاء حي لا ينتمي إليها.
//
// ✅ إصلاح شكل الأزرار: زر "حسناً" في نافذة "معلومات الحساب" (وأي حوار
// مشابه) كان ElevatedButton بلا تغليف SizedBox عريض ومع minimumSize(0, 40)
// — القيمة 0 للعرض تجعله ينكمش على حجم النص فقط فيبدو كحبّة ضيقة غير
// احترافية. تم إصلاحه أدناه في _showAccountInfo (راجع نفس الإصلاح في
// profile_screen.dart لشاشتَي "المساعدة والدعم" و"عن التطبيق").
//
// ✅ جديد — أُعيد زر تبديل الثيم (فاتح/داكن) إلى شريط العنوان العلوي
// (AppBar) المشترك في AdminShell، ليظهر في كل شاشات لوحة الإدارة (النظرة
// العامة، مراجعة الأسعار، البلاغات، المستخدمين، المنتجات، المتاجر،
// المواقع، الوحدات، العلامات، الأسعار الرسمية، التحليلات) ما عدا شاشة
// "الإعدادات" (AdminSettingsScreen) تحديداً، لأنها تحتوي أصلاً على عنصر
// تحكم مخصص لنفس الغرض (مفتاح Switch ضمن بطاقة "الوضع الليلي"، راجع
// AdminSettingsScreen._buildBody أدناه)، فلا داعي لتكراره في الأعلى هناك.
//
// ✅ إصلاح جوهري إضافي (بلا أي تغيير في باقي الشاشات): نافذة "إضافة سعر
// رسمي جديد" ضمن AdminOfficialPricesScreen كانت تستقبل اسم منتج ووحدة
// كنصين حرّين (TextField) لا يملكان أي ربط فعلي بجدولي Product/Unit في
// قاعدة البيانات (مخطط قاعدة البيانات الفعلي لجدول OfficialPrice لا يحتوي
// أي عمود نصي لاسم المنتج أو الوحدة، فقط product_id/unit_id). استُبدل ذلك
// بقائمتين منسدلتين تختاران منتجاً/وحدة موجودَين فعلاً، بنفس نمط النافذة
// المطابق تماماً (نفس العنوان، الحقول، الأزرار)، راجع
// AdminOfficialPricesScreen._showAddOfficialPrice أدناه للتفاصيل الكاملة.
//
// ✅ جديد (هذا التحديث) — أُزيل حقل "الوحدة" (القائمة المنسدلة) من نافذة
// "إضافة/تعديل منتج" في AdminProductsScreen._showProductDialog، بناءً على
// طلب صريح. الحقل بقي داخلياً بقيمة ثابتة (existing?.unit ?? 'كغ') لعدم
// كسر استدعاءات ProductProvider.createProduct/updateProduct التي ما زالت
// تتطلب unit كوسيط، لكن لم يعد يظهر أي عنصر واجهة له في النافذة إطلاقاً —
// بلا أي تغيير آخر في باقي الشاشات أو الملفات.
// ══════════════════════════════════════════════════════════════════════════════
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const double _wideBreakpoint = 900;

  bool _sidebarOpen = false; // يُستخدم فقط في وضع الشاشة العريضة
  int _selectedIndex = 0;

  final _labels = [
    'نظرة عامة',
    'مراجعة الأسعار',
    'إدارة البلاغات',
    'إدارة المستخدمين',
    'إدارة المنتجات',
    'إدارة المتاجر',
    'إدارة الكتل والمناطق',
    'إدارة الواحدات',
    'إدارة العلامات التجارية',
    'الأسعار الرسمية',
    'التحليلات والإحصائيات',
    'الإعدادات',
  ];

  final _icons = [
    Icons.dashboard_outlined,
    Icons.attach_money,
    Icons.flag_outlined,
    Icons.people_outlined,
    Icons.inventory_2_outlined,
    Icons.store_outlined,
    Icons.location_on_outlined,
    Icons.tag,
    Icons.label_outlined,
    Icons.description_outlined,
    Icons.bar_chart,
    Icons.settings_outlined,
  ];

  // ✅ فهرس شاشة "الإعدادات" ضمن _labels/_icons — يُستخدم لإخفاء زر تبديل
  // الثيم في شريط العنوان العلوي عندما تكون هذه الشاشة هي المعروضة حالياً،
  // بما أنها تحتوي أصلاً عنصر تحكم مخصص لنفس الغرض.
  static const int _settingsIndex = 11;

  Widget get _currentScreen {
    switch (_selectedIndex) {
      case 0:
        return const AdminDashboard();
      case 1:
        return const AdminPriceReviewScreen();
      case 2:
        return const AdminReportsScreen();
      case 3:
        return const AdminUsersScreen();
      case 4:
        return const AdminProductsScreen();
      case 5:
        return const AdminStoresScreen();
      case 6:
        return const AdminLocationsScreen();
      case 7:
        return const AdminUnitsScreen();
      case 8:
        return const AdminBrandsScreen();
      case 9:
        return const AdminOfficialPricesScreen();
      case 10:
        return const AdminAnalyticsScreen();
      case 11:
        return const AdminSettingsScreen();
      default:
        return const AdminDashboard();
    }
  }

  Widget _sidebarList(bool closeAsDrawer) => Container(
        color: AppColors.surfaceOf(context),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: List.generate(
              _labels.length,
              (i) => SidebarItem(
                icon: _icons[i],
                label: _labels[i],
                isSelected: _selectedIndex == i,
                onTap: () {
                  setState(() {
                    _selectedIndex = i;
                    _sidebarOpen = false;
                  });
                  if (closeAsDrawer) Navigator.pop(context); // يُغلق الـ Drawer
                },
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    // ✅ جديد — نحتاج AppProvider هنا لعرض وتبديل حالة الوضع الداكن عبر
    // الزر المُعاد في شريط العنوان العلوي.
    final appProvider = context.watch<AppProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('وفّر - لوحة الإدارة'),
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => isWide
                  ? setState(() => _sidebarOpen = !_sidebarOpen)
                  : Scaffold.of(ctx).openDrawer(),
            ),
          ),
          // ══════════════════════════════════════════════════════════════
          // ✅ جديد — زر تبديل الثيم (فاتح/داكن) في شريط العنوان العلوي،
          // يظهر في كل شاشات لوحة الإدارة ما عدا شاشة "الإعدادات" (فهرسها
          // _settingsIndex) لأنها تحتوي على عنصر تحكم مخصص لنفس الغرض
          // (Switch ضمن بطاقة "الوضع الليلي").
          // ══════════════════════════════════════════════════════════════
          actions: _selectedIndex == _settingsIndex
              ? null
              : [
                  IconButton(
                    icon: Icon(
                      appProvider.isDarkMode
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    tooltip: appProvider.isDarkMode
                        ? 'الوضع الفاتح'
                        : 'الوضع الداكن',
                    onPressed: appProvider.toggleDarkMode,
                  ),
                  const SizedBox(width: 4),
                ],
        ),
        drawer: isWide ? null : Drawer(child: _sidebarList(true)),
        body: isWide
            ? Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: _sidebarOpen ? 220 : 0,
                    child: _sidebarOpen ? _sidebarList(false) : null,
                  ),
                  if (_sidebarOpen) const VerticalDivider(width: 1),
                  Expanded(child: _currentScreen),
                ],
              )
            : _currentScreen,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// رأس متدرّج مشترك
// ══════════════════════════════════════════════════════════════════════════════
class _AdminGradientHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  // ✅ جديد — زر إجراء ثانوي اختياري (مثال: "تعديل الكتل" بجانب "إضافة
  // موقع" في شاشة إدارة المواقع). يُعرض بتصميم مفرّغ (outline) أبيض ليتمايز
  // بصرياً عن الزر الأساسي الأبيض المملوء، مع الحفاظ على نفس ارتفاع وشكل
  // الزوايا.
  final String? secondaryActionLabel;
  final IconData? secondaryActionIcon;
  final VoidCallback? onSecondaryAction;

  const _AdminGradientHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.secondaryActionIcon,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            // ══════════════════════════════════════════════════════════
            // ✅ محدَّث — الصف الآن يستوعب زرّاً ثانوياً اختيارياً بجانب
            // الزر الأساسي، بدل Align وحيد لعنصر واحد. الزر الأساسي يبقى
            // أقصى اليسار كما كان تماماً، والزر الثانوي (إن وُجد) يظهر إلى
            // يمينه مباشرة بنفس الصف وبنفس الارتفاع، بتصميم مفرّغ (حدود
            // بيضاء شفافة، بلا تعبئة) ليكون تمييزه البصري كـ"إجراء ثانوي"
            // واضحاً فوراً دون منافسة الزر الأساسي على الانتباه.
            // ══════════════════════════════════════════════════════════
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onAction,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel!,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.add, color: AppColors.primary, size: 18),
                        ],
                      ),
                    ),
                  ),
                  if (secondaryActionLabel != null) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onSecondaryAction,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              secondaryActionLabel!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              secondaryActionIcon ?? Icons.edit_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DASHBOARD
// ✅ يقرأ من CatalogProvider.dashboardStats/recentActivity حصراً.
//
// ✅ إصلاح جوهري — كانت الشاشة تعرض MockData.dashboardStats/recentActivity
// تلقائياً كلما كانت بيانات CatalogProvider فارغة، وهذا يحدث في حالتين
// خطيرتين في وضع الإنتاج (AppConfig.useMockData = false):
//   1) أثناء التحميل الفعلي من الخادم (بين لحظة فتح الشاشة ووصول الرد) —
//      كانت اللوحة تعرض أرقاماً وهمية ثابتة (1248 مستخدم، 856 منتج...)
//      وكأنها بيانات حقيقية، قبل أن تُستبدَل فجأة بالأرقام الفعلية.
//   2) إن أعاد الخادم فعلياً بيانات فارغة (نظام جديد بلا مستخدمين مثلاً) —
//      كانت اللوحة تستمر بعرض الأرقام الوهمية إلى الأبد بدل إظهار "0" أو
//      حالة فارغة صريحة، ما يضلّل المسؤول تماماً حول الحالة الحقيقية للنظام.
//
// الإصلاح: حالة تحميل محلية صريحة (_initialLoading) تُظهر مؤشر تحميل حتى
// اكتمال أول طلب فعلي، ثم تُعرض البيانات الحقيقية أياً كانت (حتى لو صفراً)
// بلا أي رجوع لبيانات وهمية على الإطلاق. القيم المفقودة تُعرض كـ'—' بدل
// النص الحرفي "null" (بنفس نمط AdminAnalyticsScreen أدناه في هذا الملف).
//
// ✅ دمج — بطاقات الإحصائيات الخمس في هذه الشاشة تحديداً ("نظرة عامة") لا
// تعرض أي شارة نسبة مئوية (growth) بطلب مباشر سابق، بخلاف نفس البطاقات في
// AdminAnalyticsScreen أدناه في هذا الملف والتي أبقيت شارة النمو (تُعرض فقط
// إن توفّرت قيمتها فعلياً من الخادم، عبر شرط != null الذي أضافه هذا الدمج).
// ══════════════════════════════════════════════════════════════════════════════
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // ✅ true حتى اكتمال أول تحميل فعلي (نجاحاً أو فشلاً)، لمنع أي "وميض"
  // لبيانات فارغة أو تسرّع بعرض حالة خطأ قبل أن يُتاح للطلب وقت للاستجابة.
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final catalog = context.read<CatalogProvider>();
      await Future.wait([
        catalog.loadDashboardStats(),
        catalog.loadRecentActivity(),
      ]);
      if (mounted) setState(() => _initialLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final stats = catalog.dashboardStats;
    final activity = catalog.recentActivity;

    // ✅ مؤشر تحميل صريح بدل عرض أي بيانات وهمية أثناء انتظار الرد الفعلي
    if (_initialLoading) {
      return ListView(
        padding: EdgeInsets.zero,
        children: const [
          _AdminGradientHeader(
            title: 'نظرة عامة',
            subtitle: 'ملخص إحصائيات النظام',
            icon: Icons.dashboard_outlined,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _AdminGradientHeader(
          title: 'نظرة عامة',
          subtitle: 'ملخص إحصائيات النظام',
          icon: Icons.dashboard_outlined,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              StatCard(
                icon: Icons.people_outlined,
                iconColor: Colors.blue,
                iconBg: Colors.blue.withValues(alpha: 0.1),
                value: '${stats['totalUsers'] ?? '—'}',
                label: 'إجمالي المستخدمين',
              ),
              const SizedBox(height: 10),
              StatCard(
                icon: Icons.inventory_2_outlined,
                iconColor: Colors.green,
                iconBg: Colors.green.withValues(alpha: 0.1),
                value: '${stats['totalProducts'] ?? '—'}',
                label: 'إجمالي المنتجات',
              ),
              const SizedBox(height: 10),
              StatCard(
                icon: Icons.store_outlined,
                iconColor: Colors.purple,
                iconBg: Colors.purple.withValues(alpha: 0.1),
                value: '${stats['totalStores'] ?? '—'}',
                label: 'إجمالي المتاجر',
              ),
              const SizedBox(height: 10),
              StatCard(
                icon: Icons.attach_money,
                iconColor: Colors.orange,
                iconBg: Colors.orange.withValues(alpha: 0.1),
                value: '${stats['totalPrices'] ?? '—'}',
                label: 'إجمالي الأسعار',
              ),
              const SizedBox(height: 10),
              StatCard(
                icon: Icons.flag_outlined,
                iconColor: Colors.red,
                iconBg: Colors.red.withValues(alpha: 0.1),
                value: '${stats['totalReports'] ?? '—'}',
                label: 'إجمالي البلاغات',
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'النشاط الأخير',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ✅ حالة فارغة صريحة بدل بيانات وهمية عندما لا يوجد أي نشاط
              // فعلي بعد (نظام جديد، أو خادم لم يُسجّل أي حدث بعد).
              if (activity.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Center(
                    child: Text(
                      'لا يوجد نشاط حديث بعد',
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Column(
                    children: activity.map((a) {
                      final colorMap = {
                        'blue': AppColors.primary,
                        'red': AppColors.error,
                        'green': AppColors.success,
                        'purple': Colors.purple,
                      };
                      final color = colorMap[a['color']] ?? AppColors.primary;
                      return ListTile(
                        leading: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          a['text'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimaryOf(context),
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        subtitle: Text(
                          a['time'] ?? '',
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 11,
                          ),
                        ),
                        subtitleTextStyle: const TextStyle(),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PRICE REVIEW SCREEN
// ✅ الآن يقرأ من PriceProvider.loadAdminPrices() وتوجد أزرار موافقة/رفض
// فعلية تستدعي PriceProvider.deletePrice() (كانت الشاشة سابقاً جدولاً للعرض فقط
// بلا أي إجراء).
// ✅ جديد — فلتر الحي بجانب فلتر الكتلة الإدارية، يظهر فقط بعد اختيار كتلة.
//
// ✅ محدَّث (هذا التحديث) — أُزيل فلتر "الكل/مشهورة" العلوي بالكامل (كان صف
// Chips فرعياً لفرز العرض حسب عدد التقييمات فقط، بلا أي دلالة إدارية فعلية)
// بناءً على طلب صريح — أُزيل الحقل _filter وFilterChipRow المرتبط به ومنطق
// الفرز (sort حسب totalRatings) بالكامل من هذه الشاشة تحديداً، بلا أي تأثير
// على باقي الشاشات الإدارية الأخرى التي تستخدم FilterChipRow. كما أصبح
// تنسيق عرض السعر موحّداً مع بقية شاشات التطبيق (فاصلة آلاف بعد كل 3 أرقام،
// مثال: 45,000 ل.س بدل 45000 ل.س سابقاً) عبر دالة تنسيق محلية جديدة
// _formatPrice، وأُضيف تاريخ إضافة السعر (PriceEntry.submittedAt، والذي
// يطابق عمود created_at الفعلي في جدول Price بقاعدة البيانات) كشارة صغيرة
// بأيقونة تقويم أسفل كل بطاقة سعر، بنفس أسلوب شارة الكتلة/الحي الموجودة
// أصلاً، بلا أي تغيير في مصدر البيانات نفسه.
// ══════════════════════════════════════════════════════════════════════════════
class AdminPriceReviewScreen extends StatefulWidget {
  const AdminPriceReviewScreen({super.key});
  @override
  State<AdminPriceReviewScreen> createState() => _AdminPriceReviewScreenState();
}

class _AdminPriceReviewScreenState extends State<AdminPriceReviewScreen> {
  // ✅ فلتر الكتلة الإدارية، يُشتق تصنيف كل سعر تلقائياً من حقل
  // e.storeArea الموجود أصلاً في PriceEntry عبر AleppoBlocks.blockOfArea
  // (بلا حاجة لتعديل الـ model أو الـ backend).
  String _blockFilter = 'الكل';
  // ✅ جديد — فلتر الحي، يظهر فقط بعد اختيار كتلة إدارية محددة، ويُعاد
  // ضبطه تلقائياً إلى "الكل" كلما تغيّرت الكتلة.
  String _areaFilter = 'الكل';
  // ✅ جديد — فلتر العلامة التجارية. يُطبَّق على حقل PriceEntry.brand
  // مقارنةً بقائمة العلامات التجارية الحقيقية المُحمَّلة من الخادم عبر
  // CatalogProvider (نفس مصدر البيانات المستخدم في AddPriceScreen وشاشة
  // "إدارة العلامات التجارية")، بدل الاعتماد على نص حر أو قائمة ثابتة قد
  // لا تطابق العلامات الفعلية المُدخَلة مع الأسعار.
  String _brandFilter = 'الكل';
  // ✅ جديد — نص البحث، يُطبَّق محلياً على اسم المنتج/المتجر/المستخدم
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PriceProvider>().loadAdminPrices();
      // ✅ جديد — تحميل قائمة العلامات التجارية الحقيقية (إن لم تكن
      // محمَّلة أصلاً من شاشة أخرى) لاستخدامها في فلتر العلامة التجارية
      // الجديد أدناه.
      final catalog = context.read<CatalogProvider>();
      if (catalog.brands.isEmpty) catalog.loadBrands();
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري — حلّت محل _review(approve/reject). جدول Price لا
  // يحتوي عمود status، ومخطط حالات الاستخدام يُدرج "حذف السعر" صراحة
  // كالإجراء الإداري الوحيد ضمن "مراجعة الأسعار". يُطلب تأكيد صريح قبل
  // الحذف بما أنه إجراء نهائي لا رجعة فيه.
  // ══════════════════════════════════════════════════════════════════════
  Future<void> _deletePrice(PriceEntry e) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف السعر',
      message: 'هل تريد حذف سعر "${e.productName}" نهائياً؟',
      confirmText: 'حذف',
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<PriceProvider>().deletePrice(e.id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم حذف السعر' : 'تعذّر حذف السعر'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  // ✅ جديد — تنسيق موحّد للسعر بفاصلة آلاف (مثال: 45,000 ل.س)، بنفس منطق
  // الدوال المحلية المتكررة في home_screen.dart/products_screen.dart
  // (_f)/official_price_history_screen.dart (_fmtPrice)، بلا أي تغيير في
  // القيمة الرقمية نفسها — تنسيق العرض فقط.
  String _formatPrice(double v) {
    final rounded = v.round();
    final str = rounded.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  // ✅ جديد — تنسيق تاريخ إضافة السعر (PriceEntry.submittedAt، يطابق عمود
  // Price.created_at الفعلي في قاعدة البيانات المرفقة)، بنفس نمط _fmtDate
  // في official_price_history_screen.dart.
  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final priceProvider = context.watch<PriceProvider>();
    var entries = priceProvider.entries;
    if (_search.trim().isNotEmpty) {
      final q = _search.trim();
      entries = entries
          .where(
            (e) =>
                e.productName.contains(q) ||
                e.storeName.contains(q) ||
                e.submittedBy.contains(q),
          )
          .toList();
    }
    if (_blockFilter != 'الكل') {
      entries = entries
          .where(
            (e) => AleppoBlocks.blockOfArea(e.storeArea)?.name == _blockFilter,
          )
          .toList();
    }
    // ✅ جديد — فلترة إضافية حسب الحي المحدد
    if (_areaFilter != 'الكل') {
      entries = entries.where((e) => e.storeArea == _areaFilter).toList();
    }
    // ✅ جديد — فلترة إضافية حسب العلامة التجارية المحددة
    if (_brandFilter != 'الكل') {
      entries = entries.where((e) => e.brand == _brandFilter).toList();
    }
    // ✅ جديد — أسماء العلامات التجارية الحقيقية المُحمَّلة من الخادم،
    // تُستخدَم كخيارات فلتر العلامة التجارية أدناه.
    final brandNames =
        context.watch<CatalogProvider>().brands.map((b) => b.name).toList();

    return Column(
      children: [
        const _AdminGradientHeader(
          title: 'مراجعة الأسعار',
          subtitle: 'راجع الأسعار المقدمة من المستخدمين واحذف غير الصحيح منها',
          icon: Icons.attach_money,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ إصلاح — كان حقل البحث زخرفياً بلا onChanged؛ أصبح الآن
              // مربوطاً فعلياً بفلترة القائمة محلياً.
              WaffirSearchField(
                hint: 'ابحث عن منتج، متجر أو مستخدم...',
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 10),
              // فلتر الكتلة الإدارية
              FilterChipRow(
                options: ['الكل', ...AleppoBlocks.blockNames],
                selected: _blockFilter,
                onSelected: (v) => setState(() {
                  _blockFilter = v;
                  // ✅ إعادة ضبط فلتر الحي تلقائياً عند تغيير الكتلة
                  _areaFilter = 'الكل';
                }),
              ),
              // ✅ جديد — صف فلترة الحي (يظهر فقط بعد اختيار كتلة محددة)
              if (_blockFilter != 'الكل') ...[
                const SizedBox(height: 8),
                FilterChipRow(
                  options: ['الكل', ...AleppoBlocks.areasOfBlock(_blockFilter)],
                  selected: _areaFilter,
                  onSelected: (v) => setState(() => _areaFilter = v),
                ),
              ],
              // ══════════════════════════════════════════════════════════
              // ✅ جديد — فلتر العلامة التجارية. يظهر دائماً (بلا شرط
              // اختيار كتلة، على خلاف فلتر الحي أعلاه) طالما توجد علامات
              // تجارية مُحمَّلة فعلياً من الخادم، ويعتمد نفس تصميم بقية
              // صفوف الفلترة في هذه الشاشة (FilterChipRow).
              // ══════════════════════════════════════════════════════════
              if (brandNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                FilterChipRow(
                  options: ['الكل', ...brandNames],
                  selected: _brandFilter,
                  onSelected: (v) => setState(() => _brandFilter = v),
                ),
              ],
              // ══════════════════════════════════════════════════════════
              // ✅ أُزيل هنا نهائياً صف فلتر "الكل/مشهورة" (كان FilterChipRow
              // ثانياً بخيارين فقط لفرز العرض حسب عدد التقييمات، بلا أي
              // دلالة إدارية فعلية) بناءً على طلب صريح، بالإضافة إلى الحقل
              // _filter ومنطق الفرز المرتبط به بالكامل.
              // ══════════════════════════════════════════════════════════
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: priceProvider.isLoading && entries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : entries.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد أسعار مطابقة',
                        style: TextStyle(
                            color: AppColors.textSecondaryOf(context)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: entries.length,
                      itemBuilder: (ctx, i) {
                        final e = entries[i];
                        final block =
                            AleppoBlocks.blockOfArea(e.storeArea)?.name;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceOf(context),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppColors.borderOf(context)),
                          ),
                          child: Column(
                            children: [
                              // ══════════════════════════════════════════
                              // ✅ إعادة تصميم احترافية — كانت هذه البطاقة
                              // تضع السعر أولاً (فيظهر أقصى اليمين في RTL)
                              // واسم المنتج ثانياً (فيظهر أقصى اليسار) —
                              // عكس التسلسل الطبيعي المتوقَّع في واجهة
                              // عربية (الكلام/الاسم يمين، الرقم/السعر
                              // يسار). الآن: اسم المنتج (مع شارة العلامة
                              // التجارية أسفله إن وُجدت) أصبح أول عنصر في
                              // الصف فيظهر أقصى اليمين ويأخذ المساحة
                              // المرنة (Expanded) لمنع أي فيضان نص، والسعر
                              // انتقل إلى بطاقة مميّزة (pill) بخلفية ملوّنة
                              // في أقصى اليسار، ليكون أوضح بصرياً كرقم
                              // مستقل بدل نص عادي مجاور.
                              // ══════════════════════════════════════════
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.productName,
                                          textAlign: TextAlign.right,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimaryOf(
                                                context),
                                          ),
                                        ),
                                        if (e.brand.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  AppColors.textHint.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                6,
                                              ),
                                            ),
                                            child: Text(
                                              e.brand,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    AppColors.textSecondaryOf(
                                                  context,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // ✅ بطاقة السعر (pill) — تنسيق بفاصلة
                                  // آلاف عبر _formatPrice، مع "ل.س" كوحدة
                                  // ثانوية أصغر أسفل الرقم.
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatPrice(e.price),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const Text(
                                          'ل.س',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${e.quantity.toStringAsFixed(0)} ${e.unit}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryOf(context),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      '${e.storeName} — بواسطة ${e.submittedBy}',
                                      textAlign: TextAlign.left,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            AppColors.textSecondaryOf(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // ══════════════════════════════════════════
                              // ✅ جديد — صف الشارات: شارة الكتلة/الحي (إن
                              // وُجدت) وشارة تاريخ الإضافة معاً داخل Wrap
                              // مرن، فلا تفيضان عن عرض الشاشة مهما طال اسم
                              // الحي. تاريخ الإضافة مصدره
                              // PriceEntry.submittedAt (يطابق عمود
                              // Price.created_at الفعلي في قاعدة البيانات).
                              // ══════════════════════════════════════════
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (block != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          e.storeArea.isEmpty
                                              ? block
                                              : '$block — ${e.storeArea}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.textHint.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.calendar_today_outlined,
                                            size: 11,
                                            color: AppColors.textSecondaryOf(
                                              context,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDate(e.submittedAt),
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: AppColors.textSecondaryOf(
                                                context,
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              // ✅ إصلاح جوهري — زر "حذف السعر" فقط، بدل
                              // موافقة/رفض السابقين اللذين افترضا عمود status
                              // غير موجود فعلياً في جدول Price.
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _deletePrice(e),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: AppColors.error,
                                  ),
                                  label: const Text(
                                    'حذف السعر',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: AppColors.error),
                                    minimumSize: const Size(0, 38),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REPORTS SCREEN
// يعرض البلاغات من ReportProvider، مع فلترة الحالة والموقع والنوع، وتفاصيل
// كاملة وإجراء قابل للتراجع لتحديد البلاغ كمُعالَج دون حذفه.
// ══════════════════════════════════════════════════════════════════════════════
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _filter = 'الكل';
  String _blockFilter = 'الكل';
  String _areaFilter = 'الكل';
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadReports();
    });
  }

  String _typeLabel(String t) {
    switch (t) {
      case ReportType.overpriced:
        return 'سعر\nمبالغ فيه';
      case ReportType.wrongPrice:
        return 'سعر\nغير صحيح';
      case ReportType.wrongInfo:
        return 'معلومات\nغير صحيحة';
      default:
        return t;
    }
  }

  Color _typeColor(String t) {
    switch (t) {
      case ReportType.overpriced:
        return AppColors.warning;
      case ReportType.wrongPrice:
        return AppColors.error;
      case ReportType.wrongInfo:
        return Colors.blue;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case ReportType.overpriced:
        return Icons.warning_amber_outlined;
      case ReportType.wrongPrice:
        return Icons.price_change_outlined;
      case ReportType.wrongInfo:
        return Icons.info_outline;
      default:
        return Icons.flag_outlined;
    }
  }

  String _formatPrice(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }

  String _formatReportPriceDetail(ReportModel report) {
    final priceStr = '${_formatPrice(report.price!)} ل.س';
    final hasQty = report.quantity != null && report.quantity! > 0;
    final hasUnit = report.unit != null && report.unit!.isNotEmpty;

    if (hasQty && hasUnit) {
      final quantity = report.quantity! % 1 == 0
          ? report.quantity!.toStringAsFixed(0)
          : report.quantity!.toStringAsFixed(1);
      return '$priceStr  •  $quantity ${report.unit}';
    }
    if (hasUnit) return '$priceStr / ${report.unit}';
    return priceStr;
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime date) =>
      '${_formatDate(date)} — ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> _deleteReport(ReportModel report) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف البلاغ',
      message: 'هل تريد حذف البلاغ عن "${report.productName}" نهائياً؟',
      confirmText: 'حذف',
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<ReportProvider>().deleteReport(report.id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم حذف البلاغ' : 'تعذّر حذف البلاغ'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  void _showReportDetail(ReportModel report) {
    final block = AleppoBlocks.blockOfArea(report.storeArea)?.name;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderOf(sheetContext),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _typeColor(report.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_typeIcon(report.type),
                        color: _typeColor(report.type), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.productName,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryOf(sheetContext))),
                        const SizedBox(height: 2),
                        Text(report.storeName,
                            style: TextStyle(
                                color: AppColors.textSecondaryOf(sheetContext),
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: _ReportInfoBadge(
                  text: _typeLabel(report.type).replaceAll('\n', ' '),
                  color: _typeColor(report.type),
                ),
              ),
              const Divider(height: 28),
              if (report.price != null)
                _ReportDetailRow(
                  icon: Icons.attach_money,
                  label: 'السعر المُبلَّغ عنه',
                  value: _formatReportPriceDetail(report),
                ),
              _ReportDetailRow(
                  icon: Icons.storefront_outlined,
                  label: 'المتجر',
                  value: report.storeName),
              if (report.storeArea.isNotEmpty)
                _ReportDetailRow(
                    icon: Icons.map_outlined,
                    label: 'المنطقة',
                    value: report.storeArea),
              if (block != null)
                _ReportDetailRow(
                    icon: Icons.location_city_outlined,
                    label: 'الكتلة الإدارية',
                    value: block),
              _ReportDetailRow(
                  icon: Icons.person_outline,
                  label: 'بلّغ عنه',
                  value: report.userName),
              _ReportDetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'تاريخ البلاغ',
                  value: _formatDateTime(report.reportedAt)),
              if (report.description != null && report.description!.isNotEmpty)
                _ReportDetailRow(
                    icon: Icons.notes_outlined,
                    label: 'التوضيح',
                    value: report.description!),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _deleteReport(report);
                  },
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.error),
                  label: const Text('حذف البلاغ',
                      style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: AppColors.error),
                  ),
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
    final reportProvider = context.watch<ReportProvider>();
    var reports = _filter == 'الكل'
        ? reportProvider.reports
        : reportProvider.reports.where((r) => r.type == _filter).toList();
    if (_search.trim().isNotEmpty) {
      final q = _search.trim();
      reports = reports
          .where(
            (r) =>
                r.productName.contains(q) ||
                r.storeName.contains(q) ||
                r.userName.contains(q),
          )
          .toList();
    }
    if (_blockFilter != 'الكل') {
      reports = reports
          .where(
            (r) => AleppoBlocks.blockOfArea(r.storeArea)?.name == _blockFilter,
          )
          .toList();
    }
    // ✅ جديد — فلترة إضافية حسب الحي المحدد
    if (_areaFilter != 'الكل') {
      reports = reports.where((r) => r.storeArea == _areaFilter).toList();
    }

    return Column(
      children: [
        const _AdminGradientHeader(
          title: 'إدارة البلاغات',
          subtitle: 'راجع البلاغات المقدمة من المستخدمين',
          icon: Icons.flag_outlined,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ إصلاح — كان حقل البحث زخرفياً بلا onChanged
              WaffirSearchField(
                hint: 'ابحث عن منتج، متجر أو مستخدم...',
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 10),
              // فلتر الكتلة الإدارية
              FilterChipRow(
                options: ['الكل', ...AleppoBlocks.blockNames],
                selected: _blockFilter,
                onSelected: (v) => setState(() {
                  _blockFilter = v;
                  // ✅ إعادة ضبط فلتر الحي تلقائياً عند تغيير الكتلة
                  _areaFilter = 'الكل';
                }),
              ),
              // ✅ جديد — صف فلترة الحي (يظهر فقط بعد اختيار كتلة محددة)
              if (_blockFilter != 'الكل') ...[
                const SizedBox(height: 8),
                FilterChipRow(
                  options: ['الكل', ...AleppoBlocks.areasOfBlock(_blockFilter)],
                  selected: _areaFilter,
                  onSelected: (v) => setState(() => _areaFilter = v),
                ),
              ],
              const SizedBox(height: 8),
              FilterChipRow(
                options: const ['الكل', ...ReportType.all],
                selected: _filter,
                onSelected: (v) => setState(() => _filter = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: reportProvider.isLoading && reports.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : reports.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد بلاغات مطابقة',
                        style: TextStyle(
                            color: AppColors.textSecondaryOf(context)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: reports.length,
                      itemBuilder: (ctx, i) {
                        final r = reports[i];
                        final block =
                            AleppoBlocks.blockOfArea(r.storeArea)?.name;
                        return GestureDetector(
                          onTap: () => _showReportDetail(r),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceOf(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.borderOf(context)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _typeColor(
                                          r.type,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _typeLabel(r.type),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _typeColor(r.type),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${r.productName} — ${r.storeName}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'بلّغ عنه: ${r.userName}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondaryOf(
                                                context,
                                              ),
                                            ),
                                          ),
                                          if (r.description != null &&
                                              r.description!.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Text(
                                                r.description!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                  color:
                                                      AppColors.textSecondaryOf(
                                                    context,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.arrow_back_ios,
                                        size: 13,
                                        color: AppColors.textHintOf(context)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (block != null)
                                        _ReportInfoBadge(
                                          text: r.storeArea.isEmpty
                                              ? block
                                              : '$block — ${r.storeArea}',
                                          color: AppColors.primary,
                                        ),
                                      _ReportInfoBadge(
                                        text: _formatDate(r.reportedAt),
                                        color:
                                            AppColors.textSecondaryOf(context),
                                        icon: Icons.calendar_today_outlined,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _deleteReport(r),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16, color: AppColors.error),
                                    label: const Text('حذف البلاغ',
                                        style:
                                            TextStyle(color: AppColors.error)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: AppColors.error),
                                      minimumSize: const Size(0, 38),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _ReportInfoBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _ReportInfoBadge({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
            ],
            Text(text,
                style: TextStyle(
                    fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _ReportDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ReportDetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: AppColors.textPrimaryOf(context)),
                  textAlign: TextAlign.right),
            ),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: AppColors.textSecondaryOf(context), fontSize: 13)),
            const SizedBox(width: 8),
            Icon(icon, size: 18, color: AppColors.primary),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// USERS SCREEN
// ✅ إعادة تصميم جوهرية بناءً على طلب صريح:
//   1) فلترة حسب المنطقة — أُضيف فلتر الكتلة الإدارية ثم الحي (بنفس نمط
//      AdminStoresScreen/AdminReportsScreen)، وأصبحت كل بطاقة مستخدم تعرض
//      شارة توضح الكتلة/المنطقة التي اختارها ذلك المستخدم. المصدر هو
//      UserModel.location المخزَّن بصيغة "الكتلة X - المنطقة" (راجع
//      AppProvider._setUser وMockData.users)، يُحلَّل عبر _blockOfUser/
//      _areaOfUser أدناه بلا أي حاجة لتعديل الـ model أو الـ backend.
//   2) أُزيل المدراء نهائياً من هذه الشاشة — أصبحت مخصّصة حصراً لعرض
//      وإدارة المستخدمين العاديين (role == 'user'). إدارة حسابات المدراء
//      انتقلت بالكامل إلى شاشتها المستقلة (AdminAdminsScreen، تُفتح من
//      "إدارة المسؤولين" ضمن الإعدادات) قبل هذا التحديث بالفعل، فلم يعد
//      هناك أي داعٍ لعرضهم أو لإتاحة ترقية/تخفيض دور من هنا؛ شارة "مدير/
//      مستخدم" وحدود البطاقة الحمراء الخاصة بالحظر أُزيلتا تبعاً لذلك.
//   3) أُزيلت ميزة الحظر بالكامل — لا زر حظر/رفع حظر، ولا شارة "محظور"،
//      ولا أي اعتماد على UserModel.isActive في هذه الشاشة.
//   4) تعديل بيانات المستخدم أصبح يغطي الاسم ورقم الهاتف وكلمة مرور جديدة
//      اختيارية معاً في نافذة واحدة (بنفس نمط نافذة "تعديل معلومات
//      المسؤول" في AdminAdminsScreen أدناه في هذا الملف)، بدل الاسم فقط
//      كما كان سابقاً. AdminUsersProvider.updateUser يدعم أصلاً phone/
//      password اختياريين (راجع app_provider.dart)، فلا حاجة لأي تعديل
//      على طبقة الـ Provider أو الخدمة.
// ══════════════════════════════════════════════════════════════════════════════
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  // ✅ جديد — فلتر الكتلة الإدارية، وفلتر الحي (يظهر فقط بعد اختيار كتلة
  // محددة، ويُعاد ضبطه تلقائياً إلى "الكل" عند تغيير الكتلة)، بنفس نمط
  // بقية شاشات لوحة الإدارة (AdminStoresScreen، AdminReportsScreen...).
  String _blockFilter = 'الكل';
  String _areaFilter = 'الكل';
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUsersProvider>().loadUsers();
      final catalog = context.read<CatalogProvider>();
      if (catalog.locations.isEmpty) catalog.loadLocations();
    });
  }

  // تنسيق تاريخ إنشاء الحساب (UserModel.createdAt، يطابق عمود
  // User.created_at الفعلي في قاعدة البيانات). يُعيد '—' عند غياب القيمة.
  String _formatCreatedAt(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — استخراج الكتلة الإدارية واسم المنطقة من UserModel.location،
  // المخزَّن بصيغة موحّدة "الكتلة الخامسة - الفرقان" (راجع
  // AppProvider._setUser وRegisterScreen). يُعيدان null إن تعذّر التحليل
  // (مستخدم قديم بلا هذه الصيغة مثلاً) بدل كسر الفلترة أو العرض.
  // ══════════════════════════════════════════════════════════════════════
  String? _blockOfUser(UserModel u) {
    if (!u.location.contains(' - ')) return null;
    final parts = u.location.split(' - ');
    if (parts.isEmpty || parts.first.trim().isEmpty) return null;
    return parts.first.trim();
  }

  String? _areaOfUser(UserModel u) {
    if (!u.location.contains(' - ')) return null;
    final parts = u.location.split(' - ');
    if (parts.length < 2) return null;
    final area = parts.sublist(1).join(' - ').trim();
    return area.isEmpty ? null : area;
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ محدَّث بالكامل — نافذة "تعديل بيانات المستخدم" أصبحت تضم 3 حقول:
  // الاسم الكامل، رقم الهاتف (بتحقق أساسي)، وكلمة مرور جديدة اختيارية
  // (تُترك فارغة لإبقاء كلمة المرور الحالية دون أي تغيير)، بنفس نمط ونفس
  // رسائل التحقق المعتمدة في نافذة "تعديل معلومات المسؤول"
  // (AdminAdminsScreen._showEditAdmin أدناه في هذا الملف)، لضمان اتساق
  // تجربة الاستخدام بين الشاشتين.
  // ══════════════════════════════════════════════════════════════════════
  void _showEditUser(UserModel u) {
    final nameCtrl = TextEditingController(text: u.name);
    final phoneCtrl = TextEditingController(text: u.phone);
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;
    String? nameError;
    String? phoneError;
    String? passwordError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'تعديل بيانات المستخدم',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الاسم الكامل', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    textDirection: TextDirection.rtl,
                    onChanged: (v) {
                      if (nameError != null) {
                        setDialogState(() => nameError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'اسم المستخدم',
                      errorText: nameError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('رقم الهاتف', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    onChanged: (v) {
                      if (phoneError != null) {
                        setDialogState(() => phoneError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'مثال: 0944123456',
                      hintStyle: TextStyle(
                        color: AppColors.textHintOf(ctx),
                        fontSize: 12.5,
                      ),
                      errorText: phoneError,
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'كلمة مرور جديدة (اختياري)',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: obscurePassword,
                    textDirection: TextDirection.ltr,
                    onChanged: (v) {
                      if (passwordError != null) {
                        setDialogState(() => passwordError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'اتركه فارغاً لعدم تغيير كلمة المرور',
                      hintStyle: TextStyle(
                        color: AppColors.textHintOf(ctx),
                        fontSize: 12.5,
                      ),
                      errorText: passwordError,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: AppColors.textHintOf(ctx),
                        ),
                        onPressed: () => setDialogState(
                          () => obscurePassword = !obscurePassword,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          setDialogState(
                            () => nameError = 'أدخل اسم المستخدم',
                          );
                          return;
                        }
                        final newPhone = phoneCtrl.text.trim();
                        if (newPhone.isEmpty || newPhone.length < 8) {
                          setDialogState(
                            () => phoneError = 'أدخل رقم هاتف صحيح',
                          );
                          return;
                        }
                        final newPassword = passwordCtrl.text.trim();
                        if (newPassword.isNotEmpty && newPassword.length < 6) {
                          setDialogState(
                            () => passwordError =
                                'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
                          );
                          return;
                        }
                        final navigator = Navigator.of(ctx);
                        final ok =
                            await context.read<AdminUsersProvider>().updateUser(
                                  u.id,
                                  name: nameCtrl.text.trim(),
                                  phone: newPhone,
                                  password:
                                      newPassword.isEmpty ? null : newPassword,
                                );
                        navigator.pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'تم تحديث البيانات' : 'تعذّر التحديث',
                            ),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.error,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        ),
      ),
    );
  }

  /// إضافة مستخدم جديد مباشرة من لوحة الإدارة. يستخدم نفس منتقي الموقع
  /// الموحّد (الكتل الخمس) المستخدم في بقية التطبيق، ثم يترجم الاختيار إلى
  /// location_id حقيقي.
  void _showAddUser(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String? selectedBlock;
    String? selectedArea;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'إضافة مستخدم جديد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الاسم الكامل', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      hintText: 'مثال: أحمد محمد',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('رقم الهاتف', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(hintText: '09xxxxxxxx'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'كلمة المرور المبدئية',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '6 أحرف على الأقل',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('الكتلة والمنطقة', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => showLocationPickerSheet(
                      context,
                      currentBlock: selectedBlock ?? '',
                      currentArea: selectedArea ?? '',
                      onSelect: (block, area) => setDialogState(() {
                        selectedBlock = block;
                        selectedArea = area;
                      }),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderOf(ctx)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        selectedArea == null
                            ? 'اختر الكتلة الإدارية والمنطقة'
                            : AleppoBlocks.displayLabel(
                                block: selectedBlock!,
                                area: selectedArea!,
                              ),
                        style: TextStyle(
                          color: selectedArea == null
                              ? AppColors.textHintOf(ctx)
                              : AppColors.textPrimaryOf(ctx),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty ||
                            phoneCtrl.text.trim().isEmpty ||
                            passwordCtrl.text.trim().length < 6 ||
                            selectedArea == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('يرجى تعبئة كل الحقول بشكل صحيح'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                        final locationId = context
                            .read<CatalogProvider>()
                            .locationIdForArea(selectedArea!);
                        final navigator = Navigator.of(ctx);
                        final ok =
                            await context.read<AdminUsersProvider>().createUser(
                                  name: nameCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                  password: passwordCtrl.text,
                                  locationId: locationId ?? '',
                                );
                        navigator.pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'تمت إضافة المستخدم' : 'تعذّرت الإضافة',
                            ),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.error,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('إضافة'),
                    ),
                  ),
                ],
              ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = context.watch<AdminUsersProvider>();
    // ══════════════════════════════════════════════════════════════════
    // ✅ إصلاح جوهري — استبعاد المدراء نهائياً (role == 'admin') من هذه
    // الشاشة؛ تُدار حساباتهم حصراً عبر AdminAdminsScreen. ثم فلترة حسب
    // الكتلة/المنطقة المختارتين أدناه.
    // ══════════════════════════════════════════════════════════════════
    var users = usersProvider.users.where((u) => u.role != 'admin').toList();
    if (_blockFilter != 'الكل') {
      users = users.where((u) => _blockOfUser(u) == _blockFilter).toList();
    }
    if (_areaFilter != 'الكل') {
      users = users.where((u) => _areaOfUser(u) == _areaFilter).toList();
    }

    return Column(
      children: [
        _AdminGradientHeader(
          title: 'إدارة المستخدمين',
          subtitle: 'إدارة حسابات المستخدمين',
          icon: Icons.people_outlined,
          actionLabel: 'إضافة مستخدم',
          onAction: () => _showAddUser(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WaffirSearchField(
                hint: 'ابحث عن اسم أو رقم هاتف...',
                onChanged: (v) {
                  setState(() => _search = v);
                  context.read<AdminUsersProvider>().loadUsers(search: v);
                },
              ),
              const SizedBox(height: 10),
              // ✅ جديد — فلتر الكتلة الإدارية
              FilterChipRow(
                options: ['الكل', ...AleppoBlocks.blockNames],
                selected: _blockFilter,
                onSelected: (v) => setState(() {
                  _blockFilter = v;
                  // إعادة ضبط فلتر الحي تلقائياً عند تغيير الكتلة
                  _areaFilter = 'الكل';
                }),
              ),
              // ✅ جديد — صف فلترة الحي (يظهر فقط بعد اختيار كتلة محددة)
              if (_blockFilter != 'الكل') ...[
                const SizedBox(height: 8),
                FilterChipRow(
                  options: ['الكل', ...AleppoBlocks.areasOfBlock(_blockFilter)],
                  selected: _areaFilter,
                  onSelected: (v) => setState(() => _areaFilter = v),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: usersProvider.isLoading && users.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : users.isEmpty
                  ? Center(
                      child: Text(
                        _search.isEmpty &&
                                _blockFilter == 'الكل' &&
                                _areaFilter == 'الكل'
                            ? 'لا يوجد مستخدمون'
                            : 'لا يوجد مستخدمون مطابقون',
                        style: TextStyle(
                            color: AppColors.textSecondaryOf(context)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: users.length,
                      itemBuilder: (ctx, i) {
                        final u = users[i];
                        final block = _blockOfUser(u);
                        final area = _areaOfUser(u);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceOf(context),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: AppColors.borderOf(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── الصف الأول: أيقونة + الاسم + تعديل/حذف ──
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      u.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () => _showEditUser(u),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () async {
                                      final confirmed = await showConfirmDialog(
                                        context,
                                        title: 'حذف المستخدم',
                                        message:
                                            'هل تريد حذف "${u.name}" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
                                        confirmText: 'حذف',
                                        icon: Icons.delete_outline,
                                      );
                                      if (confirmed != true || !mounted) return;
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      final ok = await context
                                          .read<AdminUsersProvider>()
                                          .deleteUser(u.id);
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ok
                                                ? 'تم حذف المستخدم'
                                                : 'تعذّر حذف المستخدم',
                                          ),
                                          backgroundColor: ok
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                      );
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // ── الصف الثاني: الهاتف + تاريخ الإنشاء ──
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.phone_outlined,
                                        size: 12,
                                        color: AppColors.textHintOf(context),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        u.phone,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.textHintOf(
                                        context,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 11,
                                          color: AppColors.textSecondaryOf(
                                            context,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatCreatedAt(u.createdAt),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: AppColors.textSecondaryOf(
                                              context,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // ── الصف الثالث: عدد الأسعار + شارة المنطقة ──
                              // ✅ جديد — شارة الكتلة/المنطقة التي اختارها
                              // المستخدم، بنفس نمط شارات المنطقة المستخدمة في
                              // بقية شاشات لوحة الإدارة (AdminStoresScreen،
                              // AdminPriceReviewScreen...).
                              Row(
                                children: [
                                  Text(
                                    '${u.pricesCount} سعر',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const Spacer(),
                                  if (area != null)
                                    Flexible(
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(maxWidth: 220),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.location_on_outlined,
                                              size: 11,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                block == null
                                                    ? area
                                                    : '$block — $area',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      'بلا موقع مسجَّل',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textHintOf(context),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PRODUCTS SCREEN
// ✅ الآن يقرأ من ProductProvider، وحوار "إضافة منتج" يستدعي فعلياً
// ProductProvider.createProduct (أُضيف حقل الوحدة الناقص)، وزر "⋮" يحذف
// المنتج فعلياً عبر ProductProvider.deleteProduct بعد تأكيد.
//
// ✅ جديد (هذا التحديث) — أُزيل حقل "الوحدة" (القائمة المنسدلة) من نافذة
// "إضافة/تعديل منتج" أدناه بناءً على طلب صريح للمستخدم. الحقل بقي داخلياً
// بقيمة ثابتة (existing?.unit ?? 'كغ') حتى لا تنكسر استدعاءات
// ProductProvider.createProduct/updateProduct التي ما زالت تتطلب unit
// كوسيط إلزامي، لكن لم يعد يظهر أي عنصر واجهة له في النافذة إطلاقاً.
// ══════════════════════════════════════════════════════════════════════════════
class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});
  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
  }

  /// ✅ جديد — نافذة إضافة/تعديل موحّدة. عند تمرير [existing] تعمل كنافذة
  /// تعديل (تُعبَّأ الحقول مسبقاً وتستدعي ProductProvider.updateProduct)،
  /// وإلا فهي نافذة إضافة كما كانت (ProductProvider.createProduct). هذا
  /// يكمل عنصر "تعديل" الناقص سابقاً في مخطط حالات الاستخدام.
  ///
  /// ✅ محدَّث — حُذف حقل "الوحدة" (القائمة المنسدلة) من هذه النافذة بناءً
  /// على طلب صريح. المتغيّر [unit] بقي موجوداً محلياً بقيمة ثابتة (قيمة
  /// المنتج الحالية عند التعديل، أو 'كغ' افتراضياً عند الإضافة) فقط لتمريره
  /// كما هو إلى ProductProvider.createProduct/updateProduct أدناه دون أي
  /// تغيير في توقيع تلك الدوال، بلا وجود أي عنصر واجهة يسمح بتغييره بعد
  /// الآن.
  void _showProductDialog(BuildContext context, {ProductModel? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isEdit ? 'تعديل المنتج' : 'إضافة منتج جديد',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('اسم المنتج', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(hintText: 'مثال: زيت زيتون'),
              ),
              const SizedBox(height: 14),
              const Text('الفئة', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(hintText: 'مثال: زيوت'),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final navigator = Navigator.of(ctx);
                      final provider = context.read<ProductProvider>();
                      final ok = isEdit
                          ? await provider.updateProduct(
                              existing.id,
                              name: nameCtrl.text.trim(),
                              category: catCtrl.text.trim(),
                            )
                          : await provider.createProduct(
                              name: nameCtrl.text.trim(),
                              category: catCtrl.text.trim(),
                            );
                      navigator.pop();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? (isEdit
                                    ? 'تم تعديل المنتج'
                                    : 'تمت إضافة المنتج')
                                : (isEdit
                                    ? 'تعذّر التعديل'
                                    : 'تعذّر إضافة المنتج'),
                          ),
                          backgroundColor:
                              ok ? AppColors.success : AppColors.error,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(isEdit ? 'حفظ' : 'إضافة'),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ProductModel p) async {
    final ok = await showConfirmDialog(
      context,
      title: 'حذف المنتج',
      message: 'هل تريد حذف "${p.name}"؟',
      confirmText: 'حذف',
      icon: Icons.delete_outline,
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await context.read<ProductProvider>().deleteProduct(p.id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(deleted ? 'تم حذف المنتج' : 'تعذّر الحذف'),
        backgroundColor: deleted ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    return Column(
      children: [
        _AdminGradientHeader(
          title: 'إدارة المنتجات',
          subtitle: 'أضف وراجع منتجات النظام',
          icon: Icons.inventory_2_outlined,
          actionLabel: 'إضافة منتج',
          onAction: () => _showProductDialog(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: WaffirSearchField(
            hint: 'ابحث عن منتج أو فئة...',
            onChanged: (v) =>
                context.read<ProductProvider>().loadProducts(search: v),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: productProvider.isLoading && productProvider.products.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: productProvider.products.length,
                  itemBuilder: (ctx, i) {
                    final p = productProvider.products[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      // ══════════════════════════════════════════════════════════
                      // ✅ إعادة تصميم احترافية لبطاقة المنتج — صفان:
                      // الصف الأول: أيقونة + اسم المنتج + تعديل/حذف
                      // الصف الثاني: شارات الفئة وعدد الأسعار في Wrap
                      // بنفس لغة التصميم المعتمدة في بقية بطاقات التطبيق
                      // (متاجر، أسعار، بلاغات) — شارات ملوّنة بخلفية شفافة.
                      // الشارات تبدأ من نفس محاذاة اسم المنتج (مسافة إزاحة
                      // 50 = 40 أيقونة + 10 مسافة)، وتستخدم Wrap لضمان عدم
                      // الفيضان عند فئات ذات أسماء طويلة.
                      // ══════════════════════════════════════════════════════════
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── الصف الأول: أيقونة + اسم المنتج + تعديل/حذف ──
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () =>
                                    _showProductDialog(context, existing: p),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _confirmDelete(p),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // ══════════════════════════════════════════════════════════
                          // ✅ جديد — صف شارات: شارة الفئة (إن وُجدت) وشارة عدد الأسعار
                          // معاً داخل Wrap مرن، بنفس نمط شارات الكتلة/الحي وتاريخ الإضافة
                          // المستخدَمة في بقية بطاقات لوحة الإدارة (AdminPriceReviewScreen،
                          // AdminStoresScreen...)، فلا تفيضان عن عرض الشاشة مهما طال اسم
                          // الفئة، وتبقى الشارات مُزاحة بمقدار عرض أيقونة المنتج (50 = 40 +
                          // 10) لتبدأ من نفس محاذاة اسم المنتج أعلاه.
                          // ══════════════════════════════════════════════════════════════════════════════════
                          Padding(
                            padding: const EdgeInsets.only(right: 50),
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (p.category.trim().isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.category_outlined,
                                          size: 11,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          p.category,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.textHint
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sell_outlined,
                                        size: 11,
                                        color:
                                            AppColors.textSecondaryOf(context),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${p.pricesCount} سعر',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.textSecondaryOf(
                                              context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STORES SCREEN
// ✅ الآن يقرأ من StoreProvider، وزر التوثيق فعلي (يستدعي
// StoreProvider.setVerified). فلتر الكتلة الإدارية الرسمية بالإضافة
// إلى فلتر التوثيق، وشارة الكتلة تُعرض أسفل كل متجر (مُشتقّة تلقائياً من
// حقل area عبر AleppoBlocks.blockOfArea).
// ✅ جديد — فلتر الحي بجانب فلتر الكتلة الإدارية، يظهر فقط بعد اختيار كتلة.
// ══════════════════════════════════════════════════════════════════════════════
class AdminStoresScreen extends StatefulWidget {
  const AdminStoresScreen({super.key});
  @override
  State<AdminStoresScreen> createState() => _AdminStoresScreenState();
}

class _AdminStoresScreenState extends State<AdminStoresScreen> {
  String _verifyFilter = 'الكل';
  // ✅ فلتر الكتلة الإدارية، يُشتق تصنيف كل متجر تلقائياً من حقل
  // area الموجود أصلاً عبر AleppoBlocks.blockOfArea (بلا حاجة لتعديل الـ
  // model أو الـ backend).
  String _blockFilter = 'الكل';
  // ✅ جديد — فلتر الحي، يظهر فقط بعد اختيار كتلة إدارية محددة، ويُعاد
  // ضبطه تلقائياً إلى "الكل" كلما تغيّرت الكتلة.
  String _areaFilter = 'الكل';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().loadStores();
      final catalog = context.read<CatalogProvider>();
      if (catalog.locations.isEmpty) catalog.loadLocations();
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري — حلّت محل _toggleVerify السابقة (نقرة مباشرة على شارة
  // "موثق" في البطاقة). تغيير حالة التوثيق أصبح يتم حصراً من داخل نافذة
  // "تعديل المتجر" (_showEditStore أدناه)، فأصبحت هذه الدالة غير مستخدَمة
  // وحُذفت. راجع مفتاح "حالة التوثيق" الجديد داخل تلك النافذة.
  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — إضافة متجر مباشرة من لوحة الإدارة. كانت "إدارة المتاجر" هي
  // الشاشة الإدارية الوحيدة التي لا تملك زر "إضافة" رغم أن مخطط حالات
  // الاستخدام يُدرج صراحة أن "إدارة المتاجر" تتضمّن الميزات المشتركة
  // الخمس (عرض/إضافة/تعديل/بحث/حذف) تماماً مثل إدارة المنتجات والمواقع
  // والوحدات والعلامات التجارية والأسعار الرسمية — التي تملك جميعها زر
  // إضافة في رأسها بالفعل. تستخدم نفس منتقي الموقع الموحّد ونفس آلية
  // ترجمة الحي المختار إلى location_id حقيقي عبر
  // CatalogProvider.locationIdForArea، بنفس منطق _showEditStore أدناه
  // وAddStoreScreen (مسار المستخدم العادي) تماماً.
  // ══════════════════════════════════════════════════════════════════════
  void _showAddStore(BuildContext context) {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String? selectedBlock;
    String? selectedArea;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'إضافة متجر جديد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اسم المتجر', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      hintText: 'مثال: محل الأمانة',
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ✅ محدَّث — حقل "الكتلة والمنطقة" أصبح قبل "العنوان"
                  // (تبديل الترتيب بناءً على طلب صريح)، بلا أي تغيير آخر
                  // في شكل أو سلوك الحقلين.
                  const Text('الكتلة والمنطقة', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => showLocationPickerSheet(
                      context,
                      currentBlock: selectedBlock ?? '',
                      currentArea: selectedArea ?? '',
                      onSelect: (block, area) => setDialogState(() {
                        selectedBlock = block;
                        selectedArea = area;
                      }),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderOf(ctx)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        selectedArea == null
                            ? 'اختر الكتلة الإدارية والمنطقة'
                            : AleppoBlocks.displayLabel(
                                block: selectedBlock!,
                                area: selectedArea!,
                              ),
                        style: TextStyle(
                          color: selectedArea == null
                              ? AppColors.textHintOf(ctx)
                              : AppColors.textPrimaryOf(ctx),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('العنوان', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addressCtrl,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      hintText: 'مثال: شارع الفرقان الرئيسي',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty ||
                            addressCtrl.text.trim().isEmpty ||
                            selectedArea == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('يرجى تعبئة كل الحقول بشكل صحيح'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                        final locationId = context
                            .read<CatalogProvider>()
                            .locationIdForArea(selectedArea!);
                        final navigator = Navigator.of(ctx);
                        final ok =
                            await context.read<StoreProvider>().createStore(
                                  name: nameCtrl.text.trim(),
                                  address: addressCtrl.text.trim(),
                                  area: selectedArea!,
                                  sector: selectedBlock!,
                                  locationId: locationId,
                                );
                        navigator.pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'تمت إضافة المتجر' : 'تعذّرت الإضافة',
                            ),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.error,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('إضافة'),
                    ),
                  ),
                ],
              ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        ),
      ),
    );
  }

  /// ✅ جديد — تعديل بيانات متجر (الاسم/العنوان/الموقع)، مطابقةً لعنصر
  /// "تعديل" الناقص سابقاً في مخطط حالات الاستخدام لـ"إدارة المتاجر".
  void _showEditStore(StoreModel s) {
    final nameCtrl = TextEditingController(text: s.name);
    final addressCtrl = TextEditingController(text: s.address);
    String? selectedBlock = AleppoBlocks.blockOfArea(s.area)?.name;
    String? selectedArea = s.area;
    // ✅ جديد — حالة التوثيق أصبحت حقلاً ضمن نافذة التعديل نفسها (بدل نقرة
    // مباشرة على شارة البطاقة)، فتُعدَّل مع باقي بيانات المتجر دفعة واحدة.
    bool isVerified = s.isVerified;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'تعديل المتجر',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اسم المتجر', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 14),
                  // ✅ محدَّث — حقل "الكتلة والمنطقة" أصبح قبل "العنوان"
                  // (تبديل الترتيب بناءً على طلب صريح)، بنفس الترتيب المعتمد
                  // في نافذة "إضافة متجر جديد" (_showAddStore) أعلاه في هذا
                  // الملف، بلا أي تغيير آخر في شكل أو سلوك الحقلين.
                  const Text('الكتلة والمنطقة', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => showLocationPickerSheet(
                      context,
                      currentBlock: selectedBlock ?? '',
                      currentArea: selectedArea ?? '',
                      onSelect: (block, area) => setDialogState(() {
                        selectedBlock = block;
                        selectedArea = area;
                      }),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderOf(ctx)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(selectedArea ?? 'اختر الكتلة والمنطقة'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('العنوان', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addressCtrl,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 14),
                  // ══════════════════════════════════════════════════════
                  // ✅ جديد — مفتاح "حالة التوثيق" داخل نافذة التعديل، بدل
                  // النقر المباشر على شارة "موثق" في البطاقة. بنفس نمط
                  // بطاقة قابلة للنقر بحدود ملونة تعكس الحالة الحالية،
                  // ليكون واضحاً بصرياً حتى قبل تبديله.
                  // ══════════════════════════════════════════════════════
                  const Text('حالة التوثيق', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setDialogState(() => isVerified = !isVerified),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: (isVerified
                                ? AppColors.success
                                : AppColors.textHint)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isVerified
                              ? AppColors.success
                              : AppColors.borderOf(ctx),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isVerified ? Icons.verified : Icons.help_outline,
                            size: 18,
                            color: isVerified
                                ? AppColors.success
                                : AppColors.textHintOf(ctx),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isVerified
                                  ? 'موثّق — يظهر كمتجر موثوق للمستخدمين'
                                  : 'غير موثّق — بانتظار المراجعة',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isVerified
                                    ? AppColors.success
                                    : AppColors.textSecondaryOf(ctx),
                              ),
                            ),
                          ),
                          Switch(
                            value: isVerified,
                            onChanged: (v) =>
                                setDialogState(() => isVerified = v),
                            activeThumbColor: AppColors.success,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty ||
                            addressCtrl.text.trim().isEmpty) {
                          return;
                        }
                        final locationId = selectedArea == s.area
                            ? null // لم يتغيّر الموقع
                            : context.read<CatalogProvider>().locationIdForArea(
                                  selectedArea!,
                                );
                        final navigator = Navigator.of(ctx);
                        final storeProvider = context.read<StoreProvider>();
                        final ok = await storeProvider.updateStore(
                          s.id,
                          name: nameCtrl.text.trim(),
                          address: addressCtrl.text.trim(),
                          locationId: locationId,
                        );
                        // ✅ جديد — إن تغيّرت حالة التوثيق داخل النافذة،
                        // تُرسَل عبر setVerified بعد نجاح تعديل بيانات
                        // المتجر الأساسية (طلب منفصل، بنفس آلية
                        // StoreProvider.setVerified الموجودة أصلاً).
                        var verifyOk = true;
                        if (ok && isVerified != s.isVerified) {
                          verifyOk = await storeProvider.setVerified(
                            s.id,
                            isVerified,
                          );
                        }
                        navigator.pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok && verifyOk
                                  ? 'تم تعديل المتجر'
                                  : 'تعذّر إتمام كل التعديلات',
                            ),
                            backgroundColor: ok && verifyOk
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        ),
      ),
    );
  }

  /// ✅ جديد — حذف متجر، مطابقةً لعنصر "حذف" الناقص سابقاً في نفس المخطط.
  Future<void> _confirmDeleteStore(StoreModel s) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف المتجر',
      message: 'هل تريد حذف "${s.name}" نهائياً؟',
      confirmText: 'حذف',
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<StoreProvider>().deleteStore(s.id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم حذف المتجر' : 'تعذّر حذف المتجر'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeProvider = context.watch<StoreProvider>();
    var stores = _verifyFilter == 'موثق'
        ? storeProvider.stores.where((s) => s.isVerified).toList()
        : _verifyFilter == 'غير موثق'
            ? storeProvider.stores.where((s) => !s.isVerified).toList()
            : storeProvider.stores;
    if (_blockFilter != 'الكل') {
      stores = stores
          .where((s) => AleppoBlocks.blockOfArea(s.area)?.name == _blockFilter)
          .toList();
    }
    // ✅ جديد — فلترة إضافية حسب الحي المحدد
    if (_areaFilter != 'الكل') {
      stores = stores.where((s) => s.area == _areaFilter).toList();
    }

    return Column(
      children: [
        // ✅ إصلاح جوهري — أُضيف زر "إضافة متجر" (كان غائباً تماماً)
        // مطابقةً لمخطط حالات الاستخدام الذي يُدرج "إدارة المتاجر" ضمن
        // الشاشات التي تتضمّن الميزات المشتركة الخمس كاملة (عرض/إضافة/
        // تعديل/بحث/حذف)، بنفس نمط بقية شاشات لوحة الإدارة.
        _AdminGradientHeader(
          title: 'إدارة المتاجر',
          subtitle: 'راجع وتحقق من المتاجر المسجلة، وأضف متاجر جديدة مباشرة',
          icon: Icons.store_outlined,
          actionLabel: 'إضافة متجر',
          onAction: () => _showAddStore(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WaffirSearchField(
                hint: 'ابحث عن متجر أو عنوان...',
                onChanged: (v) =>
                    context.read<StoreProvider>().loadStores(search: v),
              ),
              const SizedBox(height: 10),
              // فلتر الكتلة الإدارية
              FilterChipRow(
                options: ['الكل', ...AleppoBlocks.blockNames],
                selected: _blockFilter,
                onSelected: (v) => setState(() {
                  _blockFilter = v;
                  // ✅ إعادة ضبط فلتر الحي تلقائياً عند تغيير الكتلة
                  _areaFilter = 'الكل';
                }),
              ),
              // ✅ جديد — صف فلترة الحي (يظهر فقط بعد اختيار كتلة محددة)
              if (_blockFilter != 'الكل') ...[
                const SizedBox(height: 8),
                FilterChipRow(
                  options: ['الكل', ...AleppoBlocks.areasOfBlock(_blockFilter)],
                  selected: _areaFilter,
                  onSelected: (v) => setState(() => _areaFilter = v),
                ),
              ],
              const SizedBox(height: 8),
              FilterChipRow(
                options: const ['الكل', 'موثق', 'غير موثق'],
                selected: _verifyFilter,
                onSelected: (v) => setState(() => _verifyFilter = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: storeProvider.isLoading && stores.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : stores.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد متاجر مطابقة',
                        style: TextStyle(
                            color: AppColors.textSecondaryOf(context)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: stores.length,
                      itemBuilder: (ctx, i) {
                        final s = stores[i];
                        final block =
                            AleppoBlocks.blockOfArea(s.area)?.name ?? s.sector;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceOf(context),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: AppColors.borderOf(context)),
                          ),
                          // ══════════════════════════════════════════════
                          // ✅ إصلاح فيضان النص (overflow) جوهري — كانت
                          // البطاقة صفاً واحداً مزدحماً بعناصر ثابتة العرض
                          // بلا حد أقصى للأسطر (اسم المتجر، اسم الحي، عدّاد
                          // الأسعار، شارة التوثيق، زرّا التعديل/الحذف)، فحين
                          // يطول اسم المتجر أو الحي (مثال: "الحمدانية الحي
                          // الأول") يضيق الحيّز المتبقي لنص العنوان (Expanded)
                          // حتى الانضغاط والالتفاف حرفاً حرفاً عمودياً، مع
                          // فيضان فعلي لبقية الصف عن حدود الشاشة
                          // ("RIGHT OVERFLOWED" في وضع التصحيح).
                          //
                          // الحل: إعادة ترتيب البطاقة على 3 صفوف، وكل نص
                          // متغيّر الطول محدود الآن بسطر واحد وعلامة "..."
                          // عند الحاجة (اسم المتجر، العنوان، اسم الحي)، بلا
                          // أي فقدان لأي معلومة كانت معروضة سابقاً:
                          //   1) اسم المتجر (Expanded) + عدد الأسعار + تعديل/حذف
                          //   2) العنوان الكامل بسطر واحد
                          //   3) شارة التوثيق (قابلة للنقر) + شارتا الحي/الكتلة
                          // ══════════════════════════════════════════════
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${s.pricesCount} سعر',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  const SizedBox(width: 6),
                                  // ✅ أزرار تعديل/حذف
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () => _showEditStore(s),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () => _confirmDeleteStore(s),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // ══════════════════════════════════════
                                  // ✅ إصلاح جوهري — أُزيلت إمكانية تبديل
                                  // حالة التوثيق بنقرة مباشرة على الشارة
                                  // (كانت GestureDetector تستدعي
                                  // _toggleVerify مباشرة). الشارة الآن عرض
                                  // فقط (Container بلا أي onTap)، وأصبح
                                  // تغيير حالة التوثيق يتم حصراً من داخل
                                  // نافذة "تعديل المتجر" (زر القلم)، راجع
                                  // _showEditStore أدناه — بنفس مبدأ توحيد
                                  // إجراءات "التعديل" في مكان واحد.
                                  // ══════════════════════════════════════
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (s.isVerified
                                              ? AppColors.success
                                              : AppColors.textHint)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          s.isVerified
                                              ? Icons.verified
                                              : Icons.help_outline,
                                          size: 14,
                                          color: s.isVerified
                                              ? AppColors.success
                                              : AppColors.textHint,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          s.isVerified ? 'موثق' : 'غير موثق',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: s.isVerified
                                                ? AppColors.success
                                                : AppColors.textSecondaryOf(
                                                    context,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // ✅ شارتا الحي والكتلة الإدارية داخل Wrap
                                  // مرن بدل Row ثابت، فلا تفيضان عن الشاشة
                                  // مهما طال اسم الحي.
                                  Expanded(
                                    child: Wrap(
                                      alignment: WrapAlignment.start,
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          constraints: const BoxConstraints(
                                            maxWidth: 140,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            s.area,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        // ✅ شارة الكتلة الإدارية
                                        Container(
                                          constraints: const BoxConstraints(
                                            maxWidth: 140,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            block,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LOCATIONS SCREEN
// ✅ من CatalogProvider، بالإضافة إلى فلتر الكتلة الإدارية وقائمتين
// منسدلتين مترابطتين (كتلة ← حي) عند إضافة موقع جديد بدل حقول نصية حرة.
// ✅ جديد — فلتر الحي بجانب فلتر الكتلة الإدارية في قائمة العرض نفسها،
// يظهر فقط بعد اختيار كتلة، ويُعاد ضبطه عند تغييرها.
// ══════════════════════════════════════════════════════════════════════════════
class AdminLocationsScreen extends StatefulWidget {
  const AdminLocationsScreen({super.key});
  @override
  State<AdminLocationsScreen> createState() => _AdminLocationsScreenState();
}

class _AdminLocationsScreenState extends State<AdminLocationsScreen> {
  // ✅ فلترة قائمة المواقع حسب الكتلة الإدارية
  String _blockFilter = 'الكل';
  // ✅ جديد — فلترة إضافية حسب الحي داخل الكتلة المختارة
  String _areaFilter = 'الكل';
  // ✅ جديد — نص البحث المربوط فعلياً بحقل البحث (كان زخرفياً بلا فلترة)
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalog = context.read<CatalogProvider>();
      catalog.loadLocations();
      catalog.loadSectors();
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ تحديث جوهري (بناءً على طلب صريح):
  //   1) حُذف حقل "المعلم (اختياري)" نهائياً من نافذتي الإضافة والتعديل —
  //      لم يعد يظهر أي عنصر واجهة له، ويُرسَل حقل landmark فارغاً ('')
  //      إلى CatalogProvider.addLocation/updateLocation (كلاهما لا يزال
  //      يتطلبه كوسيط، فبقي التوقيع كما هو دون أي تعديل في app_provider.dart
  //      أو catalog_service.dart، تفادياً لأي أثر جانبي في ملفات أخرى).
  //   2) حقل "المنطقة" تحوّل من قائمة منسدلة مقيَّدة بأحياء الكتلة المختارة
  //      (AleppoBlocks.areasOfBlock) إلى حقل نصي حر (TextField) قابل
  //      للكتابة المباشرة — سواء عند الإضافة أو عند التعديل — بدل الاقتصار
  //      على الاختيار من قائمة الأحياء الرسمية الثابتة فقط. حقل "الكتلة
  //      الإدارية" بقي قائمة منسدلة كما هو (لم يُطلب تغييره)، وبما أن
  //      المنطقة أصبحت نصاً حراً الآن، لم يعد هناك حاجة لإعادة ضبطها تلقائياً
  //      عند تغيير الكتلة (القيمة المكتوبة تبقى كما هي بصرف النظر عن الكتلة
  //      المختارة).
  // ══════════════════════════════════════════════════════════════════════
  void _showLocationDialog(BuildContext context, {LocationModel? existing}) {
    final isEdit = existing != null;
    final areaCtrl = TextEditingController(text: existing?.area ?? '');
    String selectedBlock = existing?.sector ?? AleppoBlocks.all.first.name;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              isEdit ? 'تعديل المنطقة' : 'إضافة منطقة جديدة',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'الكتلة الإدارية',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBlock,
                    isExpanded: true,
                    items: AleppoBlocks.blockNames
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() => selectedBlock = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('المنطقة', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(height: 6),
                  // ✅ حقل نصي حر بدل القائمة المنسدلة السابقة — يمكن كتابة
                  // أي اسم حي، وليس محصوراً بأحياء الكتلة المختارة أعلاه.
                  TextField(
                    controller: areaCtrl,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      hintText: 'مثال: الفرقان',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final area = areaCtrl.text.trim();
                        // ✅ تحقق أساسي: المنطقة أصبحت نصاً حراً، فلا بد من
                        // ضمان عدم إرسالها فارغة بعد أن كانت مضمونة القيمة
                        // دائماً عبر القائمة المنسدلة سابقاً.
                        if (area.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('يرجى إدخال اسم المنطقة'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                        final navigator = Navigator.of(ctx);
                        final provider = context.read<CatalogProvider>();
                        final ok = isEdit
                            ? await provider.updateLocation(
                                existing.id,
                                sector: selectedBlock,
                                area: area,
                                landmark: '',
                              )
                            : await provider.addLocation(
                                sector: selectedBlock,
                                area: area,
                                landmark: '',
                              );
                        navigator.pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? (isEdit ? 'تم التعديل' : 'تمت الإضافة')
                                  : (isEdit
                                      ? 'تعذّر التعديل'
                                      : 'تعذّرت الإضافة'),
                            ),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.error,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(isEdit ? 'حفظ' : 'إضافة'),
                    ),
                  ),
                ],
              ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        ),
      ),
    );
  }

  /// ✅ جديد — حذف موقع، مطابقةً لعنصر "حذف" الناقص سابقاً في نفس المخطط.
  Future<void> _confirmDeleteLocation(LocationModel l) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف المنطقة',
      message: 'هل تريد حذف "${l.area}" نهائياً؟',
      confirmText: 'حذف',
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<CatalogProvider>().deleteLocation(l.id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم حذف الموقع' : 'تعذّر حذف الموقع'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    var locations = _blockFilter == 'الكل'
        ? catalog.locations
        : catalog.locations.where((l) => l.sector == _blockFilter).toList();
    // ✅ جديد — فلترة إضافية حسب الحي المحدد
    if (_areaFilter != 'الكل') {
      locations = locations.where((l) => l.area == _areaFilter).toList();
    }
    // ✅ إصلاح — كان حقل البحث زخرفياً بلا onChanged
    if (_search.trim().isNotEmpty) {
      final q = _search.trim();
      locations = locations
          .where((l) => l.area.contains(q) || l.landmark.contains(q))
          .toList();
    }

    return Column(
      children: [
        _AdminGradientHeader(
          title: 'إدارة الكتل والمناطق',
          subtitle: 'أدر الكتل الإدارية الخمس ومناطقها',
          icon: Icons.location_on_outlined,
          actionLabel: 'إضافة منطقة',
          onAction: () => _showLocationDialog(context),
          // ✅ جديد — زر ثانوي يفتح شاشة "تعديل الكتل" المستقلة، حيث تُدار
          // أسماء الكتل الإدارية نفسها (تعديل الاسم أو حذف الكتلة بالكامل)
          // بمعزل عن إدارة الأحياء الفردية أعلاه.
          secondaryActionLabel: 'تعديل الكتل',
          secondaryActionIcon: Icons.edit_road_outlined,
          onSecondaryAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminBlocksScreen()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WaffirSearchField(
                hint: 'ابحث عن المنطقة...',
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 10),
              // ✅ فلترة حسب الكتلة الإدارية
              FilterChipRow(
                options: ['الكل', ...AleppoBlocks.blockNames],
                selected: _blockFilter,
                onSelected: (v) => setState(() {
                  _blockFilter = v;
                  // ✅ إعادة ضبط فلتر الحي تلقائياً عند تغيير الكتلة
                  _areaFilter = 'الكل';
                }),
              ),
              // ✅ جديد — صف فلترة الحي (يظهر فقط بعد اختيار كتلة محددة)
              if (_blockFilter != 'الكل') ...[
                const SizedBox(height: 8),
                FilterChipRow(
                  options: ['الكل', ...AleppoBlocks.areasOfBlock(_blockFilter)],
                  selected: _areaFilter,
                  onSelected: (v) => setState(() => _areaFilter = v),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: catalog.isLoading && catalog.locations.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : locations.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد مواقع مطابقة',
                        style: TextStyle(
                            color: AppColors.textSecondaryOf(context)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: locations.length,
                      itemBuilder: (ctx, i) {
                        final l = locations[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceOf(context),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: AppColors.borderOf(context)),
                          ),
                          // ══════════════════════════════════════════════
                          // ✅ محدَّث — أُزيل عرض "المعلم" (landmark) وعدد
                          // المتاجر (l.storesCount) من هذه البطاقة بناءً
                          // على طلب صريح. البطاقة أصبحت أبسط: اسم الحي في
                          // صف علوي (Expanded بسطر واحد لمنع أي فيضان نص)
                          // مع زرّي التعديل/الحذف، وشارة الكتلة الإدارية
                          // وحدها في صف سفلي.
                          // ══════════════════════════════════════════════
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l.area,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // ✅ أزرار تعديل/حذف، مطابقةً لمخطط حالات
                                  // الاستخدام لـ"إدارة المواقع والكتل".
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () => _showLocationDialog(
                                        context,
                                        existing: l),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () => _confirmDeleteLocation(l),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // ✅ شارة الكتلة الإدارية بدل نص "حلب" العام
                              // السابق
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    l.sector,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ✅ جديد بالكامل — BLOCKS SCREEN ("تعديل الكتل")
// شاشة مستقلة لإدارة الكتل الرسمية والكتل التي يضيفها المسؤول.
//
//   • عرض   → الكتل الفريدة المُشتقّة من sector لكل المواقع، مع عدد
//             الأحياء التابعة لكل كتلة.
//   • تعديل → إعادة تسمية الكتلة: يُحدَّث عمود sector لكل حي تابع لها عبر
//             CatalogProvider.updateLocation (طلب منفصل لكل حي، بما أن لا
//             يوجد endpoint واحد لإعادة تسمية كتلة كاملة دفعة واحدة).
//   • حذف   → حذف الكتلة بالكامل: يحذف كل الأحياء التابعة لها عبر
//             CatalogProvider.deleteLocation (بعد تحذير صريح بعدد الأحياء
//             التي ستُحذف، لأن هذا إجراء تجميعي لا رجعة فيه).
// ══════════════════════════════════════════════════════════════════════════════
class AdminBlocksScreen extends StatefulWidget {
  const AdminBlocksScreen({super.key});

  @override
  State<AdminBlocksScreen> createState() => _AdminBlocksScreenState();
}

class _AdminBlocksScreenState extends State<AdminBlocksScreen> {
  // أثناء تنفيذ إعادة تسمية أو حذف جماعي، تُعطّل الإجراءات لمنع التكرار.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalog = context.read<CatalogProvider>();
      if (catalog.locations.isEmpty) catalog.loadLocations();
      if (catalog.sectors.isEmpty) catalog.loadSectors();
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري — الرقم الظاهر تحت اسم كل كتلة كان يُحسب من عدد سجلات
  // LocationModel (من CatalogProvider.locations، أي "المواقع" المُسجَّلة
  // فعلياً عبر شاشة "إدارة الكتل والمناطق" أو من الخادم) التي يطابق حقل
  // sector فيها اسم الكتلة — وهذا عملياً عدد "مواقع" مرتبطة بالمتاجر، لا
  // عدد "المناطق/الأحياء" الفعلي المُعرَّف لكل كتلة في aleppo_blocks.dart.
  // النتيجتان مختلفتان تماماً وغير متسقتين:
  //   • الكتل الرسمية الخمس تملك عشرات الأحياء الثابتة (16 إلى 33 حياً)،
  //     لكن الرقم المعروض كان يعتمد فقط على عدد سجلات LocationModel
  //     الموجودة فعلياً في القائمة (وقد يكون أقل بكثير أو صفراً).
  //   • أي كتلة جديدة يضيفها المسؤول (عبر "إضافة كتلة جديدة" أدناه) تُعرَّف
  //     أحياؤها مباشرة داخل AleppoBlocks (بلا أي سجل LocationModel مقابل
  //     لها بالضرورة)، فكان رقمها يظهر صفراً دائماً بعد الإضافة مباشرة،
  //     خلافاً تماماً لسلوك الكتل الرسمية — وهو بالضبط التناقض المُبلَّغ عنه.
  //
  // الإصلاح: الرقم أصبح يُشتق حصرياً من AleppoBlocks.areasOfBlock(name)
  // — المصدر الوحيد والموحّد لعدد "المناطق" الفعلي لأي كتلة، رسمية كانت أم
  // مضافة من المسؤول، تماماً كما تعرضه بقية شاشات التطبيق (فلاتر الأحياء،
  // منتقي الموقع...). بهذا تصبح كتلة مضافة حديثاً مطابقة تماماً لسلوك أي
  // كتلة رسمية: رقمها يعكس فوراً عدد الأحياء التي أُضيفت لها عند الإنشاء
  // (أو لاحقاً)، بلا أي فرق في الشكل أو المبدأ.
  //
  // ملاحظة: الوسيط [locations] لم يعد يُستخدَم في حساب العدّاد (أُبقي في
  // التوقيع فقط لعدم كسر نقطة الاستدعاء في build()، والتي ما زالت بحاجة
  // لقائمة locations بشكل منفصل لحساب "members" عند التعديل/الحذف).
  // ══════════════════════════════════════════════════════════════════════
  List<MapEntry<String, int>> _blocksOf(List<LocationModel> locations) {
    final entries = AleppoBlocks.all
        .map((block) => MapEntry(
              block.name,
              AleppoBlocks.areasOfBlock(block.name).length,
            ))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  Future<void> _showAddBlockDialog() async {
    final nameCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final pendingAreas = <String>[];
    String? nameError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void addArea() {
            final area = areaCtrl.text.trim();
            if (area.isEmpty || pendingAreas.contains(area)) return;
            setDialogState(() {
              pendingAreas.add(area);
              areaCtrl.clear();
            });
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('إضافة كتلة جديدة'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اسم الكتلة'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      onChanged: (_) {
                        if (nameError != null) {
                          setDialogState(() => nameError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'مثال: الكتلة السادسة',
                        errorText: nameError,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('مناطق الكتلة (اختياري)'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: areaCtrl,
                            onSubmitted: (_) => addArea(),
                            decoration:
                                const InputDecoration(hintText: 'اسم المنطقة'),
                          ),
                        ),
                        IconButton(
                          tooltip: 'إضافة منطقة',
                          onPressed: addArea,
                          icon: const Icon(Icons.add_circle,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                    if (pendingAreas.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: pendingAreas
                            .map((area) => Chip(
                                  label: Text(area),
                                  onDeleted: () => setDialogState(
                                      () => pendingAreas.remove(area)),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final trimmedName = nameCtrl.text.trim();
                          if (AleppoBlocks.all
                              .any((block) => block.name == trimmedName)) {
                            setDialogState(
                                () => nameError = 'يرجى إدخال اسم فريد للكتلة');
                            return;
                          }
                          final sectorCreated = await context
                              .read<CatalogProvider>()
                              .addSector(trimmedName);
                          if (!sectorCreated) {
                            setDialogState(() =>
                                nameError = 'تعذّرت إضافة الكتلة إلى الخادم');
                            return;
                          }
                          final ok = await AleppoBlocks.addBlock(
                            trimmedName,
                            areas: pendingAreas,
                          );
                          if (!ok) {
                            setDialogState(
                                () => nameError = 'يرجى إدخال اسم فريد للكتلة');
                            return;
                          }
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تمت إضافة الكتلة بنجاح'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        child: const Text('إضافة'),
                      ),
                    ),
                  ],
                ),
              ],
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
          );
        },
      ),
    );
  }

  Future<void> _renameBlock(String oldName, List<LocationModel> members) async {
    final isCustom = AleppoBlocks.isCustomBlock(oldName);
    if (!isCustom && members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أضف مناطق لهذه الكتلة أولاً لتتمكن من تعديلها'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    final ctrl = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'تعديل اسم الكتلة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سيُطبَّق الاسم الجديد على ${members.length} منطقة تابعة لهذه الكتلة',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondaryOf(ctx),
                ),
              ),
              const SizedBox(height: 14),
              const Text('اسم الكتلة', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  hintText: 'مثال: الكتلة الأولى',
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('حفظ'),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;
    if (!mounted) return;

    if (AleppoBlocks.all.any((block) => block.name == newName)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('هذا الاسم مستخدم من قبل كتلة أخرى'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<CatalogProvider>();
    setState(() => _busy = true);
    var failures = 0;
    if (AppConfig.useMockData) {
      for (final loc in members) {
        final ok = await provider.updateLocation(
          loc.id,
          sector: newName,
          area: loc.area,
          landmark: loc.landmark,
        );
        if (!ok) failures++;
      }
    } else if (!await provider.updateSector(oldName, newName)) {
      failures++;
    }
    if (isCustom) {
      final renamed = await AleppoBlocks.renameCustomBlock(oldName, newName);
      if (!renamed) failures++;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failures == 0
              ? 'تم تعديل اسم الكتلة لكل المناطق التابعة لها'
              : 'تعذّر تحديث $failures من ${members.length} منطقة',
        ),
        backgroundColor: failures == 0 ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _deleteBlock(String name, List<LocationModel> members) async {
    final isOfficial = AleppoBlocks.isOfficialBlock(name);
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف الكتلة',
      message: isOfficial
          ? 'سيؤدي هذا إلى حذف الكتلة الرسمية "$name" وكل المناطق الـ${members.length} التابعة لها نهائياً من كل شاشات التطبيق.'
          : 'سيؤدي هذا إلى حذف "$name" وكل المناطق الـ${members.length} التابعة لها نهائياً. لا يمكن التراجع عن هذا الإجراء.',
      confirmText: 'حذف الكتلة',
      icon: Icons.delete_forever_outlined,
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<CatalogProvider>();
    setState(() => _busy = true);
    var failures = 0;
    for (final loc in members) {
      final ok = await provider.deleteLocation(loc.id);
      if (!ok) failures++;
    }
    if (failures == 0 &&
        !AppConfig.useMockData &&
        !await provider.deleteSector(name)) {
      failures++;
    }
    if (failures == 0 && !await AleppoBlocks.deleteBlock(name)) {
      failures++;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failures == 0
              ? 'تم حذف الكتلة وكل مناطقها'
              : 'تعذّر حذف $failures من ${members.length} منطقة',
        ),
        backgroundColor: failures == 0 ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final blocks = _blocksOf(catalog.locations);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تعديل الكتل'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تعديل اسم الكتلة يطبّقه على كل مناطقها، وحذفها يحذف كل المناطق التابعة لها',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _showAddBlockDialog,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text('إضافة كتلة جديدة'),
                ),
              ),
            ),
            Expanded(
              child: catalog.isLoading && catalog.locations.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : blocks.isEmpty
                      ? Center(
                          child: Text(
                            'لا توجد كتل مسجّلة بعد',
                            style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: blocks.length,
                          itemBuilder: (ctx, i) {
                            final entry = blocks[i];
                            final isCustom =
                                AleppoBlocks.isCustomBlock(entry.key);
                            final members = catalog.locations
                                .where((l) => l.sector == entry.key)
                                .toList();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceOf(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.borderOf(context),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (isCustom
                                              ? AppColors.success
                                              : AppColors.primary)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isCustom
                                          ? Icons.add_location_alt_outlined
                                          : Icons.location_city_outlined,
                                      color: isCustom
                                          ? AppColors.success
                                          : AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                entry.key,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${entry.value} منطقة',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondaryOf(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                            _renameBlock(entry.key, members),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: AppColors.error,
                                    ),
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                            _deleteBlock(entry.key, members),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// UNITS SCREEN — ✅ من CatalogProvider، إضافة/حذف فعليان
// ══════════════════════════════════════════════════════════════════════════════
class AdminUnitsScreen extends StatefulWidget {
  const AdminUnitsScreen({super.key});
  @override
  State<AdminUnitsScreen> createState() => _AdminUnitsScreenState();
}

class _AdminUnitsScreenState extends State<AdminUnitsScreen> {
  // ✅ جديد — حقل بحث لم يكن موجوداً إطلاقاً سابقاً رغم إدراجه ضمن الأفعال
  // الموحّدة في مخطط حالات الاستخدام لـ"إدارة الوحدات".
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().loadUnits();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final units = _search.trim().isEmpty
        ? catalog.units
        : catalog.units.where((u) => u.name.contains(_search.trim())).toList();
    return Column(
      children: [
        _AdminGradientHeader(
          title: 'إدارة الواحدات',
          subtitle: 'أدر واحدات القياس المستخدمة في النظام',
          icon: Icons.tag,
          actionLabel: 'إضافة واحدة',
          onAction: () async {
            final name = await showAddDialog(
              context,
              title: 'إضافة واحدة جديدة',
              fieldLabel: 'اسم الواحدة',
              hint: 'مثال: كيلوغرام',
            );
            if (name == null || name.trim().isEmpty || !mounted) return;
            final ok = await context.read<CatalogProvider>().addUnit(
                  name.trim(),
                );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok ? 'تمت الإضافة' : 'تعذّرت الإضافة'),
                backgroundColor: ok ? AppColors.success : AppColors.error,
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: WaffirSearchField(
            hint: 'ابحث عن واحدة...',
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: catalog.isLoading && catalog.units.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: units.length,
                  itemBuilder: (ctx, i) {
                    final u = units[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      // ══════════════════════════════════════════════════
                      // ✅ إعادة ترتيب — أيقونة "#" أصبحت أول عنصر في
                      // children فتظهر الآن أقصى اليمين (بجانب الاسم مباشرة)
                      // بدل أقصى اليسار، وزرّا التعديل/الحذف انتقلا إلى آخر
                      // عنصر فيظهران أقصى اليسار بدل أقصى اليمين — عكس
                      // الترتيب السابق تماماً، بلا أي تغيير في وظيفة أي زر.
                      // ══════════════════════════════════════════════════
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.tag,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${u.usageCount} استخدام',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // ✅ إصلاح جوهري — بدّلنا ترتيب زرّي التعديل/الحذف:
                          // زر التعديل (✏️) أصبح أولاً فيظهر أقرب إلى النص
                          // (يمين المجموعة)، وزر الحذف (🗑️) أصبح أخيراً
                          // فيظهر في أقصى يسار البطاقة كاملة — بلا أي تغيير
                          // في وظيفة أي زر.
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                // ✅ إصلاح جوهري — أصبح endpoint التعديل موثّقاً
                                // فعلياً (PUT /units/{id}، راجع CatalogService.
                                // updateUnit)، فحلّت نافذة تعديل حقيقية محل
                                // رسالة "قيد التطوير" السابقة.
                                onPressed: () async {
                                  final name = await showAddDialog(
                                    context,
                                    title: 'تعديل الواحدة',
                                    fieldLabel: 'اسم الواحدة',
                                    hint: 'مثال: كيلوغرام',
                                    initialValue: u.name,
                                    confirmLabel: 'حفظ',
                                  );
                                  if (name == null ||
                                      name.trim().isEmpty ||
                                      !mounted) {
                                    return;
                                  }
                                  final ok = await context
                                      .read<CatalogProvider>()
                                      .updateUnit(u.id, name.trim());
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok ? 'تم التعديل' : 'تعذّر التعديل',
                                      ),
                                      backgroundColor: ok
                                          ? AppColors.success
                                          : AppColors.error,
                                    ),
                                  );
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final confirmed = await showConfirmDialog(
                                    ctx,
                                    title: 'حذف الواحدة',
                                    message: 'هل تريد حذف هذه الواحدة؟',
                                    confirmText: 'حذف',
                                    icon: Icons.delete_outline,
                                  );
                                  if (confirmed == true && mounted) {
                                    await context
                                        .read<CatalogProvider>()
                                        .deleteUnit(u.id);
                                  }
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BRANDS SCREEN — ✅ من CatalogProvider، إضافة/حذف فعليان
// ══════════════════════════════════════════════════════════════════════════════
class AdminBrandsScreen extends StatefulWidget {
  const AdminBrandsScreen({super.key});
  @override
  State<AdminBrandsScreen> createState() => _AdminBrandsScreenState();
}

class _AdminBrandsScreenState extends State<AdminBrandsScreen> {
  // ✅ جديد — حقل بحث لم يكن موجوداً إطلاقاً سابقاً
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().loadBrands();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final brands = _search.trim().isEmpty
        ? catalog.brands
        : catalog.brands.where((b) => b.name.contains(_search.trim())).toList();
    return Column(
      children: [
        _AdminGradientHeader(
          title: 'إدارة العلامات التجارية',
          subtitle: 'أدر العلامات التجارية في النظام',
          icon: Icons.label_outlined,
          actionLabel: 'إضافة علامة تجارية',
          onAction: () async {
            final name = await showAddDialog(
              context,
              title: 'إضافة علامة تجارية جديدة',
              fieldLabel: 'اسم العلامة التجارية',
              hint: 'مثال: فلسطين',
            );
            if (name == null || name.trim().isEmpty || !mounted) return;
            final ok = await context.read<CatalogProvider>().addBrand(
                  name.trim(),
                );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok ? 'تمت الإضافة' : 'تعذّرت الإضافة'),
                backgroundColor: ok ? AppColors.success : AppColors.error,
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: WaffirSearchField(
            hint: 'ابحث عن علامة تجارية...',
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: catalog.isLoading && catalog.brands.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: brands.length,
                  itemBuilder: (ctx, i) {
                    final b = brands[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      // ══════════════════════════════════════════════════
                      // ✅ إعادة ترتيب — نفس إصلاح ترتيب الأيقونات المطبَّق
                      // في AdminUnitsScreen أعلاه: أيقونة التصنيف أصبحت أول
                      // عنصر فتظهر أقصى اليمين بجانب الاسم، وزرّا التعديل/
                      // الحذف انتقلا إلى آخر عنصر فيظهران أقصى اليسار.
                      // ══════════════════════════════════════════════════
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.label_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${b.productsCount} منتج',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                // ✅ إصلاح جوهري — أصبح endpoint التعديل موثّقاً
                                // فعلياً (PUT /brands/{id})، فحلّت نافذة تعديل
                                // حقيقية محل رسالة "قيد التطوير" السابقة.
                                onPressed: () async {
                                  final name = await showAddDialog(
                                    context,
                                    title: 'تعديل العلامة التجارية',
                                    fieldLabel: 'اسم العلامة التجارية',
                                    hint: 'مثال: فلسطين',
                                    initialValue: b.name,
                                    confirmLabel: 'حفظ',
                                  );
                                  if (name == null ||
                                      name.trim().isEmpty ||
                                      !mounted) {
                                    return;
                                  }
                                  final ok = await context
                                      .read<CatalogProvider>()
                                      .updateBrand(b.id, name.trim());
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok ? 'تم التعديل' : 'تعذّر التعديل',
                                      ),
                                      backgroundColor: ok
                                          ? AppColors.success
                                          : AppColors.error,
                                    ),
                                  );
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final confirmed = await showConfirmDialog(
                                    ctx,
                                    title: 'حذف العلامة التجارية',
                                    message: 'هل تريد حذف هذه العلامة؟',
                                    confirmText: 'حذف',
                                    icon: Icons.delete_outline,
                                  );
                                  if (confirmed == true && mounted) {
                                    await context
                                        .read<CatalogProvider>()
                                        .deleteBrand(b.id);
                                  }
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// OFFICIAL PRICES SCREEN — ✅ من CatalogProvider، إضافة فعلية
//
// ✅ إصلاح جوهري في نافذة "إضافة سعر رسمي جديد" (بلا أي تغيير في شكل
// النافذة أو ترتيب حقولها): كان حقلا "المنتج" و"الوحدة" عبارة عن نص حر
// (TextField)، رغم أن مخطط قاعدة البيانات الفعلي لجدول OfficialPrice لا
// يحتوي أي عمود نصي لاسم المنتج أو الوحدة — فقط product_id/unit_id
// (مفتاحان أجنبيان يشيران لجدولي Product/Unit). أي اسم يُكتب يدوياً لا
// يملك أي ربط حقيقي بقاعدة البيانات ولا يمكن للخادم حفظه بشكل صحيح.
//
// استُبدل ذلك بقائمتين منسدلتين (نفس نمط _showAddLocation أعلاه تماماً):
// "المنتج" تُختار من ProductProvider.products الحقيقية، و"الوحدة" من
// CatalogProvider.units الحقيقية — بنفس عنوان النافذة، ونفس ترتيب الحقول
// (المنتج، الكمية، الوحدة، السعر)، ونفس شكل وحجم الأزرار تماماً.
// ══════════════════════════════════════════════════════════════════════════════
class AdminOfficialPricesScreen extends StatefulWidget {
  const AdminOfficialPricesScreen({super.key});
  @override
  State<AdminOfficialPricesScreen> createState() =>
      _AdminOfficialPricesScreenState();
}

class _AdminOfficialPricesScreenState extends State<AdminOfficialPricesScreen> {
  // ✅ جديد — نص البحث المربوط فعلياً (كان حقل البحث زخرفياً بلا فلترة)
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().loadOfficialPrices();
    });
  }

  /// ✅ محدَّث — نافذة موحّدة إضافة/تعديل. تمرير [existing] يحوّلها لنافذة
  /// تعديل (CatalogProvider.updateOfficialPrice)، مطابقةً لعنصر "تعديل"
  /// الناقص سابقاً في مخطط حالات الاستخدام لـ"إدارة الأسعار الرسمية".
  void _showOfficialPriceDialog(
    BuildContext context, {
    OfficialPrice? existing,
  }) {
    final isEdit = existing != null;
    final qtyCtrl = TextEditingController(
      text: (existing?.quantity ?? 1).toStringAsFixed(0),
    );
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(0) : '',
    );

    // ✅ تحميل قوائم المنتجات والوحدات الحقيقية (إن لم تكن محمَّلة أصلاً)
    // قبل فتح النافذة، حتى تظهر القائمتان المنسدلتان مملوءتين فوراً.
    final productProvider = context.read<ProductProvider>();
    final catalogProvider = context.read<CatalogProvider>();
    if (productProvider.products.isEmpty) productProvider.loadProducts();
    if (catalogProvider.units.isEmpty) catalogProvider.loadUnits();

    String? selectedProductId = existing?.productId;
    String? selectedUnitId = existing?.unitId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // ✅ watch هنا (لا read) لتحديث محتوى القائمتين فور اكتمال
          // التحميل حتى لو فُتحت النافذة قبل وصول الاستجابة.
          final products = context.watch<ProductProvider>().products;
          final units = context.watch<CatalogProvider>().units;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                isEdit ? 'تعديل سعر رسمي' : 'إضافة سعر رسمي جديد',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('المنتج', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedProductId,
                      isExpanded: true,
                      hint: const Text(
                        'اختر المنتج',
                        style: TextStyle(fontSize: 13),
                      ),
                      items: products
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                p.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedProductId = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الكمية',
                                style: TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '1',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الواحدة',
                                style: TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: selectedUnitId,
                                isExpanded: true,
                                hint: const Text(
                                  'اختر',
                                  style: TextStyle(fontSize: 13),
                                ),
                                items: units
                                    .map(
                                      (u) => DropdownMenuItem(
                                        value: u.id,
                                        child: Text(
                                          u.name,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setDialogState(() => selectedUnitId = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'السعر (ل.س)',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '0'),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final qty = double.tryParse(qtyCtrl.text.trim());
                          final price = double.tryParse(priceCtrl.text.trim());
                          if (selectedProductId == null ||
                              selectedUnitId == null ||
                              qty == null ||
                              price == null) {
                            return;
                          }
                          final productName = products
                              .firstWhere((p) => p.id == selectedProductId)
                              .name;
                          final unitName = units
                              .firstWhere((u) => u.id == selectedUnitId)
                              .name;
                          final navigator = Navigator.of(ctx);
                          final provider = context.read<CatalogProvider>();
                          final ok = isEdit
                              ? await provider.updateOfficialPrice(
                                  existing.id,
                                  productId: selectedProductId!,
                                  productName: productName,
                                  unitId: selectedUnitId!,
                                  unitName: unitName,
                                  amount: qty,
                                  price: price,
                                )
                              : await provider.addOfficialPrice(
                                  productId: selectedProductId!,
                                  productName: productName,
                                  unitId: selectedUnitId!,
                                  unitName: unitName,
                                  amount: qty,
                                  price: price,
                                );
                          navigator.pop();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? (isEdit ? 'تم التعديل' : 'تمت الإضافة')
                                    : (isEdit
                                        ? 'تعذّر التعديل'
                                        : 'تعذّرت الإضافة'),
                              ),
                              backgroundColor:
                                  ok ? AppColors.success : AppColors.error,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(isEdit ? 'حفظ' : 'إضافة'),
                      ),
                    ),
                  ],
                ),
              ],
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
          );
        },
      ),
    );
  }

  /// ✅ جديد — حذف سعر رسمي، مطابقةً لعنصر "حذف" الناقص سابقاً في نفس المخطط.
  Future<void> _confirmDeleteOfficialPrice(OfficialPrice op) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف السعر الرسمي',
      message: 'هل تريد حذف السعر الرسمي لـ"${op.productName}" نهائياً؟',
      confirmText: 'حذف',
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<CatalogProvider>().deleteOfficialPrice(op.id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم الحذف' : 'تعذّر الحذف'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final officialPrices = _search.trim().isEmpty
        ? catalog.officialPrices
        : catalog.officialPrices
            .where((op) => op.productName.contains(_search.trim()))
            .toList();
    return Column(
      children: [
        _AdminGradientHeader(
          title: 'الأسعار الرسمية',
          subtitle: 'أدر الأسعار الرسمية للمنتجات',
          icon: Icons.description_outlined,
          actionLabel: 'إضافة سعر رسمي',
          onAction: () => _showOfficialPriceDialog(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: WaffirSearchField(
            hint: 'ابحث عن منتج...',
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: catalog.isLoading && catalog.officialPrices.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: officialPrices.length,
                  itemBuilder: (ctx, i) {
                    final op = officialPrices[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              op.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            op.quantity.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(op.unit, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 10),
                          Text(
                            '${(op.price / 1000).toStringAsFixed(0)},000 ل.س',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // ✅ جديد — أزرار تعديل/حذف، كانتا غائبتين تماماً
                          // سابقاً رغم إدراجهما في مخطط حالات الاستخدام.
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () =>
                                _showOfficialPriceDialog(context, existing: op),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.error,
                            ),
                            onPressed: () => _confirmDeleteOfficialPrice(op),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ANALYTICS SCREEN
// ✅ إعادة تصميم شاملة (هذا التحديث):
//
//   • بطاقة رسم بياني موحّدة (_ChartCard): رأس ثابت (أيقونة + عنوان + وصف
//     + شارة اختيارية) وجسم قابل للاستبدال، تضمن اتساقاً بصرياً كاملاً بين
//     البطاقات الثلاث بدل حاويات مكررة بتنسيق مختلف قليلاً لكل رسم كما
//     كانت سابقاً.
//
//   • إصلاح جوهري للخط البياني — السبب المباشر لتكدّس كل نقاط الرسم قرب
//     حافة واحدة (كما ظهر فعلياً في لقطة الشاشة المرفقة): كان CustomPaint
//     يقع مباشرة داخل Column بلا أي قيد عرض صريح، فيحصل على قيود عرض غير
//     محدودة (unbounded width) — بالضبط نفس فئة الخلل الموثّقة سابقاً في
//     _PriceEntryCard (products_screen.dart) عند وجود Row غير مرن داخل Row
//     أب. الإصلاح: SizedBox بعرض صريح (double.infinity) وارتفاع ثابت يمنح
//     الرسام مساحة رسم فعلية محدودة، فتُحسب مواضع النقاط بشكل صحيح على
//     كامل عرض البطاقة.
//
//   • الخط البياني نفسه أصبح احترافياً: منحنى بيزيه ناعم (بدل خطوط مستقيمة
//     حادة بين النقاط)، تعبئة متدرجة شفافة أسفل المنحنى، خطوط شبكة أفقية
//     خفيفة، نقطة "القيمة الحالية" مميّزة بحجم أكبر، وشريط علوي من 3
//     إحصائيات مصغّرة (الأعلى/الحالي/الأدنى) فوق الرسم مباشرة.
//
//   • الدونات (توزيع الفئات) أصبح حلقة حقيقية (بدل قرص مملوء بالكامل)،
//     وأهم إصلاح هنا: شرائحه ووسيلته الإيضاحية تُبنيان الآن من نفس مصدر
//     البيانات (_CategorySlice) بدل قائمتين منفصلتين كانتا معرّضتين لعدم
//     التطابق (نسبة شريحة مرسومة تخالف الرقم المكتوب بجانبها).
//
//   • الأعمدة (المنتجات الأكثر نشاطاً) أصبحت بتدرّج لوني وقيمة رقمية مطبوعة
//     فوق كل عمود مباشرة، بدل عمود لوني صرف بلا أي رقم.
//
// الأرقام الثلاثة العلوية (StatCard) تبقى من CatalogProvider.dashboardStats
// كما كانت. الرسوم البيانية الثلاثة تبقى توضيحية عمداً (شارة "تجريبي" على
// بطاقة "نشاط الأسعار") — لا يوجد أي endpoint موثّق حالياً يعيد سلاسل
// بيانات زمنية (chart series)، وهذا موثّق بوضوح في docs/API_ADDENDUM.md
// كنقطة مفتوحة لمطوّر الـ backend.
// ══════════════════════════════════════════════════════════════════════════════
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});
  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().loadDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<CatalogProvider>().dashboardStats;

    // ✅ بيانات توضيحية بانتظار endpoint سلاسل زمنية حقيقي من الخادم
    // (موثّق في docs/API_ADDENDUM.md كنقطة مفتوحة) — راجع الشارة "تجريبي"
    // أسفل عنوان بطاقة "نشاط الأسعار".
    const priceActivity = [
      320.0,
      360.0,
      340.0,
      410.0,
      460.0,
      430.0,
      520.0,
      610.0,
    ];
    const priceActivityLabels = [
      'السبت',
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'اليوم',
    ];

    // ✅ مصدر بيانات واحد للدونات ووسيلته الإيضاحية معاً — يمنع أي تعارض
    // بين نسب الشرائح المرسومة والأرقام المعروضة بجانبها.
    const categorySlices = [
      _CategorySlice('زيوت', 0.35, AppColors.primary),
      _CategorySlice('سكريات', 0.20, Color(0xFF60A5FA)),
      _CategorySlice('حبوب', 0.20, Color(0xFF93C5FD)),
      _CategorySlice('أخرى', 0.25, Color(0xFFBFDBFE)),
    ];

    const topProducts = [
      _BarItem('رز أبيض', 156),
      _BarItem('زيت ذرة', 130),
      _BarItem('طحين', 105),
      _BarItem('سكر', 95),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _AdminGradientHeader(
          title: 'التحليلات والإحصائيات',
          subtitle: 'تتبع الاتجاهات والأنماط في البيانات',
          icon: Icons.bar_chart,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              StatCard(
                icon: Icons.attach_money,
                iconColor: Colors.orange,
                iconBg: Colors.orange.withValues(alpha: 0.1),
                value: '${stats['totalPrices'] ?? '—'}',
                label: 'إجمالي الأسعار',
                growth: stats['pricesGrowth'] != null
                    ? '${stats['pricesGrowth']}%+'
                    : null,
                isPositive: true,
              ),
              const SizedBox(height: 10),
              StatCard(
                icon: Icons.people_outlined,
                iconColor: Colors.green,
                iconBg: Colors.green.withValues(alpha: 0.1),
                value: '${stats['totalUsers'] ?? '—'}',
                label: 'إجمالي المستخدمين',
                growth: stats['usersGrowth'] != null
                    ? '${stats['usersGrowth']}%+'
                    : null,
                isPositive: true,
              ),
              const SizedBox(height: 10),
              StatCard(
                icon: Icons.inventory_2_outlined,
                iconColor: Colors.purple,
                iconBg: Colors.purple.withValues(alpha: 0.1),
                value: '${stats['totalProducts'] ?? '—'}',
                label: 'إجمالي المنتجات',
                growth: stats['productsGrowth'] != null
                    ? '${stats['productsGrowth']}%+'
                    : null,
                isPositive: true,
              ),
              const SizedBox(height: 18),
              _ChartCard(
                title: 'نشاط الأسعار',
                subtitle: 'حركة الأسعار المضافة خلال آخر 8 أيام',
                icon: Icons.show_chart,
                badgeText: 'تجريبي',
                child: const _PriceActivityChart(
                  values: priceActivity,
                  labels: priceActivityLabels,
                ),
              ),
              _ChartCard(
                title: 'توزيع الفئات',
                subtitle: 'نسبة كل فئة من إجمالي المنتجات المسجّلة',
                icon: Icons.donut_large_outlined,
                child: const _CategoryDonutChart(slices: categorySlices),
              ),
              _ChartCard(
                title: 'المنتجات الأكثر نشاطاً',
                subtitle: 'الأعلى في عدد الأسعار المسجّلة من المستخدمين',
                icon: Icons.local_fire_department_outlined,
                child: const _TopProductsBarChart(items: topProducts),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ✅ بطاقة رسم بياني موحّدة — رأس (أيقونة + عنوان + وصف + شارة اختيارية)
// وجسم قابل للاستبدال، تضمن اتساقاً بصرياً كاملاً بين البطاقات الثلاث بدل
// حاويات مكررة بتنسيق مختلف قليلاً لكل رسم كما كان سابقاً.
// ══════════════════════════════════════════════════════════════════════════════
class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final String? badgeText;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppColors.isDark(context) ? 0 : 0.03,
            ),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: AppColors.primary, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// خط بياني — نشاط الأسعار
// ══════════════════════════════════════════════════════════════════════════════
class _PriceActivityChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  const _PriceActivityChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final isDark = AppColors.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MiniStat(
              label: 'الأعلى',
              value: maxV.toStringAsFixed(0),
              color: AppColors.success,
            ),
            _MiniStat(
              label: 'الحالي',
              value: values.last.toStringAsFixed(0),
              color: AppColors.primary,
              highlight: true,
            ),
            _MiniStat(
              label: 'الأدنى',
              value: minV.toStringAsFixed(0),
              color: AppColors.textSecondaryOf(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ══════════════════════════════════════════════════════════════
        // ✅ الإصلاح الجوهري — SizedBox بعرض صريح (double.infinity) يمنح
        // CustomPaint عرضاً محدوداً فعلياً من البطاقة الأب، بدل القيد غير
        // المحدود الذي كان يجعل الرسام يحسب مواضع النقاط بعرض خاطئ فتتكدّس
        // كلها قرب حافة واحدة (هذا بالضبط ما ظهر في لقطة الشاشة).
        // ══════════════════════════════════════════════════════════════
        SizedBox(
          width: double.infinity,
          height: 170,
          child: CustomPaint(
            painter: _LineChartPainter(
              values: values,
              lineColor: AppColors.primary,
              gridColor: AppColors.borderOf(context),
              isDark: isDark,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map(
                (l) => Text(
                  l,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.textHintOf(context),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            '$value ل.س',
            style: TextStyle(
              fontSize: highlight ? 16 : 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      );
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color gridColor;
  final bool isDark;
  _LineChartPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;

    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV) == 0 ? 1 : (maxV - minV);
    final topPad = size.height * 0.12;
    final bottomPad = size.height * 0.12;
    final chartHeight = size.height - topPad - bottomPad;

    // خطوط شبكة أفقية خفيفة
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: isDark ? 0.35 : 0.7)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = topPad + (chartHeight / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // مواضع النقاط
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : (i / (values.length - 1)) * size.width;
      final y =
          topPad + chartHeight - ((values[i] - minV) / range) * chartHeight;
      points.add(Offset(x, y));
    }

    // منحنى بيزيه ناعم يمرّ بكل نقطة
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    // تعبئة متدرجة أسفل المنحنى
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: isDark ? 0.35 : 0.22),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // المنحنى نفسه
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // نقاط + تمييز آخر نقطة (القيمة الحالية)
    for (int i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      final r = isLast ? 6.0 : 3.2;
      canvas.drawCircle(points[i], r, Paint()..color = Colors.white);
      canvas.drawCircle(
        points[i],
        r,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = isLast ? 3 : 2,
      );
      if (isLast) {
        canvas.drawCircle(points[i], 3, Paint()..color = lineColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.isDark != isDark;
}

// ══════════════════════════════════════════════════════════════════════════════
// دونات — توزيع الفئات
// ══════════════════════════════════════════════════════════════════════════════
class _CategorySlice {
  final String label;
  final double ratio; // 0..1
  final Color color;
  const _CategorySlice(this.label, this.ratio, this.color);
}

class _CategoryDonutChart extends StatelessWidget {
  final List<_CategorySlice> slices;
  const _CategoryDonutChart({required this.slices});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _DonutChartPainter(slices: slices),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${slices.length}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  Text(
                    'فئات',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: slices
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                        ),
                        Text(
                          '${(s.ratio * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<_CategorySlice> slices;
  _DonutChartPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;
    double start = -3.14159 / 2;
    for (final s in slices) {
      final sweep = s.ratio * 2 * 3.14159;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        start,
        sweep - 0.04, // فراغ صغير بين الشرائح
        false,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// أعمدة — المنتجات الأكثر نشاطاً
// ══════════════════════════════════════════════════════════════════════════════
class _BarItem {
  final String label;
  final int value;
  const _BarItem(this.label, this.value);
}

class _TopProductsBarChart extends StatelessWidget {
  final List<_BarItem> items;
  const _TopProductsBarChart({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxVal = items.map((b) => b.value).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: items.map((b) {
              final h = maxVal == 0 ? 0.0 : 110 * b.value / maxVal;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${b.value}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 34,
                    height: h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.55),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: items
              .map(
                (b) => SizedBox(
                  width: 60,
                  child: Text(
                    b.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// (بلا تغيير جوهري — تعتمد على AppProvider فقط وهو مربوط بالكامل بالفعل)
// ✅ ملاحظة: هذه الشاشة تحديداً لا تُظهر زر تبديل الثيم في شريط العنوان
// العلوي المشترك في AdminShell (راجع _AdminShellState.build أعلاه)، لأنها
// تحتوي أصلاً بطاقة "الوضع الليلي" الخاصة بها أدناه.
// ══════════════════════════════════════════════════════════════════════════════
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  void _showLanguageInfo() {
    showComingSoonDialog(
      context,
      title: 'اللغة',
      message: 'العربية هي اللغة الوحيدة المتوفرة حالياً في لوحة الإدارة. '
          'دعم لغات إضافية (مثل الإنجليزية) مخطط له في إصدار قادم.',
      icon: Icons.language,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ إصلاح شكل الزر — الإصلاح السابق (SizedBox بعرض كامل) بقي، لكن
  // elevation: 0 مع الاعتماد على لون الثيم الافتراضي فقط جعل الزر يبدو
  // باهتاً وغير واضح الحدود على خلفية النافذة (خصوصاً في الوضع الداكن، حيث
  // يقترب لون الزر من لون الخلفية). الآن يحمل الزر لوناً صريحاً (أزرق
  // العلامة) بتباين كامل مع النص الأبيض، ظلاً خفيفاً يفصله بصرياً عن
  // النافذة، ووزن/حجم خط أكبر — ليكون واضحاً كإجراء أساسي (primary action)
  // بلا لبس.
  //
  // ✅ إصلاح جوهري إضافي — "الصلاحية" كانت نصاً ثابتاً ("مدير النظام") بلا
  // أي ربط فعلي بمستوى صلاحية المستخدم الحقيقي. الآن تُعرض من
  // provider.currentUser?.roleLevelLabel، المبني على roleLevel الرقمي الخام
  // (0/1/2) القادم من الخادم: 1 → "مسؤول"، 2 → "مسؤول رئيسي" (راجع
  // UserModel.roleLevelLabel في models.dart للتفاصيل الكاملة). لا حاجة لأي
  // تعديل آخر: أي مستخدم يفتح لوحة الإدارة هو أصلاً role >= 1 بحكم شرط
  // الدخول، فالقيمة المعروضة هنا دقيقة دوماً بلا حالة افتراضية مضلِّلة.
  // ══════════════════════════════════════════════════════════════════════
  void _showAccountInfo(AppProvider provider) {
    final roleLabel = provider.currentUser?.roleLevelLabel ?? 'مسؤول';
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('معلومات الحساب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                ),
                title: const Text('الاسم'),
                subtitle: Text(provider.userName),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.phone_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('رقم الهاتف'),
                subtitle: Text(provider.userPhone),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('الصلاحية'),
                subtitle: Text(roleLabel),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            // ══════════════════════════════════════════════════════════
            // ✅ إصلاح — كان هذا الزر محصوراً داخل SizedBox بارتفاع ثابت
            // (50) أقل مما يحتاجه النص فعلياً مع علامة التشكيل (التنوين
            // فوق الألف في "حسناً")، فيُقصّ الحرف الأخير عمودياً ويظهر
            // مشوَّهاً/غير مكتمل. الحل: إزالة الارتفاع الثابت المفروض
            // (نفس إصلاح أزرار "حسناً" الأخرى في profile_screen.dart)،
            // مع الاكتفاء بحد أدنى للارتفاع (minimumSize) وحشوة رأسية
            // كافية، بالإضافة إلى height صريح لسطر النص يمنح علامة
            // التشكيل مساحة رأسية كافية لتُعرض كاملة بلا قصّ.
            // ══════════════════════════════════════════════════════════
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'حسناً',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startChangePassword(AppProvider provider) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'تغيير كلمة المرور',
      message: 'سنرسل رمز تحقق عبر رسالة نصية إلى هاتفك ${provider.userPhone} '
          'لتأكيد هويتك قبل تعيين كلمة مرور جديدة.',
      confirmText: 'إرسال الرمز',
      confirmColor: AppColors.primary,
      icon: Icons.lock_reset_outlined,
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.forgotPassword(provider.userPhone);
    if (!mounted) return;
    if (ok) {
      await Navigator.pushNamed(
        context,
        AppRoutes.resetPassword,
        arguments: {'phone': provider.userPhone, 'fromSettings': true},
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'تعذّر إرسال رمز التحقق، حاول مجدداً',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — حارس الدخول إلى "إدارة المسؤولين": يفتح الشاشة فقط إن كان
  // المستخدم الحالي "مسؤول رئيسي" (roleLevel == 2). أي مستوى أدنى (roleLevel
  // == 1، "مسؤول عادي") يتلقى إشعاراً صريحاً بعدم امتلاك الصلاحية بدل فتح
  // الشاشة صامتاً أو ظهور خطأ غير مفهوم لاحقاً. هذا الحارس هو خط الدفاع
  // الأول (منع فتح الشاشة أصلاً من نقطة الدخول الوحيدة لها)، بالإضافة إلى
  // حارس دفاعي ثانٍ داخل AdminAdminsScreen نفسها (راجع أسفل الملف) تحسباً
  // لأي وصول مباشر مستقبلي.
  // ══════════════════════════════════════════════════════════════════════
  void _openAdminsManagement(AppProvider provider) {
    if (provider.currentUser?.roleLevel != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'غير مسموح لك بالدخول إلى إدارة المسؤولين — هذه الصلاحية حصرية لحساب مسؤول رئيسي',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminAdminsScreen()),
    );
  }

  Future<void> _confirmLogout(AppProvider provider) async {
    final ok = await showConfirmDialog(
      context,
      title: 'تأكيد تسجيل الخروج',
      message: 'هل أنت متأكد من رغبتك في تسجيل الخروج من لوحة الإدارة؟',
      confirmText: 'تسجيل الخروج',
      icon: Icons.logout,
    );
    if (ok == true && mounted) {
      await provider.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.splash,
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _AdminGradientHeader(
          title: 'إعدادات الإدارة',
          subtitle: 'أدر تفضيلات وإعدادات لوحة الإدارة',
          icon: Icons.settings_outlined,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const _AdminSectionHeader('تفضيلات لوحة الإدارة'),
              _AdminCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'الوضع الليلي',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 26,
                          child: Center(
                            child: Text(
                              provider.isDarkMode ? '☀️' : '🌙',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: provider.isDarkMode,
                      onChanged: (_) => provider.toggleDarkMode(),
                      activeThumbColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const _AdminSectionHeader('الإشعارات'),
              const _AdminNotificationsSection(),
              const _AdminSectionHeader('الأمان'),
              _AdminCard(
                child: _tappableRow(
                  onTap: () => _startChangePassword(provider),
                  label: 'تغيير كلمة المرور',
                  emoji: '🔐',
                ),
              ),
              const _AdminSectionHeader('إعدادات الحساب'),
              _AdminCard(
                child: _tappableRow(
                  onTap: () => _showAccountInfo(provider),
                  label: 'معلومات الحساب',
                  emoji: '👤',
                ),
              ),
              _AdminCard(
                // ══════════════════════════════════════════════════════
                // ✅ إصلاح جوهري — كانت "صلاحيات المسؤولين" مجرد نافذة
                // "قيد التطوير" بلا أي وظيفة فعلية. مخطط حالات الاستخدام
                // يُدرج "عرض المسؤولين" كحالة استخدام مستقلة كاملة ضمن
                // الإعدادات، مع extend إلى: إضافة/تعديل/بحث/حذف مسؤول.
                // الآن تُفتح شاشة AdminAdminsScreen المخصّصة بالكامل لهذا
                // الغرض (راجع أسفل الملف).
                //
                // ✅ جديد — حارس صلاحية: "إدارة المسؤولين" أصبحت متاحة حصراً
                // لحساب "مسؤول رئيسي" (roleLevel == 2، راجع
                // UserModel.roleLevelLabel في models.dart). أي مسؤول بمستوى
                // أدنى (roleLevel == 1، "مسؤول") يحاول الدخول يتلقى إشعاراً
                // صريحاً برفض الدخول بدل فتح الشاشة، عبر _openAdminsManagement
                // أدناه.
                // ══════════════════════════════════════════════════════
                child: _tappableRow(
                  onTap: () => _openAdminsManagement(provider),
                  label: 'إدارة المسؤولين',
                  emoji: '🛡️',
                ),
              ),
              _AdminCard(
                child: _tappableRow(
                  onTap: () => _confirmLogout(provider),
                  label: 'تسجيل الخروج',
                  emoji: '🚪',
                  labelColor: AppColors.error,
                ),
              ),
              const _AdminSectionHeader('التطبيق'),
              _AdminCard(
                child: _tappableRow(
                  onTap: _showLanguageInfo,
                  label: 'اللغة',
                  emoji: '🌍',
                  trailingText: 'العربية',
                ),
              ),
              _AdminCard(
                child: _tappableRow(
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.privacyPolicy),
                  label: 'سياسة الخصوصية',
                  emoji: '🛡',
                ),
              ),
              _AdminCard(
                child: _tappableRow(
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.termsOfService),
                  label: 'الشروط والأحكام',
                  emoji: '📋',
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'نظام إدارة وفّر\nالإصدار 1.0.0',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tappableRow({
    required VoidCallback onTap,
    required String label,
    required String emoji,
    String? trailingText,
    Color? labelColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 26,
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.arrow_back_ios,
                size: 14,
                color: labelColor ?? AppColors.textHint,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminNotificationsSection extends StatefulWidget {
  const _AdminNotificationsSection();
  @override
  State<_AdminNotificationsSection> createState() =>
      _AdminNotificationsSectionState();
}

class _AdminNotificationsSectionState
    extends State<_AdminNotificationsSection> {
  bool _emailNotif = true;
  bool _priceNotif = true;
  bool _reportNotif = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _emailNotif = prefs.getBool('admin_notif_email') ?? true;
      _priceNotif = prefs.getBool('admin_notif_price') ?? true;
      _reportNotif = prefs.getBool('admin_notif_report') ?? true;
    });
  }

  Future<void> _set(String key, bool value, VoidCallback apply) async {
    setState(apply);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        (
          _emailNotif,
          'إشعارات البريد الإلكتروني',
          '📧',
          (bool v) {
            _set('admin_notif_email', v, () => _emailNotif = v);
          },
        ),
        (
          _priceNotif,
          'تنبيهات الأسعار الجديدة',
          '💰',
          (bool v) {
            _set('admin_notif_price', v, () => _priceNotif = v);
          },
        ),
        (
          _reportNotif,
          'تنبيهات البلاغات',
          '🚨',
          (bool v) {
            _set('admin_notif_report', v, () => _reportNotif = v);
          },
        ),
      ]
          .map(
            (item) => _AdminCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Flexible(
                          child: Text(
                            item.$2,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 26,
                          child: Center(
                            child: Text(
                              item.$3,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: item.$1,
                    onChanged: item.$4,
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AdminSectionHeader extends StatelessWidget {
  final String text;
  const _AdminSectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}

class _AdminCard extends StatelessWidget {
  final Widget child;
  const _AdminCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: child,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ✅ جديد بالكامل — ADMINS SCREEN ("عرض المسؤولين")
// حالة استخدام مستقلة كانت غائبة تماماً عن التطبيق رغم وجودها صراحة في
// مخطط حالات الاستخدام ضمن قسم الإعدادات، مع extend إلى: إضافة مسؤول،
// تعديل معلومات مسؤول، البحث عن مسؤول، حذف مسؤول.
//
// ✅ ملاحظة تصميمية مهمة: جدول User في قاعدة البيانات الفعلية
// (Waffir_Database.txt) لا يحتوي جدولاً منفصلاً للمسؤولين — الأدوار كلها
// أعمدة role على نفس جدول User. لذا "المسؤولون" هنا هم ببساطة مستخدمون
// بقيمة role مرتفعة (راجع UserModel._parseRole في models.dart)، وتُبنى
// هذه الشاشة فوق نفس AdminUsersProvider المستخدم في "إدارة المستخدمين"
// (دون طلب شبكة منفصل):
//   • عرض  → AdminUsersProvider.admins (مُشتقّة من users المُحمَّلة)
//   • بحث  → فلترة محلية على الاسم/الهاتف
//   • إضافة → AdminUsersProvider.createUser(role: 'admin') — إنشاء حساب
//             مسؤول جديد مباشرة من هنا
//   • تعديل → AdminUsersProvider.updateUser (تعديل الاسم)
//   • حذف  → تُفسَّر هنا كـ"إزالة صلاحية الإدارة" (إعادة الدور إلى
//             'user' عبر setRole) وليس حذف الحساب بالكامل، لتفادي حذف
//             مستخدم قد يملك محتوى مرتبطاً به (أسعار، بلاغات...) بصورة
//             لا رجعة فيها من نافذة لا علاقة موضوعها بذلك مباشرة. إن أراد
//             ohayo لاحقاً حذفاً فعلياً للحساب بدل التخفيض، يمكن استبدال
//             الاستدعاء بسهولة بـ AdminUsersProvider.deleteUser.
// ══════════════════════════════════════════════════════════════════════════════
class AdminAdminsScreen extends StatefulWidget {
  const AdminAdminsScreen({super.key});

  @override
  State<AdminAdminsScreen> createState() => _AdminAdminsScreenState();
}

class _AdminAdminsScreenState extends State<AdminAdminsScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminUsersProvider>();
      if (provider.users.isEmpty) provider.loadUsers();
    });
  }

  /// ✅ جديد — نفس نمط تنسيق التاريخ المستخدم في AdminUsersScreen
  /// (_formatCreatedAt)، يطابق عمود User.created_at الفعلي في قاعدة
  /// البيانات. يُعيد '—' عند غياب القيمة (حساب مسؤول قديم بلا هذا الحقل).
  String _formatCreatedAt(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ محدَّث — أُضيفت إمكانية تغيير كلمة مرور المسؤول مباشرة من نفس نافذة
  // "تعديل معلومات المسؤول": حقل جديد اختياري تماماً (كلمة مرور جديدة)،
  // بأيقونة إظهار/إخفاء ونفس قاعدة التحقق المعتمدة في بقية شاشات التطبيق
  // (6 أحرف على الأقل إن كُتب فيه أي نص). يُترك فارغاً لإبقاء كلمة المرور
  // الحالية دون أي تغيير — عندها لا يُرسَل الحقل إطلاقاً للخادم (راجع
  // AdminUsersProvider.updateUser وAdminUserService.updateUser).
  // ══════════════════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — حقل "رقم الهاتف" أُضيف إلى نافذة "تعديل معلومات المسؤول"،
  // بين حقل الاسم وحقل كلمة المرور، بنفس نمط حقول الهاتف المعتمد في بقية
  // شاشات التطبيق (keyboardType: phone، اتجاه LTR للأرقام، أيقونة هاتف).
  // يُعبَّأ مسبقاً برقم المسؤول الحالي (admin.phone)، ويخضع لتحقق أساسي
  // (لا يمكن حفظه فارغاً) بنفس أسلوب رسائل الخطأ الظاهرة أسفل الحقل
  // المستخدَم أصلاً لحقل كلمة المرور (phoneError/passwordError، تُخفى
  // تلقائياً فور تعديل النص). القيمة الجديدة تُمرَّر إلى
  // AdminUsersProvider.updateUser عبر الوسيط [phone] الجديد.
  // ══════════════════════════════════════════════════════════════════════
  void _showEditAdmin(UserModel admin) {
    final nameCtrl = TextEditingController(text: admin.name);
    final phoneCtrl = TextEditingController(text: admin.phone);
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;
    String? phoneError;
    String? passwordError;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'تعديل معلومات المسؤول',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الاسم الكامل', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 16),
                  // ✅ جديد — تعديل رقم الهاتف
                  const Text('رقم الهاتف', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    onChanged: (v) {
                      if (phoneError != null) {
                        setDialogState(() => phoneError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'مثال: 0944123456',
                      hintStyle: TextStyle(
                        color: AppColors.textHintOf(ctx),
                        fontSize: 12.5,
                      ),
                      errorText: phoneError,
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ✅ جديد — تغيير كلمة المرور (اختياري)
                  const Text(
                    'كلمة مرور جديدة (اختياري)',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: obscurePassword,
                    textDirection: TextDirection.ltr,
                    onChanged: (v) {
                      if (passwordError != null) {
                        setDialogState(() => passwordError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'اتركه فارغاً لعدم تغيير كلمة المرور',
                      hintStyle: TextStyle(
                        color: AppColors.textHintOf(ctx),
                        fontSize: 12.5,
                      ),
                      errorText: passwordError,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: AppColors.textHintOf(ctx),
                        ),
                        onPressed: () => setDialogState(
                          () => obscurePassword = !obscurePassword,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        final newPhone = phoneCtrl.text.trim();
                        if (newPhone.isEmpty || newPhone.length < 8) {
                          setDialogState(
                            () => phoneError = 'أدخل رقم هاتف صحيح',
                          );
                          return;
                        }
                        final newPassword = passwordCtrl.text.trim();
                        if (newPassword.isNotEmpty && newPassword.length < 6) {
                          setDialogState(
                            () => passwordError =
                                'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
                          );
                          return;
                        }
                        final navigator = Navigator.of(ctx);
                        final ok =
                            await context.read<AdminUsersProvider>().updateUser(
                                  admin.id,
                                  name: nameCtrl.text.trim(),
                                  phone: newPhone,
                                  password:
                                      newPassword.isEmpty ? null : newPassword,
                                );
                        navigator.pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'تم تحديث البيانات' : 'تعذّر التحديث',
                            ),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.error,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemoveAdmin(UserModel admin) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف مسؤول',
      message:
          'هل تريد إزالة "${admin.name}" من قائمة المسؤولين؟ سيعود حسابه إلى صلاحية مستخدم عادي.',
      confirmText: 'حذف',
      icon: Icons.person_remove_outlined,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<AdminUsersProvider>().setRole(
          admin.id,
          'user',
        );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم حذف المسؤول' : 'تعذّر تنفيذ الإجراء'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ محدَّث — حُذف حقل "الكتلة والمنطقة" نهائياً من نافذة "إضافة مسؤول
  // جديد" بناءً على طلب صريح: المسؤولون (على خلاف المستخدمين العاديين) لا
  // يرتبطون بحي أو كتلة إدارية معيّنة، فلا داعٍ لإجبار من يضيفهم على اختيار
  // موقع لا معنى فعلياً له بالنسبة لحساب مسؤول. النافذة الآن تقتصر على 3
  // حقول فقط: الاسم الكامل، رقم الهاتف، كلمة المرور المبدئية — بلا أي منتقي
  // موقع، وبلا أي حاجة لتحميل قائمة المواقع (راجع أيضاً حذف تحميل
  // CatalogProvider.locations من initState أعلاه).
  // ══════════════════════════════════════════════════════════════════════
  void _showAddAdmin(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'إضافة مسؤول جديد',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الاسم الكامل', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'مثال: أحمد محمد',
                    hintStyle: TextStyle(
                      color: AppColors.textHintOf(ctx),
                      fontSize: 12.5,
                    ),
                    helperText: 'اكتب الاسم كما سيظهر في لوحة الإدارة',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('رقم الهاتف', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: 'مثال: 0944123456',
                    hintStyle: TextStyle(
                      color: AppColors.textHintOf(ctx),
                      fontSize: 12.5,
                    ),
                    helperText: 'سيُستخدم الرقم لتسجيل الدخول إلى الحساب',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'كلمة المرور المبدئية',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: 'أنشئ كلمة مرور من 6 أحرف على الأقل',
                    hintStyle: TextStyle(
                      color: AppColors.textHintOf(ctx),
                      fontSize: 12.5,
                    ),
                    helperText:
                        'استخدم مزيجاً من الأحرف والأرقام لحماية الحساب',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          phoneCtrl.text.trim().isEmpty ||
                          passwordCtrl.text.trim().length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يرجى تعبئة كل الحقول بشكل صحيح'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      final navigator = Navigator.of(ctx);
                      final ok =
                          await context.read<AdminUsersProvider>().createUser(
                                name: nameCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                password: passwordCtrl.text,
                                // ✅ لا موقع لحساب المسؤول — يُرسَل معرّفاً
                                // فارغاً بما أن الحقل حُذف من الواجهة.
                                locationId: '',
                                role: 'admin',
                              );
                      navigator.pop();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok ? 'تمت إضافة المسؤول' : 'تعذّرت الإضافة',
                          ),
                          backgroundColor:
                              ok ? AppColors.success : AppColors.error,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('إضافة'),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ══════════════════════════════════════════════════════════════════
    // ✅ جديد — حارس دفاعي ثانٍ: هذه الشاشة حصرية لحساب "مسؤول رئيسي"
    // (roleLevel == 2). خط الدفاع الأول هو _openAdminsManagement في
    // AdminSettingsScreen أعلاه (يمنع فتح الشاشة أصلاً من نقطة الدخول
    // الوحيدة لها ضمن الإعدادات)؛ هذا الحارس هنا حماية إضافية تحسباً لأي
    // وصول مباشر مستقبلي لهذه الشاشة (مثال: رابط عميق/Deep link).
    // ══════════════════════════════════════════════════════════════════
    final appProvider = context.watch<AppProvider>();
    if (appProvider.currentUser?.roleLevel != 2) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('إدارة المسؤولين'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppColors.error,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا تملك صلاحية الوصول',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'الدخول إلى إدارة المسؤولين متاح حصرياً لحساب مسؤول رئيسي',
                    style: TextStyle(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final provider = context.watch<AdminUsersProvider>();
    final admins = _search.trim().isEmpty
        ? provider.admins
        : provider.admins
            .where(
              (a) =>
                  a.name.contains(_search.trim()) ||
                  a.phone.contains(_search.trim()),
            )
            .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المسؤولين'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            _AdminGradientHeader(
              title: 'عرض المسؤولين',
              subtitle: 'أدر حسابات المسؤولين',
              icon: Icons.shield_outlined,
              actionLabel: 'إضافة مسؤول',
              onAction: () => _showAddAdmin(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: WaffirSearchField(
                hint: 'ابحث عن اسم أو رقم هاتف مسؤول...',
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: provider.isLoading && provider.users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : admins.isEmpty
                      ? Center(
                          child: Text(
                            'لا يوجد مسؤولون مطابقون',
                            style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: admins.length,
                          itemBuilder: (ctx, i) {
                            final a = admins[i];
                            // ══════════════════════════════════════════
                            // ✅ محدَّث — إعادة تنظيم البطاقة على صفَّين
                            // بدل صف واحد مزدحم: الصف الأول (الأيقونة +
                            // الاسم + زرّا التعديل/الحذف)، والصف الثاني
                            // (رقم الهاتف + شارة "تاريخ إنشاء الحساب"
                            // الجديدة، بنفس نمط شارات التاريخ المستخدمة في
                            // AdminUsersScreen وAdminPriceReviewScreen أعلاه
                            // في هذا الملف). تاريخ الإنشاء يطابق عمود
                            // User.created_at الفعلي في قاعدة البيانات.
                            // ══════════════════════════════════════════
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceOf(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.borderOf(context),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.purple.withValues(
                                            alpha: 0.1,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.shield_outlined,
                                          size: 16,
                                          color: Colors.purple,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          a.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: AppColors.textSecondary,
                                        ),
                                        onPressed: () => _showEditAdmin(a),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.person_remove_outlined,
                                          size: 18,
                                          color: AppColors.error,
                                        ),
                                        onPressed: () => _confirmRemoveAdmin(a),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.phone_outlined,
                                            size: 12,
                                            color:
                                                AppColors.textHintOf(context),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            a.phone,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      // ✅ جديد — شارة تاريخ إنشاء الحساب
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.textHintOf(
                                            context,
                                          ).withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.calendar_today_outlined,
                                              size: 11,
                                              color: AppColors.textSecondaryOf(
                                                context,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatCreatedAt(a.createdAt),
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color:
                                                    AppColors.textSecondaryOf(
                                                  context,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
