import '../../models/models.dart';

class MockData {
  static List<ProductModel> products = [
    ProductModel(
        id: '1',
        name: 'رز أبيض',
        category: 'حبوب',
        officialPrice: 12000,
        realPrice: 15500,
        avgPrice: 15200,
        unit: 'كغ',
        pricesCount: 4,
        changePercent: 29,
        isPriceUp: true),
    ProductModel(
        id: '2',
        name: 'سكر',
        category: 'سكريات',
        officialPrice: 8000,
        realPrice: 9200,
        avgPrice: 9100,
        unit: 'كغ',
        pricesCount: 6,
        changePercent: 15,
        isPriceUp: true),
    ProductModel(
        id: '3',
        name: 'زيت نباتي',
        category: 'زيوت',
        officialPrice: 25000,
        realPrice: 24000,
        avgPrice: 24500,
        unit: 'لتر',
        pricesCount: 5,
        changePercent: 4,
        isPriceUp: false),
    ProductModel(
        id: '4',
        name: 'زيت زيتون فلسطين',
        category: 'زيوت',
        officialPrice: 43000,
        realPrice: 45000,
        avgPrice: 44000,
        unit: 'لتر',
        pricesCount: 156,
        changePercent: 5,
        isPriceUp: true),
    ProductModel(
        id: '5',
        name: 'رز بسمتي',
        category: 'حبوب',
        officialPrice: 17000,
        realPrice: 17800,
        avgPrice: 17500,
        unit: 'كغ',
        pricesCount: 189,
        changePercent: 5,
        isPriceUp: true),
    ProductModel(
        id: '6',
        name: 'زيت ذرة',
        category: 'زيوت',
        officialPrice: 25000,
        realPrice: 26000,
        avgPrice: 25800,
        unit: 'لتر',
        pricesCount: 167,
        changePercent: 4,
        isPriceUp: true),
    ProductModel(
        id: '7',
        name: 'طحين',
        category: 'حبوب',
        officialPrice: 9000,
        realPrice: 9200,
        avgPrice: 9100,
        unit: 'كغ',
        pricesCount: 134,
        changePercent: 2,
        isPriceUp: true),
    ProductModel(
        id: '8',
        name: 'برغل',
        category: 'حبوب',
        officialPrice: 10000,
        realPrice: 10500,
        avgPrice: 10200,
        unit: 'كغ',
        pricesCount: 89,
        changePercent: 5,
        isPriceUp: true),
  ];

  // ══════════════════════════════════════════════════════════════════════
  // ✅ إصلاح شامل: حقل area لكل متجر أصبح اسم حي حقيقي من التقسيم الإداري
  // الرسمي لمحافظة حلب (الكتل الخمس، راجع aleppo_blocks.dart). أسماء وهمية
  // سابقة مثل "الشعار" أو "الميدان" لم تكن موجودة أصلاً ضمن أي كتلة رسمية
  // فاستُبدلت بأحياء حقيقية من نفس الكتلة تقريباً. حقل sector يبقى "حلب"
  // (كل التطبيق داخل محافظة حلب فقط)؛ الكتلة الإدارية تُشتق تلقائياً من
  // اسم الحي عبر AleppoBlocks.blockOfArea عند الحاجة لعرضها.
  // ══════════════════════════════════════════════════════════════════════
  static List<StoreModel> stores = [
    StoreModel(
        id: '1',
        name: 'محل الأمانة',
        address: 'شارع الفرقان الرئيسي',
        area: 'الفرقان', // الكتلة الخامسة
        sector: 'حلب',
        isVerified: true,
        pricesCount: 24),
    StoreModel(
        id: '2',
        name: 'سوبر ماركت النور',
        address: 'شارع الحمدانية الحي الأول',
        area: 'الحمدانية الحي الأول', // الكتلة الخامسة
        sector: 'حلب',
        isVerified: true,
        pricesCount: 18),
    StoreModel(
        id: '3',
        name: 'بقالية السلام',
        address: 'شارع الكواكبي',
        area: 'الكواكبي', // الكتلة الخامسة
        sector: 'حلب',
        isVerified: true,
        pricesCount: 12),
    StoreModel(
        id: '4',
        name: 'محل الخير',
        address: 'شارع اليرمون',
        area: 'اليرمون', // الكتلة الثانية
        sector: 'حلب',
        isVerified: false,
        pricesCount: 8),
    StoreModel(
        id: '5',
        name: 'بقالة الخير',
        address: 'شارع العزيزية',
        area: 'العزيزية', // الكتلة الثانية
        sector: 'حلب',
        isVerified: true,
        pricesCount: 46),
    StoreModel(
        id: '6',
        name: 'هايبر ماركت الشام',
        address: 'شارع السليمانية',
        area: 'السليمانية', // الكتلة الثانية
        sector: 'حلب',
        isVerified: true,
        pricesCount: 39),
    StoreModel(
        id: '7',
        name: 'مول الجلاء',
        address: 'شارع صلاح الدين',
        area: 'صلاح الدين', // الكتلة الرابعة
        sector: 'حلب',
        isVerified: false,
        pricesCount: 22),
  ];

