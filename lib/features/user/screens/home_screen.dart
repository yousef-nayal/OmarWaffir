import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_provider.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';

// ✅ تحويل إلى StatefulWidget: كانت الشاشة تقرأ MockData.products و
// MockData.recentActivity مباشرة بغض النظر عن AppConfig.useMockData. الآن
// تُحمَّل من ProductProvider/CatalogProvider في initState.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = context.read<ProductProvider>();
      final catalogProvider = context.read<CatalogProvider>();
      final appProvider = context.read<AppProvider>();
      // ✅ قائمة المواقع الحقيقية لازمة لترجمة الحي المختار إلى location_id
      // قبل أي استعلام حسّاس للموقع.
      if (catalogProvider.locations.isEmpty) catalogProvider.loadLocations();
      if (productProvider.products.isEmpty) {
        productProvider.loadProducts(
          locationId: appProvider.selectedLocationId,
        );
      }
      // ✅ إصلاح — كانت الشاشة تُحمّل GET /admin/recent-activity وهو مسار
      // إداري محمي بـ role:1، فيعود بـ 403 لكل مستخدم عادي وتبقى قائمة
      // الإشعارات فارغة. الإشعارات الحقيقية للمستخدم لها مسارها الخاص.
      context.read<NotificationProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDarkMode;
    final productProvider = context.watch<ProductProvider>();
    final gapProducts = productProvider.products.take(5).toList();
    // ✅ إشعارات المستخدم الحقيقية (GET /notifications)، لا سجل النشاط
    // الإداري الذي كان يُطلب سابقاً ويعود بـ 403.
    final notifications = context.watch<NotificationProvider>().notifications;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Blue gradient header ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ══════════════════════════════════════════════════
                      // ✅ إصلاح جوهري لمطابقة التصميم المرجعي: كانت شريحة
                      // الموقع تظهر في المنتصف تقريباً (بسبب spaceBetween
                      // مع 3 عناصر منفصلة)، وأيقونة الإشعارات معزولة في
                      // أقصى اليسار عن أيقونة الثيم. الآن العنصر الأول في
                      // القائمة (شريحة الموقع) يرتكز في أقصى اليمين — بداية
                      // الصف في RTL — وعنصر ثانٍ واحد يجمع أيقونتي الإشعارات
                      // والثيم معاً في أقصى اليسار، تماماً كما في التصميم
                      // المرجعي (🔔 🌙 ..... ▾ الموقع 📍).
                      // ══════════════════════════════════════════════════
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // شريحة الموقع — أقصى اليمين
                          GestureDetector(
                            onTap: () => _showLocationPicker(context, provider),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text(provider.userLocation,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down,
                                      color: Colors.white, size: 16),
                                ],
                              ),
                            ),
                          ),
                          // مجموعة الأيقونات — أقصى اليسار (الثيم أولاً حتى
                          // يقع بصرياً بجوار الإشعارات مباشرة على يمينها،
                          // فتظهر الإشعارات في أقصى الطرف كما في التصميم
                          // المرجعي)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: provider.toggleDarkMode,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isDark
                                        ? Icons.light_mode_outlined
                                        : Icons.dark_mode_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () =>
                                    _showNotifications(context, notifications),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.notifications_outlined,
                                      color: Colors.white,
                                      size: 20),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                          '👋 مرحباً ${provider.userName.isNotEmpty ? provider.userName.split(' ').first : ''}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700)),
                      // ✅ عرض الكتلة الإدارية تحت اسم الترحيب مباشرة، ليكون
                      // واضحاً للمستخدم أي كتلة يتابع أسعارها حالياً.
                      Text('${provider.userBlock} — تابع الأسعار واعرف الفرق',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14)),
                      const SizedBox(height: 20),
                      // ══════════════════════════════════════════════════
                      // ✅ إصلاح جوهري — كانت هذه الأرقام الثلاثة ثابتة في
                      // الكود ('16'، '8'، '24')، فتُعرض كما هي حتى بعد ربط
                      // الـ backend الحقيقي، أي بيانات عمل وهمية على شاشة
                      // إنتاجية. أصبحت الآن محسوبة من المنتجات المُحمَّلة
                      // فعلياً من الخادم للموقع المختار:
                      //   • أسعار معقولة  = السعر السوقي ≤ السعر الرسمي
                      //   • أسعار مرتفعة  = السعر السوقي > السعر الرسمي
                      //   • منتجات مراقبة = إجمالي المنتجات في الخادم
                      // المنتجات التي لا تملك أي سعر سوقي بعد (real = 0) لا
                      // تُحتسَب ضمن "معقولة" أو "مرتفعة" لأنها ببساطة بلا
                      // بيانات سوق، لا رخيصة ولا غالية.
                      // ══════════════════════════════════════════════════
                      Builder(builder: (context) {
                        final products =
                            context.watch<ProductProvider>().products;
                        final priced = products
                            .where((p) => p.realPrice > 0 && p.officialPrice > 0)
                            .toList();
                        final high = priced
                            .where((p) => p.realPrice > p.officialPrice)
                            .length;
                        final fair = priced.length - high;
                        final monitored =
                            context.watch<ProductProvider>().totalProducts;

                        return Row(children: [
                          _StatChip(
                              value: '$fair',
                              label: 'أسعار معقولة',
                              icon: Icons.check_circle_outline,
                              accentColor: AppColors.success),
                          const SizedBox(width: 10),
                          _StatChip(
                              value: '$high',
                              label: 'أسعار مرتفعة',
                              icon: Icons.trending_up,
                              accentColor: AppColors.error),
                          const SizedBox(width: 10),
                          _StatChip(
                              value: '$monitored',
                              label: 'منتجات مراقبة',
                              icon: Icons.bar_chart,
                              accentColor: Colors.white),
                        ]);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.officialPrices),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.success.withValues(alpha: 0.14)
                          : AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(16)),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_outlined,
                                color: Colors.white, size: 24),
                            SizedBox(height: 2),
                            Text('الأسعار الرسمية',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('أسعار التموين المعتمدة',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                        'تحقق من السعر الرسمي قبل الشراء',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white60
                                                : AppColors.textSecondary)),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_back_ios,
                                      size: 12, color: AppColors.success),
                                ]),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),

                // Section header
                // ══════════════════════════════════════════════════════
                // ✅ إصلاح RTL: كان زر "عرض الكل" أول عنصر في القائمة
                // فيظهر في أقصى اليمين والعنوان "أكبر الفروقات" في أقصى
                // اليسار — معكوس تماماً عن التصميم المرجعي (العنوان+الشارة
                // يمين، الزر "عرض الكل ←" يسار). الآن العنوان أولاً.
                // ══════════════════════════════════════════════════════
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Text('أكبر الفروقات',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('مقارنة مع السعر الرسمي',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.products),
                      icon: const Icon(Icons.arrow_back_ios, size: 12),
                      label: const Text('عرض الكل'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: EdgeInsets.zero),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Product gap cards
                if (productProvider.isLoading && gapProducts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  ...gapProducts
                      .map((p) => _ProductGapCard(product: p, isDark: isDark)),

                // ✅ أُزيل قسم "آخر النشاطات" وما تحته من الشاشة الرئيسية
                // بطلب مباشر. البيانات (userActivity) ما زالت تُحمَّل
                // وتُستخدم في نافذة الإشعارات (_showNotifications) التي
                // يفتحها زر الجرس في الرأس، فلم يُحذف أي منطق تحميل بيانات
                // — فقط قسم العرض هذا في الجسم الرئيسي للشاشة.
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ محدَّث — بعد اختيار الحي نترجمه إلى location_id حقيقي عبر
  // CatalogProvider (المواقع المحمَّلة من الخادم)، نحفظه، ثم نُعيد تحميل
  // المنتجات به حتى تعكس الأسعار السوقية المعروضة الحي الجديد فعلياً.
  void _showLocationPicker(BuildContext context, AppProvider provider) {
    showLocationPickerSheet(
      context,
      currentBlock: provider.userBlock,
      currentArea: provider.userLocation,
      onSelect: (block, area) async {
        final catalogProvider = context.read<CatalogProvider>();
        if (catalogProvider.locations.isEmpty) {
          await catalogProvider.loadLocations();
        }
        final locationId = catalogProvider.locationIdForArea(area);
        await provider.updateLocation(
          block: block,
          area: area,
          locationId: locationId,
        );
        if (!context.mounted) return;
        await context.read<ProductProvider>().loadProducts(
              locationId: provider.selectedLocationId,
              refresh: true,
            );
      },
    );
  }

  void _showNotifications(
      BuildContext context, List<AppNotification> notifications) {
    // فتح القائمة يعني أن المستخدم اطّلع عليها.
    context.read<NotificationProvider>().markAllRead();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الإشعارات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('لا توجد إشعارات جديدة'),
                )
              else
                ...notifications.take(5).map((n) => ListTile(
                      leading: Icon(
                          n.type == 'official_price'
                              ? Icons.description_outlined
                              : Icons.attach_money,
                          color: AppColors.primary),
                      title: Text(n.body,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(n.relativeTime,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color accentColor;
  const _StatChip({
    required this.value,
    required this.label,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Icon(icon, color: accentColor, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 9,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _ProductGapCard extends StatelessWidget {
  final ProductModel product;
  final bool isDark;
  const _ProductGapCard({required this.product, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final diff = product.realPrice - product.officialPrice;
    final isUp = diff > 0;
    final cardColor = Theme.of(context).cardColor;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.productDetail,
          arguments: product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          // Price diff badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isUp
                  ? AppColors.error.withValues(alpha: isDark ? 0.2 : 0.1)
                  : AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Icon(isUp ? Icons.trending_up : Icons.trending_down,
                  color: isUp ? AppColors.error : AppColors.success, size: 16),
              Text('${product.changePercent.toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: isUp ? AppColors.error : AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimary)),
              Text(product.category,
                  style: TextStyle(
                      color: isDark ? Colors.white54 : AppColors.textSecondary,
                      fontSize: 12)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_f(product.realPrice)} ل.س',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    const Text('حقيقي',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
                const SizedBox(width: 10),
                Container(
                    height: 26,
                    width: 1,
                    color: isDark ? Colors.white24 : AppColors.border),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_f(product.officialPrice)} ل.س',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning)),
                    const Text('رسمي',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning)),
                  ],
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_back_ios,
              size: 14, color: isDark ? Colors.white30 : AppColors.textHint),
        ]),
      ),
    );
  }

  String _f(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(0)},000' : v.toStringAsFixed(0);
}
