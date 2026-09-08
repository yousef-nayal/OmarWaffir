import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/aleppo_blocks.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PRODUCTS SCREEN
// ✅ الآن تقرأ من ProductProvider (يتحول تلقائياً بين MockData والـ backend
// الحقيقي حسب AppConfig.useMockData) بدل قراءة MockData.products مباشرة.
// ══════════════════════════════════════════════════════════════════════════════
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _filter = 'الكل';
  // ✅ إصلاح — كانت التصنيفات قائمة ثابتة في الكود ('حبوب'، 'سكريات'...) لا
  // تطابق أي قيمة فعلية في عمود products.category (التي هي 'حبوب ومطاحن'،
  // 'سكريات ومؤن'...)، فكان أي فلترة تُرجع قائمة فارغة دائماً. أصبحت الآن
  // تُقرأ من GET /products/categories.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalogProvider = context.read<CatalogProvider>();
      if (catalogProvider.locations.isEmpty) catalogProvider.loadLocations();
      final productProvider = context.read<ProductProvider>();
      productProvider.loadCategories();
      // ✅ الأسعار السوقية المعروضة خاصة بالحي المختار حالياً.
      productProvider.loadProducts(
            locationId: context.read<AppProvider>().selectedLocationId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDarkMode;
    final productProvider = context.watch<ProductProvider>();
    final allProducts = productProvider.products;
    final products = _filter == 'الكل'
        ? allProducts
        : allProducts.where((p) => p.category == _filter).toList();

    // ✅ إصلاح RTL: هذه الشاشة مسجّلة كمسار مستقل (AppRoutes.products) في
    // main.dart، بالإضافة لكونها أحد أطفال IndexedStack داخل UserShell.
    // التغليف الصريح هنا يضمن RTL في الحالتين، بدل الاعتماد فقط على
    // Directionality التي توفّرها UserShell عند الوصول عبر شريط التنقل.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Column(
          children: [
            // ── رأس متدرّج أزرق — بنفس نمط الصفحة الرئيسية وشاشة المتاجر
            // ليكون التصميم متناسقاً في كل واجهات التطبيق ─────────────────
            Container(
              width: double.infinity,
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // ✅ عنوان "المنتجات" في المنتصف
                      const Text('المنتجات',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                      // ✅ زر الثيم على اليسار بشكل موحد في جميع الواجهات
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
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
                                size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: WaffirSearchField(
                hint: 'ابحث عن منتج...',
                onChanged: (v) => context.read<ProductProvider>().loadProducts(
                      search: v,
                      category: _filter == 'الكل' ? null : _filter,
                      locationId:
                          context.read<AppProvider>().selectedLocationId,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilterChipRow(
                  options: context.watch<ProductProvider>().categories,
                  selected: _filter,
                  // ✅ الفلترة أصبحت تُنفَّذ على الخادم أيضاً، لا على الصفحة
                  // المُحمَّلة محلياً فقط — وإلا فإن اختيار تصنيف مع تفعيل
                  // الترقيم يعرض نتائج الصفحة الأولى فقط.
                  onSelected: (v) {
                    setState(() => _filter = v);
                    context.read<ProductProvider>().loadProducts(
                          category: v == 'الكل' ? null : v,
                          locationId:
                              context.read<AppProvider>().selectedLocationId,
                          refresh: true,
                        );
                  }),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: productProvider.isLoading && products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : products.isEmpty
                      ? Center(
                          child: Text('لا توجد منتجات',
                              style: TextStyle(
                                  color: AppColors.textSecondaryOf(context))))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: products.length,
                          itemBuilder: (ctx, i) => _ProductCard(
                            product: products[i],
                            onTap: () => Navigator.pushNamed(
                                ctx, AppRoutes.productDetail,
                                arguments: products[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            PriceChangeBadge(
                percent: product.changePercent, isUp: product.isPriceUp),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryOf(context))),
                    Text(product.category,
                        style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 12)),
                    const SizedBox(height: 6),
                    // ✅ عرض السعرين بوضوح: الحقيقي على اليمين بلون مميز، والرسمي
                    // على اليسار بلون مميز آخر بدل الخط المشطوب الباهت سابقاً.
                    Row(children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_f(product.realPrice)} ل.س/${product.unit}',
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
                          height: 24,
                          width: 1,
                          color: isDark ? Colors.white24 : AppColors.border),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_f(product.officialPrice)} ل.س',
                              style: const TextStyle(
                                  fontSize: 12,
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
          ],
        ),
      ),
    );
  }

  String _f(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(0)},000' : v.toStringAsFixed(0);
}

