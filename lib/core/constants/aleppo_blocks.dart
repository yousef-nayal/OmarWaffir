// ══════════════════════════════════════════════════════════════════════════
// كتل محافظة حلب الإدارية (المصدر: المنشور الرسمي لمحافظة حلب + كتل يضيفها
// المسؤول من داخل التطبيق)
// ══════════════════════════════════════════════════════════════════════════
//
// ✅ نقطة مرجعية واحدة لكل بيانات الكتل/الأحياء في التطبيق. أي شاشة تحتاج
// قائمة الكتل، أو أحياء كتلة معيّنة، أو معرفة أي كتلة ينتمي إليها حي معيّن،
// تستخدم هذا الملف بدل تكرار القوائم محلياً.
//
// ✅ جديد — أصبحت الكتل قابلة للتوسّع: بالإضافة إلى الكتل الخمس الرسمية
// الثابتة، يمكن للمسؤول الآن إضافة كتل جديدة من شاشة "تعديل الكتل"
// (AdminBlocksScreen في admin_shell.dart). الكتل المضافة تُحفَظ محلياً عبر
// SharedPreferences فتبقى موجودة بعد إغلاق التطبيق، وتظهر تلقائياً في كل
// مكان يعتمد على [AleppoBlocks.all] أو المشتقات منها (blockNames،
// areasOfBlock، منتقي الموقع الموحّد showLocationPickerSheet، قوائم فلترة
// الكتل الإدارية في كل شاشات لوحة الإدارة...) بلا أي حاجة لتعديل أي من تلك
// الشاشات — لأنها جميعها تقرأ من هذا الملف فقط، لا من قيمة ثابتة منسوخة.
//
// مكان الملف: lib/core/constants/aleppo_blocks.dart
// ══════════════════════════════════════════════════════════════════════════

import 'package:shared_preferences/shared_preferences.dart';

class AleppoBlock {
  final int number; // 1..5 للكتل الرسمية، وأرقام تسلسلية تالية للمضافة
  final String name; // "الكتلة الأولى"
  final List<String> areas;

  const AleppoBlock({
    required this.number,
    required this.name,
    required this.areas,
  });
}

class AleppoBlocks {
  AleppoBlocks._();