  // ══════════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري: كل مدخلة سعر أصبحت مرتبطة فعلياً بـ productId الحقيقي
  // (كان هذا الحقل فارغاً '' في كل المدخلات سابقاً). هذا هو السبب المباشر
  // لعدم ظهور "الأسعار المسجلة" بشكل صحيح: PriceProvider.loadProductPrices
  // كان يتجاهل productId تماماً ويعيد نفس هذه القائمة الثابتة لأي منتج
  // (راجع الإصلاح المقابل في app_provider.dart)، وبما أن أياً من المدخلات
  // الأربع القديمة لم تكن مرتبطة بمنتج "رز أبيض" (id: '1') تحديداً، فبعد
  // إضافة الفلترة الصحيحة كانت ستظهر القائمة فارغة لهذا المنتج تحديداً.
  // أُضيفت مدخلتان جديدتان (id: '5' و '6') خاصتان بـ "رز أبيض" لضمان وجود
  // بيانات تجريبية واقعية لكل منتج يتم اختباره.
  // ══════════════════════════════════════════════════════════════════════
  static List<PriceEntry> priceEntries = [
    PriceEntry(
        id: '1',
        productId: '4', // زيت زيتون فلسطين
        productName: 'زيت زيتون فلسطين',
        storeId: '2',
        storeName: 'سوبر ماركت النور',
        storeArea: 'الحمدانية الحي الأول',
        price: 45000,
        unit: 'لتر',
        quantity: 1,
        brand: 'فلسطين',
        submittedBy: 'محمد أحمد',
        submittedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        thumbsUp: 12,
        thumbsDown: 2,
        totalRatings: 14,
        status: 'pending'),
    PriceEntry(
        id: '2',
        productId: '2', // سكر
        productName: 'سكر أبيض',
        storeId: '5',
        storeName: 'بقالة الخير',
        storeArea: 'العزيزية',
        price: 12000,
        unit: 'كيلوغرام',
        quantity: 1,
        brand: 'الريف',
        submittedBy: 'فاطمة علي',
        submittedAt: DateTime.now().subtract(const Duration(minutes: 12)),
        thumbsUp: 8,
        thumbsDown: 1,
        totalRatings: 9,
        status: 'approved'),
    PriceEntry(
        id: '3',
        productId: '5', // رز بسمتي
        productName: 'رز بسمتي',
        storeId: '6',
        storeName: 'هايبر ماركت الشام',
        storeArea: 'السليمانية',
        price: 18000,
        unit: 'كيلوغرام',
        quantity: 1,
        brand: 'النخيل',
        submittedBy: 'خالد محمود',
        submittedAt: DateTime.now().subtract(const Duration(hours: 1)),
        thumbsUp: 15,
        thumbsDown: 0,
        totalRatings: 15,
        status: 'approved'),
    PriceEntry(
        id: '4',
        productId: '6', // زيت ذرة
        productName: 'زيت ذرة',
        storeId: '7',
        storeName: 'مول الجلاء',
        storeArea: 'صلاح الدين',
        price: 52000,
        unit: 'لتر',
        quantity: 2,
        brand: 'النخيل',
        submittedBy: 'سارة حسن',
        submittedAt: DateTime.now().subtract(const Duration(hours: 2)),
        thumbsUp: 20,
        thumbsDown: 3,
        totalRatings: 23,
        status: 'pending'),
    // ✅ جديد — مدخلتان لمنتج "رز أبيض" (id: '1')، لم يكن له أي سعر مسجّل
    // سابقاً رغم ظهوره كمنتج رئيسي في الصفحة الرئيسية وشاشة المنتجات.
    PriceEntry(
        id: '5',
        productId: '1', // رز أبيض
        productName: 'رز أبيض',
        storeId: '1',
        storeName: 'محل الأمانة',
        storeArea: 'الفرقان',
        price: 16500,
        unit: 'كيلوغرام',
        quantity: 1,
        brand: 'الشام',
        submittedBy: 'أحمد يوسف',
        submittedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        thumbsUp: 10,
        thumbsDown: 1,
        totalRatings: 11,
        status: 'approved'),
    PriceEntry(
        id: '6',
        productId: '1', // رز أبيض
        productName: 'رز أبيض',
        storeId: '3',
        storeName: 'بقالية السلام',
        storeArea: 'الكواكبي',
        price: 15800,
        unit: 'كيلوغرام',
        quantity: 1,
        brand: 'الفرات',
        submittedBy: 'ليلى إبراهيم',
        submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
        thumbsUp: 6,
        thumbsDown: 0,
        totalRatings: 6,
        status: 'approved'),
  ];