// ══════════════════════════════════════════════════════════════════════════════
// PRODUCT DETAIL SCREEN
// ✅ تحويل إلى StatefulWidget: تُحمَّل أسعار هذا المنتج تحديداً عبر
// PriceProvider.loadProductPrices(product.id) بدل عرض MockData.priceEntries
// (التي لم تكن حتى مرتبطة بالمنتج المعروض). كما أُضيف تصويت فعلي
// (إعجاب/عدم إعجاب) وزر بلاغ فعلي يفتحان الآن PriceProvider/ReportProvider
// بدل أن يكونا مجرّد نص بلا استجابة.
//
// ✅ إصلاح جوهري إضافي — كانت الشاشة ترجع صامتاً إلى MockData.products.first
// كلما وصل إليها المستخدم بلا وسيط (arguments) صالح من نوع ProductModel،
// حتى في وضع الإنتاج (AppConfig.useMockData = false). هذا يعني أن أي خطأ
// برمجي مستقبلي في مكان استدعاء Navigator.pushNamed (وسيط مفقود أو من نوع
// خاطئ) كان سيُخفى تماماً بعرض منتج وهمي ("رز أبيض" الثابت) بدل كشف الخطأ،
// وقد يعرض المستخدم لبيانات مضلِّلة (أسعار/تفاصيل منتج لا علاقة له بما
// نقر عليه فعلياً). الآن: إن لم يصل وسيط صالح، تُعرض حالة خطأ صريحة بنفس
// نمط OfficialPriceHistoryScreen، ولا يُستدعى تحميل الأسعار إطلاقاً بمعرّف
// منتج وهمي.
// ══════════════════════════════════════════════════════════════════════════════
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductModel? _product;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      _product = args is ProductModel ? args : null;
      _initialized = true;
      if (_product != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<PriceProvider>().loadProductPrices(_product!.id);
        });
      }
    }
  }

  Future<void> _reportEntry(PriceEntry entry) async {
    final reason = await showDialog<_ReportReason>(
      context: context,
      builder: (ctx) => const _ReportDialog(),
    );
    if (reason == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // ══════════════════════════════════════════════════════════════════
    // ✅ جديد — reason.note يحمل النص الذي كتبه المستخدم (إجباري فقط عند
    // اختيار "أخرى"، اختياري لبقية الأسباب). يُرسَل الآن تحت مفتاح
    // description الفعلي عبر ReportService (راجع report_service.dart).
    // ══════════════════════════════════════════════════════════════════
    final ok = await context.read<ReportProvider>().submitReport(
        priceEntryId: entry.id, type: reason.type, note: reason.note);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
        content: Text(ok ? 'شكراً، تم إرسال بلاغك' : 'تعذّر إرسال البلاغ'),
        backgroundColor: ok ? AppColors.success : AppColors.error));
  }

  @override
  Widget build(BuildContext context) {
    // ✅ حالة خطأ صريحة بدل عرض منتج وهمي (MockData.products.first سابقاً)
    // عند وصول وسيط غير صالح للشاشة — بنفس نمط OfficialPriceHistoryScreen.
    if (_product == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
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
                  Icon(Icons.error_outline, size: 40, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('تعذّر تحميل بيانات المنتج',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final product = _product!;
    final provider = context.watch<AppProvider>();
    final priceProvider = context.watch<PriceProvider>();

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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios,
                                      color: Colors.white, size: 18),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                IconButton(
                                    icon: Icon(
                                        provider.isDarkMode
                                            ? Icons.light_mode_outlined
                                            : Icons.dark_mode_outlined,
                                        color: Colors.white),
                                    onPressed: provider.toggleDarkMode),
                              ]),
                          const SizedBox(height: 8),
                          Text(product.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700)),
                          Text(product.category,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14)),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                                child: _PriceStat(
                                    label: 'السعر الرسمي',
                                    value:
                                        '${_f(product.officialPrice)}\nل.س/${product.unit}')),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _PriceStat(
                                    label: 'الوسيط',
                                    value:
                                        '${_f(product.avgPrice)}\nل.س/${product.unit}')),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _PriceStat(
                                    label: 'السعر الحقيقي',
                                    value:
                                        '${_f(product.realPrice)}\nل.س/${product.unit}',
                                    isHighlight: true)),
                          ]),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: product.isPriceUp
                                  ? AppColors.errorLight
                                  : AppColors.successLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                  product.isPriceUp
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: product.isPriceUp
                                      ? AppColors.error
                                      : AppColors.success,
                                  size: 18),
                              const SizedBox(width: 6),
                              Text(
                                  '${product.changePercent.toStringAsFixed(0)}%+ الفرق عن الرسمي',
                                  style: TextStyle(
                                      color: product.isPriceUp
                                          ? AppColors.error
                                          : AppColors.success,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ]),
                          ),
                        ]),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الأسعار المسجلة',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryOf(context))),
                        Text('${product.pricesCount} سعر',
                            style: TextStyle(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 13)),
                      ]),
                  const SizedBox(height: 12),
                  if (priceProvider.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  // ✅ جديد — حالة خطأ صريحة بدل شاشة فارغة بلا تفسير عند
                  // فشل التحميل (سواء من الـ backend أو خطأ غير متوقع)
                  else if (priceProvider.state == LoadingState.error)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.error_outline,
                                size: 32, color: AppColors.error),
                            const SizedBox(height: 8),
                            Text(
                                priceProvider.errorMessage ??
                                    'تعذّر تحميل الأسعار',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppColors.textSecondaryOf(context))),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => context
                                  .read<PriceProvider>()
                                  .loadProductPrices(product.id),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (priceProvider.entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                          child: Text('لا توجد أسعار مسجّلة بعد',
                              style: TextStyle(
                                  color: AppColors.textSecondaryOf(context)))),
                    )
                  else
                    ..._safeBuildEntries(context, priceProvider.entries),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                        context, AppRoutes.addPrice,
                        arguments: product),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('إضافة سعر لهذا المنتج'),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _f(double v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(0)},${(v % 1000).toInt().toString().padLeft(3, '0')}'
      : v.toStringAsFixed(0);

  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — شبكة أمان: بناء بطاقات الأسعار داخل try/catch صريح. سابقاً لو
  // حدث أي خطأ غير متوقع أثناء بناء إحدى البطاقات (بيانات ناقصة من الخادم
  // الحقيقي مستقبلاً، مثلاً)، كان بإمكان القسم كاملاً أن يختفي بصمت دون أي
  // رسالة — بالضبط الشكوى المُبلَّغ عنها ("الأسعار المسجلة لا تظهر"). الآن
  // أي خطأ من هذا النوع يُستبدَل برسالة واضحة وزر "إعادة المحاولة" بدل شاشة
  // فارغة غامضة. كل بطاقة تحمل أيضاً Key ثابتاً (entry.id) لتفادي أي تضارب
  // في إعادة بناء القائمة عند تحديث الأصوات.
  // ══════════════════════════════════════════════════════════════════════
  List<Widget> _safeBuildEntries(BuildContext context, List<PriceEntry> list) {
    try {
      return list
          .map((e) => _PriceEntryCard(
                key: ValueKey('price_entry_${e.id}'),
                entry: e,
                onThumbUp: () =>
                    context.read<PriceProvider>().vote(e.id, isUp: true),
                onThumbDown: () =>
                    context.read<PriceProvider>().vote(e.id, isUp: false),
                onReport: () => _reportEntry(e),
              ))
          .toList();
    } catch (err) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 32, color: AppColors.error),
                const SizedBox(height: 8),
                Text('تعذّر عرض الأسعار المسجّلة',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppColors.textSecondaryOf(context))),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context
                      .read<PriceProvider>()
                      .loadProductPrices(_product!.id),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ];
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// نافذة "الإبلاغ عن هذا السعر" — تصميم احترافي جديد
// ✅ استُبدلت SimpleDialog البسيطة (قائمة نصية بلا أي شكل) بنافذة مصممة
// بعناية: أيقونة رأسية، بطاقات أسباب قابلة للاختيار (بدل نص عادي)، وحقل
// كتابة يظهر بانتقال متحرك (AnimatedSwitcher) فور اختيار "أخرى" ويصبح
// إجبارياً — لا يمكن إرسال البلاغ دون تعبئته في هذه الحالة تحديداً، مع
// رسالة خطأ واضحة تحت الحقل بدل رفض صامت. زرا "إلغاء"/"إرسال البلاغ"
// بعرض متساوٍ أسفل النافذة، وزر الإرسال مُعطَّل حتى يُختار سبب واحد على
// الأقل.
// ══════════════════════════════════════════════════════════════════════════

/// ✅ جديد — نتيجة النافذة: نوع البلاغ + نص توضيحي اختياري (إجباري فقط
/// عند type == ReportType.wrongInfo، مطابقةً لقيد الـ CHECK الفعلي في
/// قاعدة البيانات الذي يسمح بـ description حصراً مع هذا النوع).
class _ReportReason {
  final String type;
  final String? note;
  const _ReportReason(this.type, this.note);
}

