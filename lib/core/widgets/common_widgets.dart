import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../constants/aleppo_blocks.dart';

// ── Location Picker Bottom Sheet ────────────────────────────────────────────
// ✅ إصلاح شامل جديد: كان منتقي الموقع يعرض قائمة مسطحة من 10 مناطق وهمية لا
// تطابق التقسيم الإداري الرسمي لحلب. الآن يعرض القوائم الرسمية الخمس (الكتل
// الإدارية) من aleppo_blocks.dart، كل كتلة قابلة للطي/الفتح (ExpansionTile)
// وتعرض أحياءها الحقيقية عند فتحها. يبقى قابلاً للتمرير والسحب
// (DraggableScrollableSheet) بغض النظر عن عدد الأحياء داخل كل كتلة.
//
// onSelect يُرجع (اسم الكتلة, اسم المنطقة) معاً حتى تُخزَّن الكتلة بشكل
// صريح في AppProvider بدل استنتاجها لاحقاً من اسم المنطقة فقط.
Future<void> showLocationPickerSheet(
  BuildContext context, {
  required String currentBlock,
  required String currentArea,
  required void Function(String block, String area) onSelect,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.borderOf(ctx),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('اختر موقعك',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryOf(ctx))),
                    const SizedBox(height: 2),
                    Text('اختر الكتلة  ثم المنطقة التابع لها',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryOf(ctx))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: AleppoBlocks.all.length,
                itemBuilder: (_, i) {
                  final block = AleppoBlocks.all[i];
                  final isCurrentBlock = currentBlock == block.name;
                  return Theme(
                    data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOf(ctx),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isCurrentBlock
                                ? AppColors.primary
                                : AppColors.borderOf(ctx)),
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: isCurrentBlock,
                        shape: const RoundedRectangleBorder(
                            side: BorderSide(color: Colors.transparent)),
                        collapsedShape: const RoundedRectangleBorder(
                            side: BorderSide(color: Colors.transparent)),
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: isCurrentBlock ? 1 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text('${block.number}',
                                style: TextStyle(
                                    color: isCurrentBlock
                                        ? Colors.white
                                        : AppColors.primary,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        title: Text(block.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimaryOf(ctx))),
                        subtitle: Text('${block.areas.length} منطقة',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryOf(ctx))),
                        children: block.areas.map((area) {
                          final selected =
                              isCurrentBlock && currentArea == area;
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on_outlined,
                                color: AppColors.primary, size: 18),
                            title: Text(area,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimaryOf(ctx),
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400)),
                            trailing: selected
                                ? const Icon(Icons.check,
                                    color: AppColors.primary, size: 18)
                                : null,
                            onTap: () {
                              onSelect(block.name, area);
                              Navigator.pop(ctx);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── App Bar ──────────────────────────────────────────────────────────────────
class WaffirAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showBack;
  final List<Widget>? actions;
  final bool isAdmin;

  const WaffirAppBar({
    super.key,
    this.title,
    this.showBack = false,
    this.actions,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: title != null
          ? Text(title!,
              style: TextStyle(
                  color: isAdmin ? AppColors.primary : AppColors.primary))
          : null,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
// ✅ تم إصلاح فيضان النص (overflow) الذي كان يجعل الأرقام تُكتب رقماً رقماً
//    عمودياً عند ضيق المساحة المتاحة (كما في لوحة الإدارة على الهاتف).
class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final String? growth;
  final bool isPositive;

  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    this.growth,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ maxLines + overflow يمنعان التفاف الأرقام حرفاً حرفاً
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryOf(context))),
                  const SizedBox(height: 2),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 13)),
                ],
              ),
            ),
            if (growth != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppColors.successLight.withValues(
                          alpha: AppColors.isDark(context) ? 0.18 : 1)
                      : AppColors.errorLight.withValues(
                          alpha: AppColors.isDark(context) ? 0.18 : 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 14,
                      color: isPositive ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      growth!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPositive ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Price Change Badge ────────────────────────────────────────────────────────
class PriceChangeBadge extends StatelessWidget {
  final double percent;
  final bool isUp;

  const PriceChangeBadge(
      {super.key, required this.percent, required this.isUp});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isUp ? AppColors.errorLight : AppColors.successLight)
            .withValues(alpha: isDark ? 0.18 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: isUp ? AppColors.priceUp : AppColors.priceDown,
          ),
          const SizedBox(width: 2),
          Text(
            '${percent.toStringAsFixed(0)}%+',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isUp ? AppColors.priceUp : AppColors.priceDown,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search Field ─────────────────────────────────────────────────────────────
class WaffirSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;

  const WaffirSearchField({super.key, required this.hint, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final border = AppColors.borderOf(context);
    return TextField(
      onChanged: onChanged,
      textDirection: TextDirection.rtl,
      style: TextStyle(color: AppColors.textPrimaryOf(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textHintOf(context)),
        prefixIcon: Icon(Icons.search, color: AppColors.textHintOf(context)),
        filled: true,
        fillColor: AppColors.surfaceOf(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// ── Filter Chip Row ───────────────────────────────────────────────────────────
class FilterChipRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surfaceOf(context);
    final border = AppColors.borderOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: options.map((opt) {
          final isSelected = opt == selected;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => onSelected(opt),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : border,
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSelected ? Colors.white : textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Admin Sidebar Item ────────────────────────────────────────────────────────
class SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confirm Dialog ────────────────────────────────────────────────────────────
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  Color confirmColor = AppColors.error,
  IconData? icon,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: confirmColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: confirmColor, size: 28),
              ),
            if (icon != null) const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(ctx)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: TextStyle(
                    color: AppColors.textSecondaryOf(ctx), fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
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
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      minimumSize: const Size(0, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Add Dialog ────────────────────────────────────────────────────────────────
// ✅ محدَّث — أُضيف [initialValue] اختياري ليُستخدَم أيضاً كنافذة "تعديل"
// موحّدة (تعبئة الحقل بالقيمة الحالية) بدل الاقتصار على الإضافة فقط.
Future<String?> showAddDialog(
  BuildContext context, {
  required String title,
  required String fieldLabel,
  required String hint,
  String? initialValue,
  String confirmLabel = 'إضافة',
}) {
  final ctrl = TextEditingController(text: initialValue ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(ctx))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fieldLabel,
                style: TextStyle(
                    color: AppColors.textSecondaryOf(ctx), fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(hintText: hint),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
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
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(confirmLabel),
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

// ── Coming Soon Dialog ────────────────────────────────────────────────────────
Future<void> showComingSoonDialog(
  BuildContext context, {
  required String title,
  String message = 'هذه الميزة قيد التطوير وستكون متاحة بعد ربط التطبيق بالخادم.',
  IconData icon = Icons.hourglass_top_outlined,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(ctx)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: TextStyle(
                    color: AppColors.textSecondaryOf(ctx), fontSize: 13.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                child: const Text('حسناً'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}