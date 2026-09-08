import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_provider.dart';
import '../../../models/models.dart';

// ══════════════════════════════════════════════════════════════════════════
// OFFICIAL PRICE HISTORY SCREEN
// ✅ سجل تغييرات السعر الرسمي لمادة واحدة عبر الزمن. تُفتح من
// OfficialPricesScreen عند النقر على أي بطاقة سعر رسمي. تعرض خطاً زمنياً
// (Timeline) مرتباً من الأحدث إلى الأقدم، مع نسبة التغيير بين كل تحديث
// والذي يسبقه (ارتفاع/انخفاض/بلا تغيير)، اعتماداً على
// CatalogProvider.loadOfficialPriceHistory التي تتحول تلقائياً بين
// MockData والـ backend الحقيقي حسب AppConfig.useMockData
// (راجع GET /official-prices/{id}/history في CatalogService).
//
// ✅ تحديث الرأس: "سجل السعر الرسمي" أصبح عنواناً رئيسياً واضحاً في أعلى
// منتصف الشاشة (بدل شارة صغيرة سابقاً). زر الرجوع انتقل إلى أقصى اليمين،
// وزر تبديل الثيم (فاتح/داكن) أصبح في مكانه أقصى اليسار — بنفس نمط رؤوس
// stores_screen.dart وproducts_screen.dart لثبات الهوية البصرية عبر التطبيق.
// ══════════════════════════════════════════════════════════════════════════
class OfficialPriceHistoryScreen extends StatefulWidget {
  const OfficialPriceHistoryScreen({super.key});

  @override
  State<OfficialPriceHistoryScreen> createState() =>
      _OfficialPriceHistoryScreenState();
}

class _OfficialPriceHistoryScreenState
    extends State<OfficialPriceHistoryScreen> {
  OfficialPrice? _officialPrice;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is OfficialPrice) _officialPrice = args;
      _initialized = true;
      if (_officialPrice != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context
              .read<CatalogProvider>()
              .loadOfficialPriceHistory(_officialPrice!.id);
        });
      }
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtPrice(double v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(0)},${(v % 1000).toInt().toString().padLeft(3, '0')}'
      : v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final op = _officialPrice;
    final provider = context.watch<AppProvider>();
    final catalog = context.watch<CatalogProvider>();
    final history = catalog.officialPriceHistory;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: op == null
            ? const Center(child: Text('تعذّر تحميل بيانات المادة'))
            : CustomScrollView(
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
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ══════════════════════════════════════════
                              // ✅ شريط الرأس: عنوان "سجل السعر الرسمي"
                              // كعنوان رئيسي في المنتصف تماماً، زر الرجوع
                              // في أقصى اليمين، وزر تبديل الثيم في أقصى
                              // اليسار — بنفس نمط بقية شاشات التطبيق.
                              // ══════════════════════════════════════════
                              SizedBox(
                                height: 44,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const Text('سجل السعر الرسمي',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700)),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        icon: const Icon(
                                            Icons.arrow_forward_ios,
                                            color: Colors.white,
                                            size: 18),
                                        onPressed: () =>
                                            Navigator.pop(context),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: IconButton(
                                        icon: Icon(
                                            provider.isDarkMode
                                                ? Icons.light_mode_outlined
                                                : Icons.dark_mode_outlined,
                                            color: Colors.white,
                                            size: 20),
                                        onPressed: provider.toggleDarkMode,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(op.productName,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('السعر الحالي',
                                                  style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.75),
                                                      fontSize: 11)),
                                              const SizedBox(height: 4),
                                              Text(
                                                  '${_fmtPrice(op.price)} ل.س/${op.unit}',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 19,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text('آخر تحديث',
                                                  style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.75),
                                                      fontSize: 11)),
                                              const SizedBox(height: 4),
                                              Text(_fmtDate(op.updatedAt),
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ],
                                          ),
                                        ],
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
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('سجل التغييرات',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryOf(context))),
                            Text('${history.length} تحديث',
                                style: TextStyle(
                                    color: AppColors.textSecondaryOf(context),
                                    fontSize: 12.5)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (catalog.isLoadingHistory)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (catalog.historyErrorMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: Center(
                              child: Text(
                                  catalog.historyErrorMessage ??
                                      'تعذّر تحميل السجل',
                                  style:
                                      const TextStyle(color: AppColors.error)),
                            ),
                          )
                        else if (history.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.history,
                                      size: 36,
                                      color: AppColors.textHintOf(context)),
                                  const SizedBox(height: 8),
                                  Text('لا يوجد سجل تغييرات لهذه المادة بعد',
                                      style: TextStyle(
                                          color: AppColors.textSecondaryOf(
                                              context))),
                                ],
                              ),
                            ),
                          )
                        else
                          _HistoryTimeline(
                            history: history,
                            fmtDate: _fmtDate,
                            fmtPrice: _fmtPrice,
                          ),
                        const SizedBox(height: 24),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// TIMELINE WIDGET — خط زمني رأسي، كل نقطة تمثل تحديثاً للسعر مع نسبة
// التغيير عن التحديث الذي يسبقه زمنياً (الأقدم منه مباشرة).
// ══════════════════════════════════════════════════════════════════════════
class _HistoryTimeline extends StatelessWidget {
  final List<OfficialPriceHistoryEntry> history;
  final String Function(DateTime) fmtDate;
  final String Function(double) fmtPrice;

  const _HistoryTimeline({
    required this.history,
    required this.fmtDate,
    required this.fmtPrice,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ ترتيب تنازلي (الأحدث أولاً) بغض النظر عن ترتيب وصول البيانات
    final sorted = [...history]
      ..sort((a, b) => b.changedAt.compareTo(a.changedAt));

    return Column(
      children: List.generate(sorted.length, (i) {
        final entry = sorted[i];
        final previous = i + 1 < sorted.length ? sorted[i + 1] : null;
        final diff = previous == null ? 0.0 : entry.price - previous.price;
        final isUp = diff > 0;
        final isFirst = i == 0;
        final isLast = i == sorted.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── نقطة وخط الزمن ────────────────────────────────────
              Column(
                children: [
                  Container(
                    width: isFirst ? 14 : 10,
                    height: isFirst ? 14 : 10,
                    margin: EdgeInsets.only(top: isFirst ? 2 : 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isFirst ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                          color: AppColors.primary, width: isFirst ? 0 : 2),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: AppColors.borderOf(context),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // ── بطاقة التحديث ────────────────────────────────────────
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isFirst
                            ? AppColors.primary.withValues(alpha: 0.35)
                            : AppColors.borderOf(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${fmtPrice(entry.price)} ل.س',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: isFirst
                                          ? AppColors.primary
                                          : AppColors.textPrimaryOf(
                                              context))),
                              if (isFirst) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('الحالي',
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ],
                          ),
                          if (previous != null && diff != 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isUp
                                        ? AppColors.error
                                        : AppColors.success)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      isUp
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      size: 13,
                                      color: isUp
                                          ? AppColors.error
                                          : AppColors.success),
                                  const SizedBox(width: 3),
                                  Text(
                                      '${((diff.abs() / previous.price) * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isUp
                                              ? AppColors.error
                                              : AppColors.success)),
                                ],
                              ),
                            )
                          else if (previous != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.textHintOf(context)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('بلا تغيير',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondaryOf(
                                          context))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 12, color: AppColors.textHintOf(context)),
                          const SizedBox(width: 4),
                          Text(fmtDate(entry.changedAt),
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      AppColors.textSecondaryOf(context))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}