class _ReportOptionData {
  final String value;
  final String label;
  final IconData icon;
  const _ReportOptionData(this.value, this.label, this.icon);
}

// ══════════════════════════════════════════════════════════════════════════
// ✅ إصلاح جوهري — القيم الثلاث الحصرية الفعلية لعمود Report.type بقاعدة
// البيانات (راجع ReportType في models.dart وWaffir_Database.txt)، بدل 4
// مفاتيح إنجليزية داخلية سابقاً لم تكن تطابق قيد الـ CHECK في القاعدة
// الحقيقية إطلاقاً (أي بلاغ قديم كان سيُرفَض فوراً من الخادم الحقيقي).
// ══════════════════════════════════════════════════════════════════════════
const List<_ReportOptionData> _reportOptions = [
  _ReportOptionData(
      ReportType.overpriced, 'سعر مبالغ فيه', Icons.warning_amber_outlined),
  _ReportOptionData(
      ReportType.wrongPrice, 'سعر غير صحيح', Icons.price_change_outlined),
  _ReportOptionData(
      ReportType.wrongInfo, 'معلومات غير صحيحة', Icons.info_outline),
];

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _selectedType;
  final _noteCtrl = TextEditingController();
  String? _noteError;

  // ✅ محدَّث — "أخرى" لم تعد موجودة كخيار (غير مسموحة في قيد الـ CHECK)؛
  // الحقل النصي الآن يظهر ويصبح إجبارياً حصراً مع 'معلومات غير صحيحة'
  // لأنه النوع الوحيد المسموح له بحمل description في القاعدة الفعلية.
  bool get _isOther => _selectedType == ReportType.wrongInfo;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _selectType(String value) {
    setState(() {
      _selectedType = value;
      // ✅ إخفاء رسالة الخطأ فور تغيير الاختيار (سواء إلى "أخرى" أو خارجها)
      _noteError = null;
    });
  }

  void _submit() {
    if (_selectedType == null) return;
    if (_isOther && _noteCtrl.text.trim().isEmpty) {
      setState(() => _noteError = 'يرجى كتابة توضيح لسبب البلاغ');
      return;
    }
    Navigator.pop(
      context,
      _ReportReason(
        _selectedType!,
        _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        // ══════════════════════════════════════════════════════════════
        // ✅ إصلاح "BOTTOM OVERFLOWED" — كان محتوى النافذة (Column بحجمه
        // الطبيعي الكامل) يفيض عن الشاشة فور ظهور لوحة المفاتيح لحقل
        // الملاحظة (خاصة عند اختيار "أخرى" مع autofocus)، لأن Dialog
        // العادي لا "يقصّ" محتواه تلقائياً بل يتركه يفيض بصمت مع الشريط
        // الأصفر/الأسود المميز لهذا الخطأ في Flutter. الحل: تحديد سقف
        // ارتفاع صريح للنافذة (85% من ارتفاع الشاشة، مطروحاً منه جزء من
        // ارتفاع لوحة المفاتيح الحالي إن وُجدت) عبر ConstrainedBox، مع
        // تغليف المحتوى بـ SingleChildScrollView ليصبح قابلاً للتمرير بدل
        // الفيض عندما لا يتسع المحتوى كاملاً.
        // ══════════════════════════════════════════════════════════════
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85 -
                MediaQuery.of(context).viewInsets.bottom * 0.3,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flag_rounded,
                          color: AppColors.error, size: 26),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('الإبلاغ عن هذا السعر',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryOf(context))),
                  const SizedBox(height: 6),
                  Text('اختر السبب الأنسب لمساعدتنا على تحسين دقة الأسعار',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: AppColors.textSecondaryOf(context))),
                  const SizedBox(height: 20),
                  ..._reportOptions.map((o) => _ReasonTile(
                        icon: o.icon,
                        label: o.label,
                        selected: _selectedType == o.value,
                        onTap: () => _selectType(o.value),
                      )),
                  // ══════════════════════════════════════════════════════════
                  // ✅ حقل الكتابة — يظهر وينهار بانتقال متحرك سلس بدل الظهور
                  // المفاجئ، ويكون إجبارياً حصراً عند اختيار "أخرى".
                  // ══════════════════════════════════════════════════════════
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: !_isOther
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _noteCtrl,
                                  maxLines: 3,
                                  minLines: 2,
                                  maxLength: 300,
                                  textDirection: TextDirection.rtl,
                                  autofocus: true,
                                  onChanged: (v) {
                                    if (_noteError != null &&
                                        v.trim().isNotEmpty) {
                                      setState(() => _noteError = null);
                                    }
                                  },
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      color: AppColors.textPrimaryOf(context)),
                                  decoration: InputDecoration(
                                    hintText: 'اكتب توضيحاً لسبب البلاغ...',
                                    hintStyle: TextStyle(
                                        color: AppColors.textHintOf(context),
                                        fontSize: 13),
                                    errorText: _noteError,
                                    counterText: '',
                                    filled: true,
                                    fillColor: AppColors.isDark(context)
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : AppColors.primary
                                            .withValues(alpha: 0.03),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color:
                                                AppColors.borderOf(context))),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: _noteError != null
                                                ? AppColors.error
                                                : AppColors.borderOf(context))),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: _noteError != null
                                                ? AppColors.error
                                                : AppColors.primary,
                                            width: 2)),
                                    errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: AppColors.error)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedType == null ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            backgroundColor: AppColors.error,
                            disabledBackgroundColor:
                                AppColors.error.withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('إرسال البلاغ',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ✅ جديد — بطاقة سبب بلاغ قابلة للاختيار (بدل SimpleDialogOption النصية
/// السابقة): أيقونة + تسمية + مؤشر اختيار دائري، وتُبرَز حدودها وخلفيتها
/// عند التحديد.
class _ReasonTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.isDark(context)
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.015),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderOf(context),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: selected
                    ? AppColors.primary
                    : AppColors.textHintOf(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimaryOf(context))),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color:
                  selected ? AppColors.primary : AppColors.textHintOf(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceStat extends StatelessWidget {
  final String label, value;
  final bool isHighlight;
  const _PriceStat(
      {required this.label, required this.value, this.isHighlight = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isHighlight ? 0.3 : 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ✅ إصلاح Crash جوهري — "RenderFlex children have non-zero flex but incoming
// width constraints are unbounded" (السبب المباشر لتوقف تحميل "الأسعار
// المسجلة" على دوّامة تحميل بلا نهاية):
//
// الصف السفلي (تصويت + "منذ ... — بواسطة ...") كان يحوي Row ثانياً كطفل
// عادي (بلا Expanded/Flexible) داخل Row أب بترتيب spaceBetween. في Flutter،
// أي طفل غير مرن (non-flex) داخل Row يحصل تلقائياً على قيود عرض غير محدودة
// (unbounded) على المحور الرئيسي — وبما أن هذا الـ Row الداخلي يحوي بدوره
// عنصر Flexible (نص "بواسطة ...")، فإن التخطيط ينهار فور محاولة حساب
// المساحة المتبقية له، فتتوقف الشاشة عند مؤشر التحميل بصمت.
//
// الإصلاح: تغليف الـ Row الثاني بـ Expanded ليحصل على عرض محدود فعلي من
// الأب، مع الإبقاء على Flexible داخله لقصّ اسم المستخدم الطويل بدل تجاوز
// الحدود. كما أُضيف mainAxisSize.min لصفوف التصويت (لا حاجة فعلية لها
// بالتمدد) كإجراء وقائي إضافي.
// ══════════════════════════════════════════════════════════════════════════════
class _PriceEntryCard extends StatelessWidget {
  final PriceEntry entry;
  final VoidCallback onThumbUp;
  final VoidCallback onThumbDown;
  final VoidCallback onReport;
  const _PriceEntryCard({
    super.key,
    required this.entry,
    required this.onThumbUp,
    required this.onThumbDown,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimaryOf(context))),
                    Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                      Flexible(
                        child: Text(entry.storeArea,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.primary),
                    ]),
                  ]),
            ),
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.store_outlined,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            // ✅ زر البلاغ أصبح فعلياً — يفتح اختيار نوع البلاغ ويرسله عبر
            // ReportProvider بدل أن يكون أيقونة ثابتة بلا استجابة.
            GestureDetector(
              onTap: onReport,
              behavior: HitTestBehavior.opaque,
              child: Icon(Icons.flag_outlined,
                  size: 18, color: AppColors.textHintOf(context)),
            ),
          ]),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${entry.totalRatings} تقييم',
                style: TextStyle(
                    color: AppColors.textSecondaryOf(context), fontSize: 11)),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: AppColors.borderOf(context)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_f(entry.price)} ل.س',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text('${entry.quantity.toStringAsFixed(0)} ${entry.unit}',
                        style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 12)),
                    if (entry.brand.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(entry.brand,
                            style: const TextStyle(
                                color: AppColors.primary, fontSize: 11)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ✅ التصويت أصبح فعلياً (كان يعرض الأرقام فقط بلا onTap) — يستدعي
          // PriceProvider.vote() بتحديث متفائل فوري.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ✅ mainAxisSize.min: هذا الصف لا يحتاج للتمدد، ويبقى بحجمه
              // الطبيعي بدل أخذ مساحة أكبر من اللازم كطفل غير مرن في Row أب.
              Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: onThumbUp,
                  behavior: HitTestBehavior.opaque,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.thumb_up_outlined,
                        size: 18, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text('${entry.thumbsUp}',
                        style: const TextStyle(
                            color: AppColors.success, fontSize: 13)),
                  ]),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: onThumbDown,
                  behavior: HitTestBehavior.opaque,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.thumb_down_outlined,
                        size: 18, color: AppColors.error),
                    const SizedBox(width: 4),
                    Text('${entry.thumbsDown}',
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13)),
                  ]),
                ),
              ]),
              // ✅ الإصلاح الجوهري: تغليف هذا الصف بـ Expanded ليحصل على عرض
              // محدود فعلي (bounded) من الـ Row الأب بدل القيد غير المحدود
              // الذي كان يتسبب بانهيار التخطيط بصمت عند وجود Flexible بداخله.
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(_timeAgo(entry.submittedAt),
                        style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 11)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('بواسطة ${entry.submittedBy}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]),
      );

  String _f(double v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(0)},${(v % 1000).toInt().toString().padLeft(3, '0')}'
      : v.toStringAsFixed(0);

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'أمس';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// USER SETTINGS SCREEN
// ✅ محدَّث — "تغيير الموقع" أصبح يفتح منتقي الكتل/الأحياء الرسمي الموحّد
// (showLocationPickerSheet من common_widgets.dart) بدل قائمة محلية مسطحة من
// 10 أسماء مناطق وهمية لم تكن مطابقة للتقسيم الإداري الرسمي. كما أصبح الصف
// يعرض الموقع الحالي (المنطقة والكتلة) كنص ثانوي بدل الاكتفاء بالأيقونة.
//
// ✅ إصلاح RTL (جديد): في كل صفوف هذه الشاشة كان ترتيب الأطفال معكوساً —
// عنصر القيمة/التحكم (نص ثانوي أو Switch) يظهر أولاً في أقصى اليمين،
// والتسمية+الأيقونة تظهر في أقصى اليسار. الآن كل صف يبدأ بالتسمية+الأيقونة
// (يمين) وينتهي بالقيمة/التحكم (يسار)، بنفس منطق رأس home_screen.dart.
// ══════════════════════════════════════════════════════════════════════════════
class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});
  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
        () => _notifications = prefs.getBool('user_notifications') ?? true);
  }

  Future<void> _setNotifications(bool v) async {
    setState(() => _notifications = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('user_notifications', v);
  }

  void _showLanguageInfo() {
    showComingSoonDialog(
      context,
      title: 'اللغة',
      message: 'العربية هي اللغة الوحيدة المتوفرة حالياً. دعم لغات إضافية '
          'مخطط له في إصدار قادم من التطبيق.',
      icon: Icons.language,
    );
  }

  /// ✅ محدَّث — يترجم الحي المختار إلى location_id حقيقي ويحفظه، ثم يزامنه
  /// مع موقع الحساب على الخادم (PUT /auth/profile) ويعيد تحميل المنتجات.
  void _showLocationPicker(AppProvider provider) {
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
        if (!mounted) return;
        await context.read<ProductProvider>().loadProducts(
              locationId: provider.selectedLocationId,
              refresh: true,
            );
      },
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
    // ✅ المستخدم مسجّل دخوله هنا، فنستخدم دورة تغيير كلمة المرور المخصّصة
    // (POST /auth/change-password/request-otp) بدل دورة استعادة الحساب.
    final ok = await provider.requestChangePasswordOtp();
    if (!mounted) return;
    if (ok) {
      await Navigator.pushNamed(context, AppRoutes.resetPassword,
          arguments: {'phone': provider.userPhone, 'fromSettings': true});
    } else {
      messenger.showSnackBar(SnackBar(
          content: Text(
              provider.errorMessage ?? 'تعذّر إرسال رمز التحقق، حاول مجدداً'),
          backgroundColor: AppColors.error));
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — "المساعدة والدعم"، أحد عناصر شاشة الإعدادات في مخطط حالات
  // الاستخدام والتي لم تكن موجودة سابقاً. نافذة معلوماتية بسيطة بنفس نمط
  // بقية الحوارات في التطبيق (showComingSoonDialog/showConfirmDialog)، تعرض
  // قناة تواصل واحدة واضحة بدل ترك الزر بلا استجابة.
  // ══════════════════════════════════════════════════════════════════════
  void _showHelpSupport() {
    showDialog(
      context: context,
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.support_agent_outlined,
                    color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 16),
              Text('المساعدة والدعم',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(ctx)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                  'لأي استفسار أو مشكلة تواجهك أثناء استخدام التطبيق، تواصل '
                  'معنا عبر البريد التالي وسيقوم فريق الدعم بالرد عليك في '
                  'أقرب وقت ممكن.',
                  style: TextStyle(
                      color: AppColors.textSecondaryOf(ctx),
                      fontSize: 13.5,
                      height: 1.6),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.mail_outline,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  const Text('support@waffir.sy',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 20),
              // ✅ إصلاح: كانت SizedBox تفرض ارتفاعاً ثابتاً (46) أقل مما
              // يحتاجه الزر فعلياً (حشوة الثيم الرأسية 16 من كل جهة + ارتفاع
              // سطر النص)، فيُقصّ النص عمودياً ويظهر مشوَّهاً بدل "حسناً"
              // كاملة. الحل: عدم فرض ارتفاع ثابت — نترك الزر يأخذ ارتفاعه
              // الطبيعي عبر minimumSize فقط، بعرض كامل.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: const Text('حسناً',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — "عن التطبيق"، عنصر آخر من مخطط حالات الاستخدام كان مفقوداً.
  // نافذة تعريفية بسيطة بشعار التطبيق ونبذة قصيرة عن هدفه.
  // ══════════════════════════════════════════════════════════════════════
  void _showAboutApp() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ استبدال إيموجي "💰" بالشعار الفعلي للتطبيق (icon.png)
              // بدل نص إيموجي عام لا يمثّل هوية التطبيق البصرية الحقيقية.
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderOf(ctx)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('وفّر',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryOf(ctx))),
              const SizedBox(height: 4),
              Text('الإصدار 1.0.0',
                  style: TextStyle(
                      color: AppColors.textSecondaryOf(ctx), fontSize: 12.5)),
              const SizedBox(height: 14),
              Text(
                  'تطبيق "وفّر" يساعدك على معرفة الأسعار الحقيقية للمنتجات '
                  'في المتاجر ومقارنتها بالأسعار الرسمية، لزيادة الشفافية '
                  'ومساعدتك على اتخاذ قرارات شراء أفضل.',
                  style: TextStyle(
                      color: AppColors.textSecondaryOf(ctx),
                      fontSize: 13.5,
                      height: 1.6),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              // ✅ نفس إصلاح ارتفاع الزر أعلاه — بلا ارتفاع ثابت مفروض.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: const Text('حسناً',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDarkMode;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? Colors.white60 : AppColors.textSecondary;
    final sectionColor = isDark ? Colors.white38 : AppColors.textSecondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعدادات'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        // ══════════════════════════════════════════════════════════════
        // ✅ إعادة ترتيب شاملة لتطابق تماماً مخطط حالات الاستخدام (فرع
        // "الإعدادات" المنبثق من "الحساب والإعدادات"): تغيير الثيم، تغيير
        // اللغة، الإشعارات، تغيير كلمة المرور، تغيير الموقع، المساعدة
        // والدعم، عن التطبيق، سياسة الخصوصية، الشروط والأحكام — بنفس هذا
        // الترتيب تماماً. "تعديل الملف الشخصي" أُزيل من هنا لأنه في المخطط
        // include مباشر من "الملف الشخصي" وليس من "الإعدادات" (متاح فعلاً
        // من شاشة الملف الشخصي مباشرة). كما أُضيفت العناصر الثلاثة التي لم
        // تكن موجودة إطلاقاً: تغيير الثيم، المساعدة والدعم، عن التطبيق،
        // بالإضافة إلى رابط الشروط والأحكام المفقود سابقاً من هذه الشاشة.
        // ══════════════════════════════════════════════════════════════
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader('المظهر والتفضيلات', color: sectionColor),
            // ✅ جديد — تغيير الثيم (فاتح/داكن) كأول عنصر في المخطط
            _SettingCard(
              isDark: isDark,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Text('تغيير الثيم',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, color: textPrimary)),
                      const SizedBox(width: 8),
                      Icon(
                          isDark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          size: 18,
                          color: AppColors.primary),
                    ]),
                    Switch(
                        value: isDark,
                        onChanged: (_) => provider.toggleDarkMode(),
                        activeThumbColor: AppColors.primary),
                  ]),
            ),
            _SettingCard(
              isDark: isDark,
              onTap: _showLanguageInfo,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Text('اللغة',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, color: textPrimary)),
                      const SizedBox(width: 8),
                      const Text('🌍', style: TextStyle(fontSize: 18)),
                    ]),
                    Text('العربية',
                        style: TextStyle(color: textSecondary, fontSize: 14)),
                  ]),
            ),
            _SettingCard(
              isDark: isDark,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Text('الإشعارات',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, color: textPrimary)),
                      const SizedBox(width: 8),
                      const Text('🔔', style: TextStyle(fontSize: 18)),
                    ]),
                    Switch(
                        value: _notifications,
                        onChanged: _setNotifications,
                        activeThumbColor: AppColors.primary),
                  ]),
            ),

            _SectionHeader('الأمان والموقع', color: sectionColor),
            _SettingCard(
              isDark: isDark,
              onTap: () => _startChangePassword(provider),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Text('تغيير كلمة المرور',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, color: textPrimary)),
                      const SizedBox(width: 8),
                      const Text('🔐', style: TextStyle(fontSize: 18)),
                    ]),
                    Icon(Icons.arrow_back_ios,
                        size: 14,
                        color: isDark ? Colors.white30 : AppColors.textHint),
                  ]),
            ),
            _SettingCard(
              isDark: isDark,
              onTap: () => _showLocationPicker(provider),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Text('تغيير الموقع',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, color: textPrimary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on_outlined,
                          size: 18, color: AppColors.primary),
                    ]),
                    Text(provider.userLocation,
                        style: TextStyle(color: textSecondary, fontSize: 14)),
                  ]),
            ),

            _SectionHeader('الدعم والتطبيق', color: sectionColor),
            // ✅ جديد — المساعدة والدعم
            _SettingCard(
              isDark: isDark,
              onTap: _showHelpSupport,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Text('المساعدة والدعم',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, color: textPrimary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.support_agent_outlined,
                          size: 18, color: AppColors.primary),
                    ]),
                    Icon(Icons.arrow_back_ios,
                        size: 14,
                        color: isDark ? Colors.white30 : AppColors.textHint),
                  ]),
            ),
            // ✅ جديد — عن التطبيق
            _SettingCard(
              isDark: isDark,
              onTap: _showAboutApp,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Text('عن التطبيق',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, color: textPrimary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.info_outline,
                          size: 18, color: AppColors.primary),
                    ]),
                    Icon(Icons.arrow_back_ios,
                        size: 14,
                        color: isDark ? Colors.white30 : AppColors.textHint),
                  ]),
            ),
            _SettingCard(
              isDark: isDark,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.privacyPolicy),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Text('سياسة الخصوصية',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, color: textPrimary)),
                      const SizedBox(width: 8),
                      const Text('🔒', style: TextStyle(fontSize: 18)),
                    ]),
                    Icon(Icons.arrow_back_ios,
                        size: 14,
                        color: isDark ? Colors.white30 : AppColors.textHint),
                  ]),
            ),
            // ✅ جديد — رابط الشروط والأحكام لم يكن موجوداً في هذه الشاشة
            // إطلاقاً رغم وجود المسار (AppRoutes.termsOfService) جاهزاً.
            _SettingCard(
              isDark: isDark,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.termsOfService),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Text('الشروط والأحكام',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, color: textPrimary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.description_outlined,
                          size: 18, color: AppColors.primary),
                    ]),
                    Icon(Icons.arrow_back_ios,
                        size: 14,
                        color: isDark ? Colors.white30 : AppColors.textHint),
                  ]),
            ),

            const SizedBox(height: 16),
            Center(
                child: Text('إصدار التطبيق\n1.0.0',
                    style: TextStyle(
                        color: isDark ? Colors.white38 : AppColors.textHint,
                        fontSize: 12),
                    textAlign: TextAlign.center)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final Color? color;
  const _SectionHeader(this.text, {this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(text,
            style: TextStyle(
                color: color ?? AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final VoidCallback? onTap;
  const _SettingCard({required this.child, this.isDark = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.border)),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADD PRICE SCREEN
// ✅ إصلاح جوهري: كانت الحقول تحمل الأسماء فقط (بلا IDs) وزر الإرسال كان
// Future.delayed وهمي حتى في وضع الإنتاج. الآن تُحمَّل قوائم المنتجات
// والمتاجر الحقيقية عبر ProductProvider/StoreProvider، ويحتفظ الاختيار
// بالـ id الفعلي، والإرسال يمرّ فعلياً عبر PriceProvider.submitPrice.
//
// ✅ إصلاح جوهري إضافي (بلا أي تغيير مرئي في شكل الشاشة): حقلا "الوحدة"
// و"العلامة التجارية" كانا يعتمدان على قائمة وحدات ثابتة (كغ/غرام/...)
// وMockData.brands على التوالي — نصوص لا معرّفات حقيقية، رغم أن مخطط
// قاعدة البيانات الفعلي يتطلب unit_id/brand_id (مفتاحان أجنبيان). الآن
// يُختاران من CatalogProvider.units/brands (مُحمَّلين من الخادم)، بنفس
// شكل وسلوك القائمتين المنسدلتين تماماً (_IdDropdown نفسها المستخدمة أصلاً
// لحقلَي المنتج والمحل)، مع الاحتفاظ بمعرّف حقيقي (id) بدل نص فقط.
// ══════════════════════════════════════════════════════════════════════════════
class AddPriceScreen extends StatefulWidget {
  const AddPriceScreen({super.key});
  @override
  State<AddPriceScreen> createState() => _AddPriceScreenState();
}

class _AddPriceScreenState extends State<AddPriceScreen> {
  // ✅ نستخدم معرّفاً فارغاً '' كقيمة اصطلاحية داخل قائمة العلامات التجارية
  // تعني "بدون علامة تجارية"، بدل الاعتماد على مطابقة نص اسم كما كان
  // سابقاً. هذا المعرّف لا يُرسَل للـ backend أبداً (راجع _submit أدناه:
  // يُترجَم إلى null قبل الإرسال).
  // Seed data reserves brand id 1 for the explicit no-brand option.
  static const String _noBrandOption = '1';

  // ✅ محدَّث — سلسلة اختيار من 3 مستويات: الكتلة الإدارية أولاً، ثم
  // المنطقة/الحي التابع لتلك الكتلة (عبر AleppoBlocks.areasOfBlock)، ثم
  // المحل أخيراً — تُفلتَر قائمة المحلات المعروضة تلقائياً لتشمل فقط
  // محلات المنطقة المختارة تحديداً (مطابقة مباشرة على حقل area الموجود
  // أصلاً في StoreModel — بلا حاجة لأي تعديل على الـ backend أو الـ model).
  String? _selectedBlock;
  String? _selectedArea;
  String? _selectedProductId;
  String? _selectedStoreId;
  final _priceCtrl = TextEditingController(text: '15000');
  final _qtyCtrl = TextEditingController(text: '1');
  // ✅ إصلاح جوهري: الوحدة والعلامة التجارية تُختاران الآن بمعرّف حقيقي
  // (unit_id/brand_id) من قوائم فعلية، لا نص ثابت كما كان.
  String? _unitId;
  String _brandId = _noBrandOption;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final productProvider = context.read<ProductProvider>();
      final storeProvider = context.read<StoreProvider>();
      final catalogProvider = context.read<CatalogProvider>();
      if (productProvider.products.isEmpty) productProvider.loadProducts();
      if (storeProvider.stores.isEmpty) storeProvider.loadStores();
      // ✅ جديد — تحميل الوحدات والعلامات التجارية الحقيقية من الخادم (أو
      // MockData في وضع العرض التجريبي) بدل الاعتماد على قوائم ثابتة.
      if (catalogProvider.units.isEmpty) {
        await catalogProvider.loadUnits();
      }
      if (catalogProvider.brands.isEmpty) {
        await catalogProvider.loadBrands();
      }
      if (!mounted) return;
      // ✅ تعيين أول وحدة كقيمة افتراضية (يحافظ على نفس تجربة الاستخدام
      // السابقة التي كانت تبدأ بقيمة مبدئية جاهزة بدل حقل فارغ).
      if (_unitId == null && catalogProvider.units.isNotEmpty) {
        setState(() => _unitId = catalogProvider.units.first.id);
      }
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is ProductModel) {
        setState(() => _selectedProductId = args.id);
      } else if (args is StoreModel) {
        // ✅ إصلاح جوهري: كان زر "إضافة سعر لهذا المتجر" (في شاشة تفاصيل
        // المتجر) يمرّر StoreModel كوسيط، لكن هذه الشاشة لم تكن تتعرّف
        // عليه إطلاقاً — فقط ProductModel كانت تُعامَل. النتيجة: المستخدم
        // يصل لشاشة "إضافة سعر" فارغة تماماً ويُضطر لاختيار الكتلة
        // والمنطقة والمحل يدوياً من جديد رغم أنه جاء أصلاً من صفحة ذلك
        // المتجر بالذات. الآن تُعبَّأ الثلاثة تلقائياً: الكتلة (مُشتقّة من
        // store.area عبر AleppoBlocks.blockOfArea)، والمنطقة (store.area
        // مباشرة)، والمحل نفسه (store.id).
        final block = AleppoBlocks.blockOfArea(args.area)?.name;
        setState(() {
          _selectedBlock = block;
          _selectedArea = args.area;
          _selectedStoreId = args.id;
        });
      }
    });
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  // ✅ محدَّث — الكتلة والمنطقة تُختاران معاً في نفس السطر عبر منتقي الموقع
  // الموحّد (showLocationPickerSheet، نفس المكوّن المستخدم في شريحة الموقع
  // بالصفحة الرئيسية وصف "تغيير الموقع" بالإعدادات) بدل قائمتين منسدلتين
  // منفصلتين. هذا يوحّد تجربة اختيار الموقع في كل شاشات التطبيق.
  void _pickLocation() {
    showLocationPickerSheet(
      context,
      currentBlock: _selectedBlock ?? '',
      currentArea: _selectedArea ?? '',
      onSelect: (block, area) => setState(() {
        _selectedBlock = block;
        _selectedArea = area;
        // ✅ إعادة ضبط المحل المختار تلقائياً، لمنع بقاء محل من منطقة
        // سابقة لا ينتمي إلى المنطقة المختارة حديثاً.
        _selectedStoreId = null;
      }),
    );
  }

  Future<void> _submit() async {
    if (_selectedBlock == null || _selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يرجى اختيار الكتلة الإدارية والمنطقة'),
          backgroundColor: AppColors.error));
      return;
    }
    if (_selectedProductId == null || _selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يرجى اختيار المنتج والمحل'),
          backgroundColor: AppColors.error));
      return;
    }
    // ✅ محدَّث — التحقق الآن من unitId (معرّف حقيقي) بدل نص وحدة ثابت.
    if (_unitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يرجى اختيار الوحدة'),
          backgroundColor: AppColors.error));
      return;
    }
    final price = double.tryParse(_priceCtrl.text.trim());
    final qty = double.tryParse(_qtyCtrl.text.trim());
    if (price == null || price <= 0 || qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يرجى إدخال سعر وكمية صحيحين'),
          backgroundColor: AppColors.error));
      return;
    }
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    final ok = await context.read<PriceProvider>().submitPrice(
          productId: _selectedProductId!,
          storeId: _selectedStoreId!,
          price: price,
          unitId: _unitId!,
          quantity: qty,
          brandId: _brandId,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('تم إرسال السعر بنجاح!'),
        backgroundColor: AppColors.success,
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(
            context.read<PriceProvider>().errorMessage ?? 'تعذّر إرسال السعر'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;
    final allStores = context.watch<StoreProvider>().stores;
    // ✅ جديد — الوحدات والعلامات التجارية الحقيقية من الخادم (بدل قائمة
    // وحدات ثابتة وMockData.brands)، لضمان أن ما يظهر للمستخدم مطابق تماماً
    // لما يملكه الخادم فعلياً من unit_id/brand_id صالحة للإرسال.
    final units = context.watch<CatalogProvider>().units;
    final brands = context.watch<CatalogProvider>().brands;
    // ✅ محدَّث — محلات المنطقة المختارة تحديداً فقط (وليس الكتلة كاملة) —
    // فارغة حتى تُختار منطقة. هذا هو الفلتر الفعلي الذي يحدد قائمة المحل.
    final storesInArea = _selectedArea == null
        ? const <StoreModel>[]
        : allStores.where((s) => s.area == _selectedArea).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إضافة سعر'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('ساعد الآخرين بمعرفة الأسعار الحقيقية',
                style: TextStyle(
                    color: AppColors.textSecondaryOf(context), fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _lbl(context, 'المنتج'),
            const SizedBox(height: 8),
            _IdDropdown(
              hint: 'اختر المنتج',
              value: _selectedProductId,
              items: {for (final p in products) p.id: p.name},
              onChanged: (v) => setState(() => _selectedProductId = v),
            ),
            const SizedBox(height: 16),
            // ══════════════════════════════════════════════════════════
            // ✅ محدَّث — الكتلة والمنطقة أصبحتا حقلاً واحداً بنفس السطر،
            // يُفتح عند النقر منتقي الموقع الموحّد (نفس المكوّن المستخدم في
            // شريحة الموقع بالصفحة الرئيسية وصف "تغيير الموقع" بالإعدادات)
            // بدل قائمتين منسدلتين منفصلتين متتاليتين. يحدد هذا الحقل
            // قائمة المحلات المتاحة أدناه.
            // ══════════════════════════════════════════════════════════
            _lbl(context, 'الكتلة والمنطقة'),
            const SizedBox(height: 8),
            _LocationPickerField(
              block: _selectedBlock,
              area: _selectedArea,
              onTap: _pickLocation,
            ),
            const SizedBox(height: 16),
            // ══════════════════════════════════════════════════════════
            // ✅ "المحل": يعتمد على المنطقة المختارة تحديداً، فتظهر فقط
            // محلات نفس الحي بدل كل محلات الكتلة الإدارية.
            // ══════════════════════════════════════════════════════════
            _lbl(context, 'المحل'),
            const SizedBox(height: 8),
            _selectedArea == null
                ? _LockedField(text: 'اختر الكتلة والمنطقة أولاً')
                : storesInArea.isEmpty
                    ? _LockedField(
                        text: 'لا توجد محلات مسجّلة في هذه المنطقة',
                        icon: Icons.store_mall_directory_outlined)
                    : _IdDropdown(
                        hint: 'اختر المحل',
                        value: _selectedStoreId,
                        items: {for (final s in storesInArea) s.id: s.name},
                        onChanged: (v) => setState(() => _selectedStoreId = v),
                      ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    _lbl(context, 'الكمية'),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '1')),
                  ])),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    _lbl(context, 'الوحدة'),
                    const SizedBox(height: 8),
                    // ✅ محدَّث — قائمة الوحدات الحقيقية (id → اسم) بدل نصوص
                    // ثابتة، بنفس شكل وسلوك _IdDropdown المستخدم أصلاً لحقلَي
                    // المنتج والمحل أعلاه.
                    _IdDropdown(
                        hint: 'الوحدة',
                        value: _unitId,
                        items: {for (final u in units) u.id: u.name},
                        onChanged: (v) => setState(() => _unitId = v)),
                  ])),
            ]),
            const SizedBox(height: 16),
            _lbl(context, 'السعر (ل.س)'),
            const SizedBox(height: 8),
            TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '15000')),
            const SizedBox(height: 16),
            _lbl(context, 'العلامة التجارية'),
            const SizedBox(height: 8),
            // ✅ محدَّث — قائمة العلامات التجارية الحقيقية (id → اسم) بدل
            // MockData.brands، مع إبقاء خيار "بدون علامة تجارية" في أعلى
            // القائمة بنفس مكانه وشكله تماماً.
            _IdDropdown(
                hint: 'اختر العلامة التجارية',
                value: _brandId,
                items: {
                  _noBrandOption: 'بدون علامة تجارية',
                  for (final b in brands) b.id: b.name,
                },
                onChanged: (v) =>
                    setState(() => _brandId = v ?? _noBrandOption)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                    child: Text('تأكد من دقة المعلومات قبل الإرسال',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.primary))),
              ]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('إرسال السعر'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _lbl(BuildContext context, String t) => Text(t,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimaryOf(context)));
}