  // ✅ location بصيغة "الكتلة X - الحي" لتطابق الصيغة الجديدة المعتمدة في
  // AppProvider (راجع _setUser وregister في app_provider.dart)
  static List<UserModel> users = [
    UserModel(
        id: '1',
        name: 'محمد أحمد',
        phone: '0944123456',
        role: 'user',
        location: 'الكتلة الخامسة - الفرقان',
        pricesCount: 45,
        ratingsCount: 56,
        reportsCount: 3,
        isActive: true,
        // ✅ جديد — تاريخ إنشاء الحساب (يطابق عمود User.created_at الفعلي)
        createdAt: DateTime(2026, 1, 12)),
    UserModel(
        id: '2',
        name: 'فاطمة علي',
        phone: '0955234567',
        role: 'user',
        location: 'الكتلة الثانية - العزيزية',
        pricesCount: 32,
        isActive: true,
        createdAt: DateTime(2026, 2, 3)),
    UserModel(
        id: '3',
        name: 'خالد محمود',
        phone: '0933345678',
        role: 'admin',
        // ✅ جديد — roleLevel = 1 ليطابق role: 'admin' نصياً (مستوى مسؤول
        // أساسي)، بدل تركه صفراً افتراضياً وهو ما كان يخلق تعارضاً صامتاً
        // بين role وroleLevel لنفس المستخدم.
        roleLevel: 1,
        location: 'الكتلة الثانية - الأشرفية',
        pricesCount: 0,
        isActive: true,
        createdAt: DateTime(2025, 11, 20)),
    UserModel(
        id: '4',
        name: 'سارة حسن',
        phone: '0922456789',
        role: 'user',
        location: 'الكتلة الثانية - اليرمون',
        pricesCount: 12,
        isActive: true,
        createdAt: DateTime(2026, 4, 8)),
  ];

  // ══════════════════════════════════════════════════════════════════════
  // ✅ أنواع البلاغات مطابقة للقيم الثلاث المسموحة في Report.type.
  // ✅ storeArea أُضيف لكل بلاغ (يطابق area المتجر المعني في المصفوفة أعلاه)
  // ليعمل فلتر الكتلة الإدارية الجديد في شاشة "إدارة البلاغات".
  // ══════════════════════════════════════════════════════════════════════
  static List<ReportModel> reports = [
    ReportModel(
        id: '1',
        productName: 'زيت زيتون فلسطين',
        storeName: 'سوبر ماركت النور',
        storeArea: 'الحمدانية الحي الأول', // الكتلة الخامسة
        userName: 'أحمد محمود',
        type: ReportType.overpriced,
        price: 45000,
        unit: 'لتر',
        quantity: 1,
        reportedAt: DateTime(2026, 5, 17, 14, 30)),
    ReportModel(
        id: '2',
        productName: 'سكر أبيض',
        storeName: 'بقالة الخير',
        storeArea: 'العزيزية', // الكتلة الثانية
        userName: 'فاطمة علي',
        type: ReportType.wrongPrice,
        price: 12000,
        unit: 'كيلوغرام',
        quantity: 1,
        reportedAt: DateTime(2026, 5, 17, 13, 15)),
    ReportModel(
        id: '3',
        productName: 'رز بسمتي',
        storeName: 'هايبر ماركت الشام',
        storeArea: 'السليمانية', // الكتلة الثانية
        userName: 'خالد حسن',
        type: ReportType.wrongInfo,
        description: 'يرجى التحقق من بيانات المنتج المسجّلة',
        price: 18000,
        unit: 'كيلوغرام',
        quantity: 1,
        reportedAt: DateTime(2026, 5, 17, 11, 45)),
    ReportModel(
        id: '4',
        productName: 'زيت ذرة',
        storeName: 'مول الجلاء',
        storeArea: 'صلاح الدين', // الكتلة الرابعة
        userName: 'سارة محمد',
        type: ReportType.overpriced,
        price: 52000,
        unit: 'لتر',
        quantity: 2,
        reportedAt: DateTime(2026, 5, 17, 10, 20)),
  ];

