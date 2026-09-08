import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_provider.dart';
import '../../../core/constants/aleppo_blocks.dart';
import '../../../core/constants/app_routes.dart';
import '../../../models/models.dart';

// ══════════════════════════════════════════════════════════════════════════
// STORES SCREEN
// ✅ إصلاح جوهري — كانت هذه الشاشة الوحيدة في كامل التطبيق التي تقرأ
// MockData.stores مباشرة (import '../../../core/utils/mock_data.dart')
// بصرف النظر تماماً عن قيمة AppConfig.useMockData، رغم وجود StoreProvider
// كامل وجاهز (loadStores مع دعم البحث والفلترة عبر الخادم، بالإضافة إلى
// createStore/setVerified/updateStore/deleteStore المُستخدمة أصلاً في
// add_store_screen.dart ولوحة الإدارة). النتيجة العملية للخطأ السابق:
//   • حقل البحث كان يُصفّي محلياً فقط الـ7 متاجر الوهمية الثابتة — لا
//     يستدعي أي endpoint إطلاقاً مهما كتب المستخدم.
//   • عند تبديل AppConfig.useMockData إلى false (ربط الـ backend الحقيقي)،
//     كانت هذه الشاشة تحديداً ستبقى تعرض نفس الـ7 متاجر الوهمية إلى الأبد،
//     بينما كل شاشة أخرى في التطبيق تتحول فعلياً للبيانات الحقيقية — وهو
//     تناقض كان سيصعب اكتشافه لاحقاً.
//
// الإصلاح: الشاشة الآن StoreProvider-based بالكامل:
//   • initState يستدعي StoreProvider.loadStores() (يتحول تلقائياً بين
//     MockData والـ backend الحقيقي حسب AppConfig.useMockData، تماماً كبقية
//     مزودي التطبيق).
//   • حقل البحث مربوط فعلياً بـ StoreProvider.loadStores(search: v) — طلب
//     شبكة حقيقي في الوضع الحقيقي.
//   • فلترة "الكتلة الإدارية"/"الحي" تبقى محلية على القائمة المُحمَّلة (بنفس
//     منطق AdminStoresScreen في admin_shell.dart تماماً)، لأن هذا التصنيف
//     مُشتق من حقل area عبر AleppoBlocks.blockOfArea ولا يحتاج طلب شبكة
//     منفصل لكل كتلة.
//   • أُضيفت حالتا تحميل (CircularProgressIndicator) وخطأ صريحة (نفس نمط
//     ProductsScreen)، بدل الاعتماد الصامت على بيانات محلية دائماً متوفرة.
//
// ✅ بلا أي تغيير آخر في الشكل أو السلوك المرئي: نفس الرأس المتدرّج، نفس
// أزرار الثيم/الإضافة، نفس بطاقة المتجر ونافذة التفاصيل السفلية بالضبط.
// ══════════════════════════════════════════════════════════════════════════
class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  String _blockFilter = 'الكل';
  String _areaFilter = 'الكل';
  String _search = '';

  @override
  void initState() {
    super.initState();
    // ✅ جديد — تحميل قائمة المتاجر الحقيقية (أو الوهمية في وضع العرض
    // التجريبي) عند فتح الشاشة، بنفس نمط بقية شاشات التطبيق
    // (ProductsScreen.initState، AddPriceScreen.initState...).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storeProvider = context.read<StoreProvider>();
      if (storeProvider.stores.isEmpty) {
        storeProvider.loadStores();
      }
    });
  }

  List<String> get _areasOfSelectedBlock {
    if (_blockFilter == 'الكل') return const [];
    return AleppoBlocks.areasOfBlock(_blockFilter);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDarkMode;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textHint = AppColors.textHintOf(context);
    final surface = AppColors.surfaceOf(context);
    final border = AppColors.borderOf(context);

    // ✅ محدَّث — المصدر الآن StoreProvider.stores (حقيقي/وهمي حسب
    // AppConfig.useMockData) بدل MockData.stores المباشرة. البحث النصي يبقى
    // كفلتر إضافي محلي فوري أثناء الكتابة (قبل وصول رد الخادم)، بالإضافة
    // إلى الطلب الفعلي المُرسَل عبر onChanged أدناه.
    final storeProvider = context.watch<StoreProvider>();
    final stores = storeProvider.stores.where((s) {
      final storeBlock = AleppoBlocks.blockOfArea(s.area)?.name;
      final matchesBlock = _blockFilter == 'الكل' || storeBlock == _blockFilter;
      final matchesArea = _areaFilter == 'الكل' || s.area == _areaFilter;
      final matchesSearch = _search.isEmpty ||
          s.name.contains(_search) ||
          s.area.contains(_search);
      return matchesBlock && matchesArea && matchesSearch;
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Column(
          children: [
            // ── رأس متدرّج أزرق ──────────────────────────────────────────
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
                      const Text('المتاجر',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                      // ══════════════════════════════════════════════════
                      // ✅ مجموعة أيقونات أقصى اليسار: زر "إضافة متجر" وزر
                      // تبديل الثيم معاً. أول عنصر في children من Row يظهر
                      // في أقصى اليمين ضمن RTL، فوضع زر الثيم أولاً ثم زر
                      // الإضافة يجعل زر الإضافة يظهر في الطرف الأبعد (أقصى
                      // يسار الشاشة كاملة).
                      // ══════════════════════════════════════════════════
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
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
                                    size: 20),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // زر "إضافة متجر" — ينقل المستخدم إلى
                            // AddStoreScreen حيث يُدخل اسم المتجر، ويختار
                            // الكتلة الإدارية والمنطقة بنفس آلية "إضافة سعر"
                            // (حقل واحد يفتح منتقي الموقع الموحّد)، ثم
                            // العنوان.
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, AppRoutes.addStore),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.add_business_outlined,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ],
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
              child: TextField(
                // ══════════════════════════════════════════════════════
                // ✅ إصلاح جوهري — الآن يُحدَّث الفلتر المحلي فوراً (تجربة
                // استخدام سلسة أثناء الكتابة) ويُرسَل طلب بحث فعلي عبر
                // StoreProvider.loadStores(search: v) في نفس الوقت، بنفس
                // نمط ProductsScreen.WaffirSearchField أعلاه في هذا الملف
                // وProductsScreen في products_screen.dart. سابقاً كان
                // onChanged يُحدِّث فقط setState محلياً بلا أي طلب شبكة.
                // ══════════════════════════════════════════════════════
                onChanged: (v) {
                  setState(() => _search = v);
                  context.read<StoreProvider>().loadStores(search: v);
                },
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'ابحث عن متجر...',
                  hintStyle: TextStyle(color: textHint),
                  prefixIcon: Icon(Icons.search, color: textHint),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2)),
                  filled: true,
                  fillColor: surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // ── صف فلترة الكتلة الإدارية ────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: AleppoBlocks.all.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final label = i == 0 ? 'الكل' : AleppoBlocks.all[i - 1].name;
                  final selected = _blockFilter == label;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _blockFilter = label;
                      _areaFilter = 'الكل';
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: selected ? AppColors.primary : border),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondaryOf(context),
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                    ),
                  );
                },
              ),
            ),
            // ── صف فلترة الحي ─────────────────────────────────────────
            if (_blockFilter != 'الكل') ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _areasOfSelectedBlock.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    final label =
                        i == 0 ? 'الكل' : _areasOfSelectedBlock[i - 1];
                    final selected = _areaFilter == label;
                    return GestureDetector(
                      onTap: () => setState(() => _areaFilter = label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: selected ? AppColors.primary : border,
                              width: 1),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondaryOf(context),
                                fontSize: 11.5,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            // ══════════════════════════════════════════════════════════
            // ✅ جديد — حالات تحميل/خطأ/فارغ صريحة، بنفس نمط ProductsScreen
            // في products_screen.dart، بدل الاعتماد الصامت على أن البيانات
            // متوفرة دائماً محلياً كما كان الحال مع MockData.
            // ══════════════════════════════════════════════════════════
            Expanded(
              child: storeProvider.isLoading && storeProvider.stores.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : storeProvider.state == LoadingState.error &&
                          storeProvider.stores.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 32, color: AppColors.error),
                              const SizedBox(height: 8),
                              Text(
                                  storeProvider.errorMessage ??
                                      'تعذّر تحميل المتاجر',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color:
                                          AppColors.textSecondaryOf(context))),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => context
                                    .read<StoreProvider>()
                                    .loadStores(search: _search),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        )
                      : stores.isEmpty
                          ? Center(
                              child: Text('لا توجد متاجر',
                                  style: TextStyle(
                                      color:
                                          AppColors.textSecondaryOf(context))))
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: stores.length,
                              itemBuilder: (ctx, i) =>
                                  _StoreCard(store: stores[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final StoreModel store;
  const _StoreCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surfaceOf(context);
    final border = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final isDark = AppColors.isDark(context);
    final block = AleppoBlocks.blockOfArea(store.area)?.name ?? store.sector;

    return GestureDetector(
      onTap: () => _showStoreDetail(context, store, block),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (store.isVerified)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success
                                .withValues(alpha: isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('موثق',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      Text(store.name,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(store.address,
                      style: TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text('${store.pricesCount} سعر',
                          style: TextStyle(color: textSecondary, fontSize: 11)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary
                              .withValues(alpha: isDark ? 0.2 : 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(store.area,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.store_outlined,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_back_ios,
                size: 14, color: AppColors.textHintOf(context)),
          ],
        ),
      ),
    );
  }

  void _showStoreDetail(BuildContext context, StoreModel store, String block) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, ctrl) => ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.borderOf(ctx),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.store,
                        color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.name,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryOf(ctx))),
                        Text(block,
                            style: TextStyle(
                                color: AppColors.textSecondaryOf(ctx))),
                      ],
                    ),
                  ),
                  if (store.isVerified)
                    const Icon(Icons.verified,
                        color: AppColors.success, size: 24),
                ],
              ),
              const SizedBox(height: 20),
              _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'العنوان',
                  value: store.address),
              _DetailRow(
                  icon: Icons.map_outlined, label: 'المنطقة', value: store.area),
              _DetailRow(
                  icon: Icons.location_city,
                  label: 'الكتلة الإدارية',
                  value: block),
              _DetailRow(
                  icon: Icons.attach_money,
                  label: 'عدد الأسعار',
                  value: '${store.pricesCount} سعر مسجل'),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, AppRoutes.addPrice,
                      arguments: store);
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('إضافة سعر منتج لهذا المتجر'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
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