/// ✅ جديد — عنصر عرض موحّد لحقل "مُقفَل" مؤقتاً ريثما يختار المستخدم
/// المستوى الأعلى في سلسلة الاختيار (كتلة ← منطقة ← محل)، بنفس شكل حقول
/// الإدخال العادية حتى لا يبدو التخطيط متقطعاً أثناء التنقل بين الحقول.
/// ✅ جديد — حقل موحّد لاختيار "الكتلة الإدارية والمنطقة" معاً بنفس السطر،
/// بنفس هوية منتقي الموقع المستخدم في شريحة الموقع بالصفحة الرئيسية وصف
/// "تغيير الموقع" بالإعدادات (showLocationPickerSheet). عند النقر تُفتح
/// نافذة سفلية تعرض الكتل الخمس قابلة للطي، كل كتلة تُظهر أحياءها عند
/// فتحها، ويُختار الحي مباشرة من داخلها — فيُحدَّد الاثنان معاً بنقرة واحدة
/// بدل قائمتين منسدلتين منفصلتين متتاليتين.
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

class _LockedField extends StatelessWidget {
  final String text;
  final IconData icon;
  const _LockedField({required this.text, this.icon = Icons.lock_outline});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.textHintOf(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: AppColors.textHintOf(context), fontSize: 14)),
          ),
        ]),
      );
}