  static List<OfficialPrice> officialPrices = [
    OfficialPrice(
        id: '1',
        productName: 'زيت زيتون فلسطين',
        unit: 'لتر',
        quantity: 1,
        price: 43000,
        updatedAt: DateTime(2026, 5, 15)),
    OfficialPrice(
        id: '2',
        productName: 'سكر أبيض',
        unit: 'كيلوغرام',
        quantity: 1,
        price: 11200,
        updatedAt: DateTime(2026, 5, 14)),
    OfficialPrice(
        id: '3',
        productName: 'رز بسمتي',
        unit: 'كيلوغرام',
        quantity: 1,
        price: 17500,
        updatedAt: DateTime(2026, 5, 13)),
    OfficialPrice(
        id: '4',
        productName: 'زيت ذرة',
        unit: 'لتر',
        quantity: 1,
        price: 25800,
        updatedAt: DateTime(2026, 5, 12)),
    OfficialPrice(
        id: '5',
        productName: 'طحين',
        unit: 'كيلوغرام',
        quantity: 1,
        price: 9100,
        updatedAt: DateTime(2026, 5, 11)),
  ];

  static List<UnitModel> units = [
    UnitModel(id: '1', name: 'كيلوغرام', usageCount: 456),
    UnitModel(id: '2', name: 'لتر', usageCount: 389),
    UnitModel(id: '3', name: 'غرام', usageCount: 234),
    UnitModel(id: '4', name: 'قطعة', usageCount: 178),
    UnitModel(id: '5', name: 'علبة', usageCount: 145),
  ];

  static List<BrandModel> brands = [
    BrandModel(id: '1', name: 'فلسطين', productsCount: 45),
    BrandModel(id: '2', name: 'الغوطة', productsCount: 38),
    BrandModel(id: '3', name: 'الريف', productsCount: 32),
    BrandModel(id: '4', name: 'النخيل', productsCount: 28),
    BrandModel(id: '5', name: 'الشام', productsCount: 24),
    BrandModel(id: '6', name: 'الفرات', productsCount: 19),
  ];

  // ✅ sector أصبح اسم الكتلة الإدارية الرسمية (بدل "حلب" العام)، وarea/
  // landmark أحياء حقيقية من نفس الكتلة — يطابق تماماً بيانات aleppo_blocks.dart
  static List<LocationModel> locations = [
    LocationModel(
        id: '1',
        sector: 'الكتلة الخامسة',
        area: 'الفرقان',
        landmark: 'شارع الفرقان الرئيسي',
        storesCount: 45),
    LocationModel(
        id: '2',
        sector: 'الكتلة الخامسة',
        area: 'الحمدانية الحي الأول',
        landmark: 'شارع الحمدانية',
        storesCount: 32),
    LocationModel(
        id: '3',
        sector: 'الكتلة الثانية',
        area: 'السليمانية',
        landmark: 'شارع السليمانية',
        storesCount: 28),
    LocationModel(
        id: '4',
        sector: 'الكتلة الرابعة',
        area: 'صلاح الدين',
        landmark: 'شارع صلاح الدين',
        storesCount: 41),
    LocationModel(
        id: '5',
        sector: 'الكتلة الثانية',
        area: 'العزيزية',
        landmark: 'شارع الملك فيصل',
        storesCount: 38),
  ];

  static Map<String, dynamic> dashboardStats = {
    'totalUsers': 1248,
    'totalProducts': 856,
    'totalStores': 324,
    'totalPrices': 4562,
    'totalReports': 89,
    'usersGrowth': 12,
    'productsGrowth': 8,
    'storesGrowth': 5,
    'pricesGrowth': 18,
  };

