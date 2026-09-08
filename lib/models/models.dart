class UserModel {
  final String id;
  final String name;
  final String phone;
  final String role;
  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — roleLevel يحفظ القيمة الرقمية الخام لعمود role (0/1/2) كما
  // وصلت من الخادم، بمعزل عن [role] النصي أعلاه الذي يُجمِّع كلاً من 1 و2
  // معاً تحت الاسم العام "admin" (لأغراض التحقق من صلاحية الدخول للوحة
  // الإدارة فقط — راجع التوضيح الكامل عند _parseRole أدناه). هذا الحقل هو
  // المصدر الوحيد للتمييز الفعلي بين "مسؤول" (1) و"مسؤول رئيسي" (2) في
  // واجهات العرض (مثال: نافذة "معلومات الحساب" في إعدادات لوحة الإدارة).
  // ══════════════════════════════════════════════════════════════════════
  final int roleLevel;
  final String location;
  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — المعرّف الحقيقي لصف الموقع (locations.id) الذي يشير إليه عمود
  // users.location_id في قاعدة البيانات. الحقل النصي [location] أعلاه يبقى
  // للعرض فقط ("الكتلة الخامسة - الفرقان")، بينما هذا المعرّف هو ما يُرسَل
  // ويُستقبَل فعلياً من الخادم. بدونه كان التطبيق يضطر لمطابقة الأحياء
  // بالاسم، وهي مطابقة هشّة تكسر عند أي اختلاف إملائي.
  // ══════════════════════════════════════════════════════════════════════
  final String? locationId;
  final int pricesCount;
  final int ratingsCount;
  final int reportsCount;
  final bool isActive;
  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — تاريخ إنشاء الحساب، يطابق عمود User.created_at الفعلي في
  // قاعدة البيانات. اختياري (nullable) لأن بعض مسارات البناء المحلية
  // (مثال: تسجيل دخول تجريبي قبل ضبط قيمة صريحة) قد لا تملك قيمة حقيقية؛
  // الشاشات التي تعرضه (AdminUsersScreen) تتعامل مع القيمة الفارغة بعرض
  // بديل واضح ('—') بدل أي خطأ.
  // ══════════════════════════════════════════════════════════════════════
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.role = 'user',
    this.roleLevel = 0,
    this.location = '',
    this.locationId,
    this.pricesCount = 0,
    this.ratingsCount = 0,
    this.reportsCount = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      phone: json['phone_number'] as String? ?? json['phone'] as String? ?? '',
      role: _parseRole(json['role']),
      roleLevel: _parseRoleLevel(json['role']),
      location: json['location'] as String? ?? '',
      locationId: json['location_id'] != null
          ? json['location_id'].toString()
          : null,
      pricesCount: json['prices_count'] as int? ?? 0,
      ratingsCount: json['ratings_count'] as int? ?? 0,
      reportsCount: json['reports_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري وحاسم — بعد فحص ملف Waffir_Database.txt الفعلي، العمود
  // role معرَّف كـ:
  //   role TINYINT NOT NULL DEFAULT 0
  //   CHECK (role IN (0, 1, 2))
  // كون القيمة الافتراضية للعمود هي 0، من غير المعقول تصميمياً أن تكون
  // القيمة الافتراضية لأي مستخدم جديد يسجّل هي "مدير عام" (كما كان مُفترَضاً
  // سابقاً في هذا الملف) — هذا كان يعني عملياً أن كل تسجيل حساب جديد عبر
  // register() سيُمنح صلاحية دخول لوحة الإدارة تلقائياً، وهي ثغرة أمنية
  // خطيرة. كما تؤكد بيانات العيّنة المُدرَجة في نفس الملف هذا الاستنتاج:
  // 4 من أصل 5 مستخدمين تجريبيين (بأسماء عادية لا تشي بصلاحية إدارية) لهم
  // role = 0، بينما مستخدم واحد فقط role = 1.
  //
  // الترميز المعتمد الآن (بانتظار تأكيد نهائي وصريح من مطوّر الـ backend،
  // فالعمود بلا أي تعليق توضيحي في السكربت الأصلي):
  //   0 = مستخدم عادي (user)        → القيمة الافتراضية لأي تسجيل جديد
  //   1 = مدير (admin)              → يُعامَل كـ"admin" داخل التطبيق
  //   2 = مستوى إداري إضافي محجوز   → يُعامَل أيضاً كـ"admin" احتياطاً
  //       (مثال: مدير عام/صلاحية أعلى) لحين توضيح الفارق الدقيق بين 1 و2
  //       من مطوّر الـ backend؛ التطبيق لا يميّز حالياً بين مستويين
  //       إداريين مختلفين في الواجهة.
  // ══════════════════════════════════════════════════════════════════════
  static String _parseRole(dynamic raw) {
    if (raw == null) return 'user';
    if (raw is int) return raw == 0 ? 'user' : 'admin';
    if (raw is String) {
      final asInt = int.tryParse(raw);
      if (asInt != null) return asInt == 0 ? 'user' : 'admin';
      return raw; // نص جاهز مثل 'admin' أو 'user'
    }
    return 'user';
  }

  /// ✅ جديد — يقرأ القيمة الرقمية الخام (0/1/2) لعمود role كما هي، بلا أي
  /// تجميع بين المستويين الإداريين كما يفعل [_parseRole] أعلاه. يُستخدَم
  /// حصراً لعرض التمييز الدقيق بين "مسؤول" و"مسؤول رئيسي" في الواجهة.
  static int _parseRoleLevel(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is String) {
      final asInt = int.tryParse(raw);
      if (asInt != null) return asInt;
      // نص جاهز مثل 'admin' — لا يحمل تمييزاً بين 1 و2، فيُعامَل كمستوى
      // إداري أساسي (1) احتياطاً بدل فقدان صلاحية الإدارة بالكامل.
      return raw == 'admin' ? 1 : 0;
    }
    return 0;
  }

  /// ✅ جديد — يحوّل دور نصي داخلي ('admin'/'user') إلى القيمة الرقمية
  /// المطابقة لعمود role في قاعدة البيانات، للاستخدام عند الإرسال للخادم
  /// (مثال: ترقية/تخفيض مستخدم من لوحة الإدارة). 'admin' تُرسَل كـ 1
  /// افتراضياً (المستوى الإداري الأساسي، وليس 2 المحجوز لمستوى أعلى).
  static int roleToInt(String role) => role == 'admin' ? 1 : 0;

  /// ✅ جديد — نص عرض الصلاحية الإدارية الدقيق للواجهة، مبني على roleLevel
  /// الخام مباشرة: 1 = "مسؤول"، 2 = "مسؤول رئيسي". أي قيمة أخرى (0 أو غير
  /// معروفة) تُعرض كـ"مستخدم عادي" تحسباً لاستخدام هذا الحقل خارج سياق
  /// لوحة الإدارة مستقبلاً.
  String get roleLevelLabel {
    switch (roleLevel) {
      case 2:
        return 'مسؤول رئيسي';
      case 1:
        return 'مسؤول';
      default:
        return 'مستخدم عادي';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone_number': phone,
        'role': role,
        'location': location,
        if (locationId != null) 'location_id': locationId,
        'prices_count': pricesCount,
        'ratings_count': ratingsCount,
        'reports_count': reportsCount,
        'is_active': isActive,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? role,
    int? roleLevel,
    String? location,
    String? locationId,
    int? pricesCount,
    int? ratingsCount,
    int? reportsCount,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      roleLevel: roleLevel ?? this.roleLevel,
      location: location ?? this.location,
      locationId: locationId ?? this.locationId,
      pricesCount: pricesCount ?? this.pricesCount,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      reportsCount: reportsCount ?? this.reportsCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ProductModel {
  final String id;
  final String name;
  final String category;
  final double officialPrice;
  final double realPrice;
  final double avgPrice;
  final String unit;
  /// ✅ جديد — معرّف الوحدة وكميتها كما يحسبهما الخادم من السعر الرسمي
  /// الحالي، ليتمكن نموذج "إضافة سعر" من اختيار نفس الوحدة تلقائياً.
  final String? unitId;
  final double amount;
  final int pricesCount;
  final double changePercent;
  final bool isPriceUp;

  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.officialPrice,
    required this.realPrice,
    required this.avgPrice,
    required this.unit,
    this.unitId,
    this.amount = 1,
    required this.pricesCount,
    required this.changePercent,
    required this.isPriceUp,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      officialPrice: _toDouble(json['official_price']),
      realPrice: _toDouble(json['real_price']),
      avgPrice: _toDouble(json['avg_price']),
      unit: json['unit'] as String? ?? 'كغ',
      unitId: json['unit_id'] != null ? json['unit_id'].toString() : null,
      amount: json['amount'] != null ? _toDouble(json['amount']) : 1,
      pricesCount: json['prices_count'] as int? ?? 0,
      changePercent: _toDouble(json['change_percent']),
      isPriceUp: json['is_price_up'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'official_price': officialPrice,
        'real_price': realPrice,
        'avg_price': avgPrice,
        'unit': unit,
        if (unitId != null) 'unit_id': unitId,
        'amount': amount,
        'prices_count': pricesCount,
        'change_percent': changePercent,
        'is_price_up': isPriceUp,
      };
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class StoreModel {
  final String id;
  final String name;
  final String address;
  // ══════════════════════════════════════════════════════════════════════
  // ✅ جديد — المعرّفان الحقيقيان اللذان يربطان المتجر بموقعه في قاعدة
  // البيانات: stores.location_id (إلزامي) وlocations.sector_id المشتق منه.
  // كان الموديل سابقاً يحتفظ بالاسمين النصيين فقط (area/sector)، فيفقد
  // المعرّف فور القراءة ولا يستطيع أي شاشة تعديل المتجر أو فلترته بالمعرّف.
  // ══════════════════════════════════════════════════════════════════════
  final String? locationId;
  final String? sectorId;
  /// اسم الحي — الحقل الرسمي في الخادم اسمه district، وarea اسم عرض فقط.
  final String area;
  final String sector;
  final bool isVerified;
  final int pricesCount;

  StoreModel({
    required this.id,
    required this.name,
    required this.address,
    this.locationId,
    this.sectorId,
    required this.area,
    required this.sector,
    this.isVerified = false,
    this.pricesCount = 0,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      locationId: json['location_id'] != null
          ? json['location_id'].toString()
          : null,
      sectorId: json['sector_id'] != null
          ? json['sector_id'].toString()
          : (json['sector'] is Map
              ? (json['sector']['id'] ?? '').toString()
              : null),
      area: json['district'] as String? ?? json['area'] as String? ?? json['district'] as String? ?? '',
      sector: json['sector'] is Map
          ? json['sector']['name'] as String? ?? ''
          : json['sector'] as String? ?? '',
      isVerified: json['is_verified'] as bool? ?? false,
      pricesCount: json['prices_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        if (locationId != null) 'location_id': locationId,
        if (sectorId != null) 'sector_id': sectorId,
        'district': area,
        'area': area,
        'sector': sector,
        'is_verified': isVerified,
        'prices_count': pricesCount,
      };

  StoreModel copyWith({
    String? id,
    String? name,
    String? address,
    String? locationId,
    String? sectorId,
    String? area,
    String? sector,
    bool? isVerified,
    int? pricesCount,
  }) {
    return StoreModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      locationId: locationId ?? this.locationId,
      sectorId: sectorId ?? this.sectorId,
      area: area ?? this.area,
      sector: sector ?? this.sector,
      isVerified: isVerified ?? this.isVerified,
      pricesCount: pricesCount ?? this.pricesCount,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ✅ PriceEntry — أُضيف unitId/brandId (معرّفان حقيقيان اختياريان يطابقان
// unit_id/brand_id في مخطط قاعدة البيانات الفعلي). الحقلان unit/brand
// النصيان بقيا كما هما تماماً لعرض الاسم مباشرة في الواجهة (denormalized)،
// بلا أي تغيير في شكل أي بطاقة سعر. الفرق الوحيد: عند القراءة من الخادم،
// إن أرسل unit_id/brand_id يُحفظان هنا أيضاً لاستخدامهما لاحقاً (مثلاً عند
// تعديل سعر موجود مستقبلاً)، وعند الإرسال الفعلي للسعر الجديد
// (PriceService.submitPrice) تُستخدم هذه المعرّفات الحقيقية بدل النصوص.
// ══════════════════════════════════════════════════════════════════════════════
class PriceEntry {
  final String id;
  final String productId;
  final String productName;
  final String storeId;
  final String storeName;
  final String storeArea;
  final double price;
  final String unit;
  final String? unitId;
  final double quantity;
  final String brand;
  final String? brandId;
  final String submittedBy;
  final DateTime submittedAt;
  final int thumbsUp;
  final int thumbsDown;
  final int totalRatings;
  final String status;

  PriceEntry({
    required this.id,
    this.productId = '',
    required this.productName,
    this.storeId = '',
    required this.storeName,
    required this.storeArea,
    required this.price,
    required this.unit,
    this.unitId,
    required this.quantity,
    this.brand = '',
    this.brandId,
    required this.submittedBy,
    required this.submittedAt,
    this.thumbsUp = 0,
    this.thumbsDown = 0,
    this.totalRatings = 0,
    this.status = 'pending',
  });

  factory PriceEntry.fromJson(Map<String, dynamic> json) {
    return PriceEntry(
      id: (json['id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      productName: json['product_name'] as String? ?? '',
      storeId: (json['store_id'] ?? '').toString(),
      storeName: json['store_name'] as String? ?? '',
      storeArea: json['store_area'] as String? ?? '',
      price: _toDouble(json['price']),
      unit: json['unit'] as String? ?? '',
      unitId: json['unit_id'] != null ? json['unit_id'].toString() : null,
      // ✅ إصلاح تسمية — عمود قاعدة البيانات الفعلي اسمه amount وليس
      // quantity. نقرأ amount أولاً، ونتراجع إلى quantity فقط توافقاً مع
      // بيانات العرض التجريبي (MockData) التي بقيت بالاسم القديم.
      quantity: _toDouble(json['amount'] ?? json['quantity']),
      brand: json['brand'] as String? ?? '',
      brandId: json['brand_id'] != null ? json['brand_id'].toString() : null,
      submittedBy: json['submitted_by'] as String? ?? '',
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : DateTime.now(),
      thumbsUp: json['thumbs_up'] as int? ?? 0,
      thumbsDown: json['thumbs_down'] as int? ?? 0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
    );
  }

  /// ✅ محدَّث — يرسل amount (لا quantity) وunit_id/brand_id الحقيقيين إن
  /// وُجدا، بدل unit/brand النصيين. ملاحظة: هذا الـtoJson غير مستخدَم حالياً
  /// في مسار إرسال سعر جديد (PriceService.submitPrice يبني حمولته يدوياً)،
  /// لكنه أُصلح لتفادي أي استخدام مستقبلي خاطئ له.
  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'store_id': storeId,
        'price': price,
        'amount': quantity,
        if (unitId != null && unitId!.isNotEmpty) 'unit_id': unitId,
        if (brandId != null && brandId!.isNotEmpty) 'brand_id': brandId,
      };

  PriceEntry copyWith({
    int? thumbsUp,
    int? thumbsDown,
    int? totalRatings,
    String? status,
  }) {
    return PriceEntry(
      id: id,
      productId: productId,
      productName: productName,
      storeId: storeId,
      storeName: storeName,
      storeArea: storeArea,
      price: price,
      unit: unit,
      unitId: unitId,
      quantity: quantity,
      brand: brand,
      brandId: brandId,
      submittedBy: submittedBy,
      submittedAt: submittedAt,
      thumbsUp: thumbsUp ?? this.thumbsUp,
      thumbsDown: thumbsDown ?? this.thumbsDown,
      totalRatings: totalRatings ?? this.totalRatings,
      status: status ?? this.status,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ✅ إضافة fromJson لكل الـ models التالية (كانت ناقصة)
// ══════════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════
// ✅ جديد — القيم الثلاث الحصرية المسموحة لعمود Report.type في قاعدة
// البيانات الفعلية (راجع Waffir_Database.txt):
//   CHECK (type IN ('سعر مبالغ فيه', 'سعر غير صحيح', 'معلومات غير صحيحة'))
// سابقاً كان التطبيق يستخدم 4 مفاتيح إنجليزية داخلية (wrong_price/outdated/
// duplicate/other) لا تطابق هذا القيد إطلاقاً — أي بلاغ كان سيُرفَض فوراً
// من الخادم الحقيقي. الآن القيم النصية العربية الفعلية هي المصدر الوحيد
// للحقيقة وتُستخدَم مباشرة كمعرّفات (لا حاجة لترجمة/تعيين إضافي).
//
// كما ينص القيد الثاني في نفس الجدول:
//   CHECK (type = 'معلومات غير صحيحة' OR description IS NULL)
// أي أن حقل description مسموح فقط عندما type = 'معلومات غير صحيحة'؛ لأي
// نوع آخر يجب أن يبقى description فارغاً (null) تماماً.
// ══════════════════════════════════════════════════════════════════════════
class ReportType {
  ReportType._();
  static const String overpriced = 'سعر مبالغ فيه';
  static const String wrongPrice = 'سعر غير صحيح';
  static const String wrongInfo = 'معلومات غير صحيحة';

  static const List<String> all = [overpriced, wrongPrice, wrongInfo];

  /// ✅ description مسموح فقط مع هذا النوع تحديداً (مطابقةً للـ CHECK الفعلي)
  static bool allowsDescription(String type) => type == wrongInfo;
}

class ReportModel {
  final String id;
  final String productName;
  final String storeName;
  // ✅ جديد — حي المتجر المرتبط بالبلاغ. أُضيف خصيصاً ليتيح لشاشة "إدارة
  // البلاغات" في لوحة الإدارة الفلترة حسب الكتلة الإدارية عبر
  // AleppoBlocks.blockOfArea(r.storeArea)، بنفس الطريقة المستخدمة أصلاً في
  // PriceEntry.storeArea. اختياري تماماً: أي بلاغ قديم من الخادم بلا هذا
  // الحقل يبقى يعمل بشكل طبيعي (يظهر فقط ضمن "الكل" ولا يظهر تحت أي كتلة).
  final String storeArea;
  final String userName;
  final String type;
  // ✅ جديد — يطابق عمود description الفعلي في جدول Report (كان الفرونت
  // يرسل هذا النص سابقاً تحت مفتاح 'note' الخاطئ ولا يقرأه إطلاقاً عند
  // الاستقبال). غير مستخدَم حالياً في أي واجهة عرض — إضافته هنا فقط لضمان
  // عدم فقدانه صامتاً عند القراءة من الخادم مستقبلاً، بلا أي تغيير مرئي.
  final String? description;
  final DateTime reportedAt;
  final double? price;
  final String? unit;
  final double? quantity;

  ReportModel({
    required this.id,
    required this.productName,
    required this.storeName,
    this.storeArea = '',
    required this.userName,
    required this.type,
    this.description,
    required this.reportedAt,
    this.price,
    this.unit,
    this.quantity,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: (json['id'] ?? '').toString(),
      productName: json['product_name'] as String? ?? '',
      storeName: json['store_name'] as String? ?? '',
      storeArea: json['store_area'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
      type: json['type'] as String? ?? 'other',
      description: json['description'] as String?,
      reportedAt: json['reported_at'] != null
          ? DateTime.parse(json['reported_at'] as String)
          : DateTime.now(),
      price: json['price'] != null ? _toDouble(json['price']) : null,
      unit: json['unit'] as String?,
      quantity: json['amount'] != null || json['quantity'] != null
          ? _toDouble(json['amount'] ?? json['quantity'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_name': productName,
        'store_name': storeName,
        'store_area': storeArea,
        'user_name': userName,
        'type': type,
        if (description != null) 'description': description,
        'reported_at': reportedAt.toIso8601String(),
        if (price != null) 'price': price,
        if (unit != null) 'unit': unit,
        if (quantity != null) 'amount': quantity,
      };
}

// ══════════════════════════════════════════════════════════════════════════════
// ✅ OfficialPrice — أُضيف productId/unitId (معرّفان حقيقيان اختياريان
// يطابقان product_id/unit_id في مخطط قاعدة البيانات الفعلي). productName/
// unit النصيان بقيا كما هما تماماً لعرض الاسم مباشرة في كل شاشات العرض
// (لا تغيير مرئي إطلاقاً)، لكن أصبح بالإمكان الآن إرسال معرّفات حقيقية
// عند إضافة سعر رسمي جديد من لوحة الإدارة بدل نص اسم منتج حر غير مرتبط
// فعلياً بجدول Product.
// ══════════════════════════════════════════════════════════════════════════════
class OfficialPrice {
  final String id;
  final String? productId;
  final String productName;
  final String? unitId;
  final String unit;
  final double quantity;
  final double price;
  final DateTime updatedAt;

  OfficialPrice({
    required this.id,
    this.productId,
    required this.productName,
    this.unitId,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.updatedAt,
  });

  factory OfficialPrice.fromJson(Map<String, dynamic> json) {
    return OfficialPrice(
      id: (json['id'] ?? '').toString(),
      productId:
          json['product_id'] != null ? json['product_id'].toString() : null,
      productName: json['product_name'] as String? ?? '',
      unitId: json['unit_id'] != null ? json['unit_id'].toString() : null,
      unit: json['unit'] as String? ?? '',
      // ✅ إصلاح تسمية — عمود قاعدة البيانات الفعلي اسمه amount وليس
      // quantity، بنفس منطق PriceEntry أعلاه.
      quantity: _toDouble(json['amount'] ?? json['quantity']),
      price: _toDouble(json['price']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (productId != null) 'product_id': productId,
        if (unitId != null) 'unit_id': unitId,
        'product_name': productName,
        'unit': unit,
        'amount': quantity,
        'price': price,
        'created_at': updatedAt.toIso8601String(),
      };
}

// ══════════════════════════════════════════════════════════════════════════════
// ✅ جديد — سجل تغييرات السعر الرسمي عبر الزمن. تُستخدم في شاشة
// OfficialPriceHistoryScreen التي تُفتح عند النقر على أي مادة في شاشة
// "الأسعار الرسمية"، وتعرض متى تغيّر سعر هذه المادة وبأي قيمة في كل مرة.
// المصدر المتوقع من الـ backend: GET /official-prices/{id}/history
// ══════════════════════════════════════════════════════════════════════════════
class OfficialPriceHistoryEntry {
  final String id;
  final double price;
  final DateTime changedAt;

  OfficialPriceHistoryEntry({
    required this.id,
    required this.price,
    required this.changedAt,
  });

  factory OfficialPriceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return OfficialPriceHistoryEntry(
      id: (json['id'] ?? '').toString(),
      price: _toDouble(json['price']),
      changedAt: json['changed_at'] != null
          ? DateTime.parse(json['changed_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'price': price,
        'changed_at': changedAt.toIso8601String(),
      };
}

class UnitModel {
  final String id;
  final String name;
  final int usageCount;

  UnitModel({required this.id, required this.name, required this.usageCount});

  factory UnitModel.fromJson(Map<String, dynamic> json) {
    return UnitModel(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      usageCount: json['usage_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'usage_count': usageCount,
      };
}

class BrandModel {
  final String id;
  final String name;
  final int productsCount;

  BrandModel(
      {required this.id, required this.name, required this.productsCount});

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      productsCount: json['products_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'products_count': productsCount,
      };
}

class LocationModel {
  final String id;
  final String? sectorId;
  final String sector;
  final String area;
  final String landmark;
  final int storesCount;

  LocationModel({
    required this.id,
    this.sectorId,
    required this.sector,
    required this.area,
    required this.landmark,
    required this.storesCount,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: (json['id'] ?? '').toString(),
      sectorId: json['sector_id'] != null
          ? json['sector_id'].toString()
          : (json['sector'] is Map
              ? (json['sector']['id'] ?? '').toString()
              : null),
      sector: json['sector'] is Map
          ? json['sector']['name'] as String? ?? ''
          : json['sector'] as String? ?? '',
      area: json['area'] as String? ?? json['district'] as String? ?? '',
      landmark: json['landmark'] as String? ?? '',
      storesCount: json['stores_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (sectorId != null) 'sector_id': sectorId,
        'sector': sector,
        'area': area,
        'landmark': landmark,
        'stores_count': storesCount,
      };
}

class SectorModel {
  final String id;
  final String name;
  final String description;

  const SectorModel({
    required this.id,
    required this.name,
    this.description = '',
  });

  factory SectorModel.fromJson(Map<String, dynamic> json) => SectorModel(
        id: (json['id'] ?? '').toString(),
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );
}