  // ── الكتل الخمس الرسمية — ثابتة، لا يمكن حذفها أو تغيير اسمها بنيوياً ──
  static const List<AleppoBlock> _officialBlocks = [
    AleppoBlock(
      number: 1,
      name: 'الكتلة الأولى',
      areas: [
        'ألمجي',
        'قسطل المشط',
        'الجلوم',
        'الفرافرة',
        'صاجليخان',
        'محمد بك',
        'الأعجام',
        'العقبة',
        'بيت محب',
        'اقيول',
        'ابن يعقوب',
        'براج',
        'بلاط',
        'ضوضو',
        'قلعة شريف',
        'القصيلة',
      ],
    ),
    AleppoBlock(
      number: 2,
      name: 'الكتلة الثانية',
      areas: [
        'الإسماعيلية',
        'الجميلية',
        'العزيزية',
        'محطة بغداد',
        'العروبة',
        'الحميدية',
        'الجابرية',
        'السليمانية',
        'السريان',
        'الزهور',
        'طارق بن زياد',
        'الأشرفية',
        'الشيخ مقصود 1',
        'الشيخ مقصود 2',
        'تشرين',
        'الرصافة',
        'اليرمون',
        'الشيخ أبو بكر',
        'جبل الغزالات',
        'سليمان الحلبي',
        'الشيخ خضر',
        'الشيخ فارس',
        'تراب العلك',
        'عين التل',
        'الحيدرية 1',
        'الحيدرية 2',
        'الصاخور 1',
        'الصاخور 2',
        'الصاخور 3',
        'العويجة وتوابعها',
        'البكارة وتوابعها',
        'مخيم حندرات',
        'قرية حندرات',
      ],
    ),
    AleppoBlock(
      number: 3,
      name: 'الكتلة الثالثة',
      areas: [
        'هنانو 1',
        'هنانو 2',
        'هنانو 3',
        'الباسل',
        'الحلوانية',
        'جورة عواد',
        'ضهرة عواد',
        'كرم الجبل',
        'قارلق',
        'تربة لالا',
        'كرم القاطرجي',
        'كرم ميسر',
        'دويرينة',
        'جبرين',
        'المالكية',
        'النيرب',
        'مضاف النيرب',
        'النيرب جنوبي',
      ],
    ),
    AleppoBlock(
      number: 4,
      name: 'الكتلة الرابعة',
      areas: [
        'مقر الأنبياء',
        'باب المقام',
        'الصالحين',
        'الفردوس',
        'كرم الدعدع',
        'الكلاسة',
        'بستان القصر',
        'المشارقة',
        'الإذاعة',
        'سيف الدولة',
        'صلاح الدين',
        'أرض الصباغ',
        'أنصاري مشهد',
        'سعد الأنصاري',
        'السكري',
        'تل الزرازير',
        'الشيخ سعيد',
      ],
    ),
    AleppoBlock(
      number: 5,
      name: 'الكتلة الخامسة',
      areas: [
        'الكواكبي',
        'المحافظة',
        'السبيل',
        'معهد حلب العلمي',
        'الفرقان',
        'الشهباء',
        'الخالدية',
        'الوفاء',
        'الغزالي',
        'الزهراء',
        'النصر',
        'حلب الجديدة الشمالي',
        'حلب الجديدة الغربي',
        'حلب الجديدة الشهداء',
        'حلب الجديدة الجنوبي',
        'الحمدانية الفيلات',
        'الحمدانية الحي الأول',
        'الحمدانية الحي الثاني',
        'الحمدانية الحي الثالث',
        'الحمدانية الحي الرابع',
        'الحمدانية حي الريادة',
        'الحمدانية ضاحية الأسد',
        'الراشدين',
        'كفر داعل',
        'خان العسل',
      ],
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — كتل يضيفها المسؤول من داخل التطبيق. تُحفَظ محلياً عبر
  // SharedPreferences (سطر نصي واحد لكل كتلة: "الرقم|الاسم|حي1,,حي2,,حي3")
  // ليبقين موجودات بعد إغلاق التطبيق. يجب استدعاء [initialize] مرة واحدة
  // عند إقلاع التطبيق (راجع main.dart) قبل أي استخدام لـ[all] لضمان تحميل
  // الكتل المحفوظة سابقاً قبل بناء أي واجهة تعتمد عليها.
  // ══════════════════════════════════════════════════════════════════════
  static final List<AleppoBlock> _customBlocks = [];
  static bool _initialized = false;
  static const String _prefsKey = 'custom_aleppo_blocks_v1';
  static final Set<String> _deletedOfficialBlockNames = {};
  static const String _deletedOfficialPrefsKey =
      'deleted_official_aleppo_blocks_v1';

  /// كل الكتل المعروفة حالياً: الخمس الرسمية أولاً، ثم أي كتل أضافها
  /// المسؤول (بترتيب الإضافة). هذا هو المصدر الوحيد الذي يجب أن تعتمد عليه
  /// أي شاشة أو منتقي موقع في التطبيق.
  static List<AleppoBlock> get all => [
        ..._officialBlocks
            .where((b) => !_deletedOfficialBlockNames.contains(b.name)),
        ..._customBlocks,
      ];

  /// ✅ جديد — يحمّل الكتل المضافة سابقاً من التخزين المحلي. آمن للاستدعاء
  /// أكثر من مرة (لا يكرر التحميل). يجب استدعاؤه مرة عند إقلاع التطبيق قبل
  /// runApp، حتى تكون الكتل المضافة جاهزة فوراً في كل الشاشات.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? [];
      _customBlocks
        ..clear()
        ..addAll(raw.map(_decode));
      final deletedOfficial =
          prefs.getStringList(_deletedOfficialPrefsKey) ?? [];
      _deletedOfficialBlockNames
        ..clear()
        ..addAll(deletedOfficial);
    } catch (_) {
      // في حال فشل القراءة (تخزين تالف مثلاً) نبدأ بقائمة فارغة بأمان بدل
      // تعطيل التطبيق بالكامل.
    }
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _customBlocks.map(_encode).toList());
  }

  static Future<void> _persistDeletedOfficial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _deletedOfficialPrefsKey, _deletedOfficialBlockNames.toList());
  }

  static String _encode(AleppoBlock b) =>
      '${b.number}|${b.name}|${b.areas.join(',,')}';

  static AleppoBlock _decode(String raw) {
    final parts = raw.split('|');
    final number = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final name = parts.length > 1 ? parts[1] : '';
    final areas = (parts.length > 2 && parts[2].isNotEmpty)
        ? parts[2].split(',,')
        : <String>[];
    return AleppoBlock(number: number, name: name, areas: areas);
  }

  /// ✅ جديد — هل هذه كتلة أضافها المسؤول (وليست إحدى الكتل الخمس
  /// الرسمية)؟ تُستخدم لتحديد ما إذا كان يمكن إعادة تسميتها/حذفها بالكامل
  /// من شاشة "تعديل الكتل".
  static bool isCustomBlock(String name) =>
      _customBlocks.any((b) => b.name == name);

  static bool isOfficialBlock(String name) =>
      _officialBlocks.any((b) => b.name == name);

  /// ✅ جديد — إضافة كتلة جديدة باسم فريد، مع إمكانية تزويدها بأحيائها
  /// الأولية مباشرة (اختياري تماماً — يمكن إضافة الأحياء لاحقاً من "إدارة
  /// الكتل والمناطق"). يرفض الاسم الفارغ أو المكرر مع أي كتلة موجودة فعلاً
  /// (رسمية أو مضافة سابقاً). يُرجع true عند النجاح.
  static Future<bool> addBlock(
    String name, {
    List<String> areas = const [],
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (all.any((b) => b.name == trimmed)) return false; // اسم مكرر
    final nextNumber = all.isEmpty
        ? 1
        : all.map((b) => b.number).reduce((a, b) => a > b ? a : b) + 1;
    final cleanAreas =
        areas.map((a) => a.trim()).where((a) => a.isNotEmpty).toSet().toList();
    _customBlocks.add(
      AleppoBlock(number: nextNumber, name: trimmed, areas: cleanAreas),
    );
    await _persist();
    return true;
  }

  /// ✅ جديد — إعادة تسمية كتلة أضافها المسؤول سابقاً فقط (لا تعمل مع
  /// الكتل الرسمية الخمس — تحقق من [isCustomBlock] أولاً من الواجهة
  /// المستدعية). يرفض الاسم الفارغ أو المكرر مع كتلة أخرى.
  static Future<bool> renameCustomBlock(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed != oldName && all.any((b) => b.name == trimmed)) return false;
    final idx = _customBlocks.indexWhere((b) => b.name == oldName);
    if (idx == -1) return false;
    final old = _customBlocks[idx];
    _customBlocks[idx] =
        AleppoBlock(number: old.number, name: trimmed, areas: old.areas);
    await _persist();
    return true;
  }

  /// ✅ جديد — حذف كتلة أضافها المسؤول سابقاً نهائياً (لا تعمل مع الكتل
  /// الرسمية الخمس).
  static Future<bool> deleteCustomBlock(String name) async {
    final idx = _customBlocks.indexWhere((b) => b.name == name);
    if (idx == -1) return false;
    _customBlocks.removeAt(idx);
    await _persist();
    return true;
  }

  static Future<bool> deleteBlock(String name) async {
    if (isCustomBlock(name)) {
      return deleteCustomBlock(name);
    }
    if (isOfficialBlock(name)) {
      _deletedOfficialBlockNames.add(name);
      await _persistDeletedOfficial();
      return true;
    }
    return false;
  }

  /// ✅ جديد — إضافة حي جديد إلى كتلة أضافها المسؤول سابقاً (لا تعمل مع
  /// الكتل الرسمية؛ أحياء تلك تبقى ثابتة كما هي في هذا الملف).
  static Future<bool> addAreaToCustomBlock(
    String blockName,
    String area,
  ) async {
    final trimmed = area.trim();
    if (trimmed.isEmpty) return false;
    final idx = _customBlocks.indexWhere((b) => b.name == blockName);
    if (idx == -1) return false;
    final old = _customBlocks[idx];
    if (old.areas.contains(trimmed)) return false;
    _customBlocks[idx] = AleppoBlock(
      number: old.number,
      name: old.name,
      areas: [...old.areas, trimmed],
    );
    await _persist();
    return true;
  }

  /// اسم الكتلة بمعرفة رقمها — يُرجع نصاً فارغاً إن كان الرقم خارج المدى
  static String nameOf(int number) {
    final match = all.where((b) => b.number == number);
    return match.isEmpty ? '' : match.first.name;
  }

  /// أحياء كتلة معيّنة بمعرفة اسمها الكامل ("الكتلة الأولى")
  static List<String> areasOfBlock(String blockName) {
    final match = all.where((b) => b.name == blockName);
    return match.isEmpty ? const [] : match.first.areas;
  }

  /// قائمة أسماء الكتل فقط (رسمية + مضافة) — لاستخدامها في القوائم المنسدلة
  /// وصفوف الفلترة في كل شاشات التطبيق.
  static List<String> get blockNames => all.map((b) => b.name).toList();

  /// ✅ يحدد أي كتلة ينتمي إليها اسم منطقة معيّن. يحاول أولاً مطابقة تامة،
  /// ثم مطابقة جزئية (لدعم أسماء مختصرة قديمة).
  static AleppoBlock? blockOfArea(String area) {
    final trimmed = area.trim();
    if (trimmed.isEmpty) return null;
    for (final block in all) {
      if (block.areas.contains(trimmed)) return block;
    }
    for (final block in all) {
      for (final a in block.areas) {
        if (a.startsWith(trimmed) || trimmed.startsWith(a)) return block;
      }
    }
    return null;
  }

  /// نص العرض الكامل: "الكتلة الأولى — المنطقة"
  static String displayLabel({required String block, required String area}) {
    if (block.isEmpty) return area;
    if (area.isEmpty) return block;
    return '$block — $area';
  }
}