/// ✅ جديد — يحتفظ بمفتاح (id) مستقل عن التسمية
/// المعروضة، حتى يمكن إرسال product_id/store_id/unit_id/brand_id الحقيقيين
/// إلى الـ backend بدل الاسم النصي فقط.
class _IdDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final Map<String, String> items; // id -> label
  final ValueChanged<String?> onChanged;

  const _IdDropdown(
      {required this.hint,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: items.containsKey(value) ? value : null,
        hint: Text(hint,
            style:
                TextStyle(color: AppColors.textHintOf(context), fontSize: 14)),
        isExpanded: true,
        style: TextStyle(color: AppColors.textPrimaryOf(context), fontSize: 14),
        dropdownColor: AppColors.surfaceOf(context),
        decoration: InputDecoration(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderOf(context))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderOf(context))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          filled: true,
          fillColor: AppColors.surfaceOf(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: items.entries
            .map((e) => DropdownMenuItem(
                value: e.key, child: Text(e.value, textAlign: TextAlign.right)))
            .toList(),
        onChanged: onChanged,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// OFFICIAL PRICES SCREEN
// ✅ من CatalogProvider.officialPrices بدل MockData مباشرة.
// ✅ إصلاح RTL: اسم المادة (الكلام) أصبح أول عنصر في كل بطاقة → يظهر في
// أقصى اليمين، والسعر+التاريخ (التفاصيل) أصبحا في عمود ثانٍ يظهر في أقصى
// اليسار، مع سهم صغير يوضّح أن البطاقة قابلة للنقر — بدل الترتيب المعكوس
// سابقاً (التفاصيل يمين، الاسم يسار).
// ✅ جديد — كل بطاقة أصبحت قابلة للنقر وتفتح OfficialPriceHistoryScreen
// (سجل تغييرات هذه المادة عبر الزمن) عبر AppRoutes.officialPriceHistory.
// ══════════════════════════════════════════════════════════════════════════════
class OfficialPricesScreen extends StatefulWidget {
  const OfficialPricesScreen({super.key});

  @override
  State<OfficialPricesScreen> createState() => _OfficialPricesScreenState();
}

class _OfficialPricesScreenState extends State<OfficialPricesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().loadOfficialPrices();
    });
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtPrice(double v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(0)},${(v % 1000).toInt().toString().padLeft(3, '0')}'
      : v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final catalog = context.watch<CatalogProvider>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios,
                                      color: Colors.white, size: 18),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                IconButton(
                                  icon: Icon(
                                      provider.isDarkMode
                                          ? Icons.light_mode_outlined
                                          : Icons.dark_mode_outlined,
                                      color: Colors.white),
                                  onPressed: provider.toggleDarkMode,
                                ),
                              ]),
                          const SizedBox(height: 8),
                          const Text('الأسعار الرسمية',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('أسعار وزارة التموين',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13)),
                        ]),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.description_outlined,
                          size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              'هذه الأسعار صادرة عن وزارة التموين والتجارة الداخلية',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.primary))),
                    ]),
                  ),
                  if (catalog.isLoading && catalog.officialPrices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ...catalog.officialPrices.map((op) => GestureDetector(
                          onTap: () => Navigator.pushNamed(
                              context, AppRoutes.officialPriceHistory,
                              arguments: op),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: AppColors.surfaceOf(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppColors.borderOf(context))),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // ✅ الكلام (اسم المادة + الكمية) أولاً →
                                // يظهر في أقصى اليمين، ويأخذ المساحة الأكبر
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(op.productName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: AppColors.textPrimaryOf(
                                                  context))),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.scale_outlined,
                                              size: 13,
                                              color: AppColors.textHintOf(
                                                  context)),
                                          const SizedBox(width: 4),
                                          Text(
                                              '${op.quantity.toStringAsFixed(0)} ${op.unit}',
                                              style: TextStyle(
                                                  color:
                                                      AppColors.textSecondaryOf(
                                                          context),
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // ✅ التفاصيل (السعر والتاريخ) أخيراً →
                                // تظهر في أقصى اليسار
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                        '${_fmtPrice(op.price)} ل.س/${op.unit}',
                                        style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary)),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_fmt(op.updatedAt),
                                            style: TextStyle(
                                                fontSize: 10.5,
                                                color:
                                                    AppColors.textSecondaryOf(
                                                        context))),
                                        const SizedBox(width: 4),
                                        Icon(Icons.calendar_today_outlined,
                                            size: 11,
                                            color:
                                                AppColors.textHintOf(context)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_back_ios,
                                    size: 13,
                                    color: AppColors.textHintOf(context)),
                              ],
                            ),
                          ),
                        )),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
