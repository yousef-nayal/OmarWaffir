import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_provider.dart';
import '../../../core/constants/aleppo_blocks.dart';
import '../../../core/widgets/common_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════
// ADD STORE SCREEN — اقتراح متجر جديد
// ✅ جديد — تُفتح من زر "إضافة متجر" في رأس شاشة "المتاجر". تتبع بالضبط
// نفس آلية اختيار الموقع المستخدمة في AddPriceScreen: حقل واحد "الكتلة
// والمنطقة" يفتح منتقي الموقع الموحّد (showLocationPickerSheet من
// common_widgets.dart)، ثم اسم المتجر والعنوان.
//
// الإرسال يمرّ عبر StoreProvider.createStore الموجودة أصلاً (تتحول تلقائياً
// بين وضع العرض التجريبي والـ backend الحقيقي حسب AppConfig.useMockData،
// راجع app_provider.dart). المتجر الجديد يُضاف بحالة "غير موثّق" افتراضياً
// (isVerified: false) بانتظار مراجعة الإدارة، تماماً كأي متجر يُقترح من
// مستخدم — هذا سلوك متعمّد وليس نقصاً.
//
// ✅ إصلاح جوهري إضافي (بلا أي تغيير مرئي): جدول Store في قاعدة البيانات
// الفعلية يتطلب location_id (مفتاح أجنبي حقيقي)، لا نصوص area/sector حرة.
// الآن تُحمَّل قائمة المواقع الفعلية من الخادم عند فتح الشاشة، ويُترجَم
// الحي المختار إلى location_id حقيقي عبر CatalogProvider.locationIdForArea
// قبل الإرسال — حقل اختيار الموقع نفسه بلا أي تغيير في شكله أو سلوكه.
// ══════════════════════════════════════════════════════════════════════════
class AddStoreScreen extends StatefulWidget {
  const AddStoreScreen({super.key});

  @override
  State<AddStoreScreen> createState() => _AddStoreScreenState();
}

class _AddStoreScreenState extends State<AddStoreScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _selectedBlock;
  String? _selectedArea;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // ✅ جديد — تحميل قائمة المواقع الحقيقية من الخادم (GET /locations) عند
    // فتح الشاشة، لتكون جاهزة لترجمة الحي المختار إلى location_id عند
    // الإرسال (راجع نفس الآلية في RegisterScreen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalogProvider = context.read<CatalogProvider>();
      if (catalogProvider.locations.isEmpty) {
        catalogProvider.loadLocations();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  /// ✅ نفس آلية اختيار الموقع المستخدمة في AddPriceScreen وصف "تغيير
  // الموقع" بالإعدادات — الكتلة والمنطقة يُختاران معاً بنقرة واحدة.
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

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack('يرجى إدخال اسم المتجر', isError: true);
      return;
    }
    if (_selectedBlock == null || _selectedArea == null) {
      _showSnack('يرجى اختيار الكتلة الإدارية والمنطقة', isError: true);
      return;
    }
    if (address.isEmpty) {
      _showSnack('يرجى إدخال عنوان المتجر', isError: true);
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // ✅ جديد — ترجمة الحي المختار إلى location_id حقيقي قبل الإرسال. في
    // وضع العرض التجريبي هذه القيمة تُتجاهَل تماماً داخل
    // StoreProvider.createStore، فلا تأثير لها على تجربة العرض التجريبي.
    final locationId =
        context.read<CatalogProvider>().locationIdForArea(_selectedArea!);
    setState(() => _loading = true);

    final ok = await context.read<StoreProvider>().createStore(
          name: name,
          address: address,
          area: _selectedArea!,
          sector: _selectedBlock!,
          locationId: locationId,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('تم إرسال المتجر بنجاح، بانتظار مراجعة الإدارة'),
        backgroundColor: AppColors.success,
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(context.read<StoreProvider>().errorMessage ??
            'تعذّر إضافة المتجر، حاول مجدداً'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  void _showSnack(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إضافة متجر'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ساعد مجتمع وفّر بإضافة متجر جديد لتسهيل الوصول إلى الأسعار الحقيقية',
                  style: TextStyle(
                      color: AppColors.textSecondaryOf(context), fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),

              _lbl(context, 'اسم المتجر'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                    hintText: 'مثال: محل الأمانة',
                    prefixIcon: Icon(Icons.storefront_outlined)),
              ),
              const SizedBox(height: 16),

              // ══════════════════════════════════════════════════════════
              // ✅ حقل "الكتلة والمنطقة" — بنفس شكل وآلية AddPriceScreen:
              // نقرة واحدة تفتح منتقي الموقع الموحّد (الكتل الخمس، كل كتلة
              // قابلة للطي وتعرض أحياءها).
              // ══════════════════════════════════════════════════════════
              _lbl(context, 'الكتلة والمنطقة'),
              const SizedBox(height: 8),
              _LocationPickerField(
                block: _selectedBlock,
                area: _selectedArea,
                onTap: _pickLocation,
              ),
              const SizedBox(height: 16),

              _lbl(context, 'العنوان'),
              const SizedBox(height: 8),
              TextField(
                controller: _addressCtrl,
                textDirection: TextDirection.rtl,
                maxLines: 2,
                decoration: const InputDecoration(
                    hintText: 'مثال: شارع الفرقان الرئيسي',
                    prefixIcon: Icon(Icons.location_on_outlined)),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'سيخضع المتجر لمراجعة فريق الإشراف قبل ظهوره كمتجر موثّق',
                        style: TextStyle(fontSize: 12, color: AppColors.primary)),
                  ),
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
                    : const Text('إضافة المتجر'),
              ),
            ],
          ),
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

/// ✅ نسخة محلية من نفس حقل اختيار الموقع الموجود في AddPriceScreen
/// (products_screen.dart) — بنفس الشكل والسلوك تماماً، لكن كعنصر خاص بهذا
/// الملف لأن الأصل مُعرَّف بشكل خاص (private) هناك.
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