  // ══════════════════════════════════════════════════════════════════════
  // ✅ محدَّث — نص نشاط "سوبر ماركت النور" أصبح "تم إضافة متجر" بدل "طلب
  // تفعيل متجر" بطلب مباشر، ليعكس أن المتجر أُضيف فعلياً إلى النظام (وليس
  // فقط طلباً معلّقاً بانتظار المراجعة). بلا أي تغيير في باقي حقول هذه
  // المدخلة (النوع، الوقت، اللون) أو أي مدخلة أخرى في هذه القائمة.
  // ══════════════════════════════════════════════════════════════════════
  static List<Map<String, dynamic>> recentActivity = [
    {
      'type': 'price',
      'text': 'تم إضافة منتج جديد (زيت زيتون) و سعر رسمي له',
      'time': 'منذ 5 دقائق',
      'color': 'blue'
    },
    {
      'type': 'report',
      'text': 'بلاغ جديد عن سعر غير صحيح',
      'time': 'منذ 12 دقيقة',
      'color': 'red'
    },
    {
      'type': 'user',
      'text': 'تسجيل مستخدم جديد: أحمد محمود',
      'time': 'منذ 25 دقيقة',
      'color': 'green'
    },
    {
      'type': 'store',
      'text': 'تم إضافة متجر: سوبر ماركت النور',
      'time': 'منذ 1 ساعة',
      'color': 'purple'
    },
    {
      'type': 'official',
      'text': 'تم تحديث سعر رسمي للسكر',
      'time': 'منذ 2 ساعة',
      'color': 'blue'
    },
  ];
  // ✅ جديد — سجل تجريبي لتغييرات كل سعر رسمي، مفتاح كل مدخلة هو id المادة
  // في officialPrices أعلاه. مرتّب من الأحدث إلى الأقدم (يُعاد ترتيبه على أي
  // حال داخل الشاشة احتياطاً، لكن يُفضَّل أن يصل من الخادم مرتَّباً هكذا).
  static Map<String, List<OfficialPriceHistoryEntry>> officialPriceHistory = {
    '1': [
      OfficialPriceHistoryEntry(
          id: 'h1-1', price: 43000, changedAt: DateTime(2026, 5, 15)),
      OfficialPriceHistoryEntry(
          id: 'h1-2', price: 41500, changedAt: DateTime(2026, 4, 20)),
      OfficialPriceHistoryEntry(
          id: 'h1-3', price: 39800, changedAt: DateTime(2026, 3, 10)),
      OfficialPriceHistoryEntry(
          id: 'h1-4', price: 38000, changedAt: DateTime(2026, 1, 25)),
    ],
    '2': [
      OfficialPriceHistoryEntry(
          id: 'h2-1', price: 11200, changedAt: DateTime(2026, 5, 14)),
      OfficialPriceHistoryEntry(
          id: 'h2-2', price: 10800, changedAt: DateTime(2026, 4, 2)),
      OfficialPriceHistoryEntry(
          id: 'h2-3', price: 10800, changedAt: DateTime(2026, 2, 18)),
      OfficialPriceHistoryEntry(
          id: 'h2-4', price: 9900, changedAt: DateTime(2026, 1, 5)),
    ],
    '3': [
      OfficialPriceHistoryEntry(
          id: 'h3-1', price: 17500, changedAt: DateTime(2026, 5, 13)),
      OfficialPriceHistoryEntry(
          id: 'h3-2', price: 17000, changedAt: DateTime(2026, 3, 28)),
      OfficialPriceHistoryEntry(
          id: 'h3-3', price: 16200, changedAt: DateTime(2026, 2, 9)),
    ],
    '4': [
      OfficialPriceHistoryEntry(
          id: 'h4-1', price: 25800, changedAt: DateTime(2026, 5, 12)),
      OfficialPriceHistoryEntry(
          id: 'h4-2', price: 24500, changedAt: DateTime(2026, 3, 30)),
      OfficialPriceHistoryEntry(
          id: 'h4-3', price: 23900, changedAt: DateTime(2026, 2, 14)),
      OfficialPriceHistoryEntry(
          id: 'h4-4', price: 22000, changedAt: DateTime(2026, 1, 3)),
    ],
    '5': [
      OfficialPriceHistoryEntry(
          id: 'h5-1', price: 9100, changedAt: DateTime(2026, 5, 11)),
      OfficialPriceHistoryEntry(
          id: 'h5-2', price: 8700, changedAt: DateTime(2026, 3, 22)),
    ],
  };
}
