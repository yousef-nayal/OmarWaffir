import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import 'screens/home_screen.dart';
import 'screens/products_screen.dart';
import 'screens/stores_screen.dart';
import 'screens/profile_screen.dart';

class UserShell extends StatefulWidget {
  const UserShell({super.key});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  // Nav indices: 0=Home, 1=Products, 2=FAB(unused), 3=Stores, 4=Profile
  int _currentIndex = 0;

  // Maps _currentIndex → IndexedStack child index (0-3)
  // This MUST stay in sync with the children list below
  int get _stackIndex {
    switch (_currentIndex) {
      case 1:
        return 1; // ProductsScreen
      case 3:
        return 2; // StoresScreen
      case 4:
        return 3; // ProfileScreen
      default:
        return 0; // HomeScreen (covers 0 and 2/FAB)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // IndexedStack keeps all screens alive (no rebuild on tab switch)
        // Children order MUST match _stackIndex mapping above
        body: IndexedStack(
          index: _stackIndex,
          children: const [
            HomeScreen(), // stackIndex 0
            ProductsScreen(), // stackIndex 1
            StoresScreen(), // stackIndex 2
            ProfileScreen(), // stackIndex 3
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.addPrice),
          backgroundColor: AppColors.primary,
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          elevation: 8,
          color: Theme.of(context).colorScheme.surface,
          child: SizedBox(
            height: 64,
            // ══════════════════════════════════════════════════════════
            // ✅ إصلاح جوهري لعدم اتساق المسافات بين الشاشات: كانت العناصر
            // توزَّع عبر mainAxisAlignment.spaceAround بحجمها الطبيعي فقط
            // (MainAxisSize.min). المشكلة أن نص العنصر المُحدَّد يتحوّل إلى
            // FontWeight.w600 (أعرض من الخط العادي) وأيقونته تتغيّر لنسخة
            // مملوءة — أي أن عرض العنصر المُحدَّد يتغيّر فعلياً بين شاشة
            // وأخرى، وبما أن spaceAround يعيد توزيع المسافات بناءً على
            // مجموع عروض كل العناصر، فإن أي تغيّر في عرض عنصر واحد يُزيح
            // كل المسافات في الصف — وهذا بالضبط سبب اختلاف شكل الشريط بين
            // "الرئيسية" (حيث الرئيسية محدَّدة) و"الملف الشخصي" (حيث الملف
            // الشخصي محدَّد، وهو نص أطول بكثير).
            //
            // الإصلاح: كل عنصر تنقّل يأخذ الآن حيّزاً ثابتاً بنسبة متساوية
            // (Expanded flex:1) بغض النظر عن محتواه أو حالة تحديده، وفراغ
            // الزر العائم أصبح بعرض ثابت غير مرن (64) بدل 48 ليطابق حجم
            // الزر العائم الفعلي (56) + هامش الفتحة (notchMargin: 8) بدقة.
            // هذا يضمن مسافات متطابقة تماماً بين كل الأيقونات في كل شاشات
            // التطبيق، بصرف النظر عن أي عنصر محدَّد حالياً.
            // ══════════════════════════════════════════════════════════
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _NavItem(
                      icon: Icons.home_outlined,
                      label: 'الرئيسية',
                      index: 0,
                      current: _currentIndex,
                      onTap: (i) => setState(() => _currentIndex = i)),
                ),
                Expanded(
                  child: _NavItem(
                      icon: Icons.shopping_basket_outlined,
                      label: 'المنتجات',
                      index: 1,
                      current: _currentIndex,
                      onTap: (i) => setState(() => _currentIndex = i)),
                ),
                const SizedBox(width: 64), // فراغ ثابت للزر العائم
                Expanded(
                  child: _NavItem(
                      icon: Icons.store_outlined,
                      label: 'المتاجر',
                      index: 3,
                      current: _currentIndex,
                      onTap: (i) => setState(() => _currentIndex = i)),
                ),
                Expanded(
                  child: _NavItem(
                      icon: Icons.person_outline,
                      label: 'الملف الشخصي',
                      index: 4,
                      current: _currentIndex,
                      onTap: (i) => setState(() => _currentIndex = i)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == index;
    final color = isSelected ? AppColors.primary : AppColors.textHint;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      // ✅ Container بعرض كامل (يملأ الـ Expanded) بدل Padding أفقي ثابت،
      // ليكون منطقة اللمس والمحاذاة متطابقة تماماً لكل عنصر بصرف النظر عن
      // طول نصه.
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? _filledIcon(icon) : icon, color: color, size: 24),
            const SizedBox(height: 2),
            // ✅ FittedBox يمنع فيضان النص الطويل ("الملف الشخصي") داخل
            // الحيّز الثابت، ويضمن أيضاً أن تحوّل الخط إلى Bold عند التحديد
            // لا يغيّر عرض الحيّز نفسه (لأن Expanded أعلاه ثابت أصلاً) —
            // فقط يتقلّص النص تلقائياً إن لزم بدل أن يفيض أو يُزيح التخطيط.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  IconData _filledIcon(IconData icon) {
    if (icon == Icons.home_outlined) return Icons.home;
    if (icon == Icons.shopping_basket_outlined) return Icons.shopping_basket;
    if (icon == Icons.store_outlined) return Icons.store;
    if (icon == Icons.person_outline) return Icons.person;
    return icon;
  }
}
