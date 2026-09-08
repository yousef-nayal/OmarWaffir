import '../../../models/models.dart';
import '../api_client.dart';

/// خدمة موحّدة لكل "بيانات المرجع" الإدارية البسيطة:
/// الأسعار الرسمية، الوحدات، العلامات التجارية، والمواقع/القطاعات.
/// كلها CRUD بسيط بنفس الشكل، لذا جُمعت في خدمة واحدة لتقليل التكرار.
/// راجع API_DOCUMENTATION.md → الأقسام المقابلة لكل واحدة.
class CatalogService {
  final ApiClient _api;
  CatalogService({ApiClient? api}) : _api = api ?? ApiClient();

  // ── الأسعار الرسمية ────────────────────────────────────────────────
  Future<List<OfficialPrice>> getOfficialPrices({String? search}) {
    return _api.get<List<OfficialPrice>>(
      '/official-prices',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search
      },
      fromJson: (json) {
        final list = (json as Map<String, dynamic>)['data'] as List? ?? [];
        return list.map((e) => OfficialPrice.fromJson(e)).toList();
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري — كانت هذه الدالة تستقبل اسم منتج ووحدة كنصوص حرة
  // (productName/unit) وترسلهما كما هما للخادم، رغم أن مخطط قاعدة
  // البيانات الفعلي لجدول OfficialPrice لا يحتوي أي عمود نصي لاسم المنتج
  // أو الوحدة إطلاقاً — فقط product_id وunit_id (مفتاحان أجنبيان). أي
  // نص يُرسَل بهذا الشكل لا يملك مكاناً حقيقياً ليُخزَّن فيه.
  //
  // الآن الدالة تستقبل product_id/unit_id حقيقيين (يُختاران من قائمة
  // منتجات/وحدات موجودة فعلاً في الشاشة)، وترسل amount بدل quantity
  // (تطابقاً مع اسم العمود الفعلي في قاعدة البيانات).
  // ══════════════════════════════════════════════════════════════════
  Future<OfficialPrice> createOfficialPrice({
    required String productId,
    required String unitId,
    required double amount,
    required double price,
  }) {
    return _api.post<OfficialPrice>(
      '/official-prices',
      data: {
        'product_id': productId,
        'unit_id': unitId,
        'amount': amount,
        'price': price,
      },
      fromJson: (json) => OfficialPrice.fromJson(
          (json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  /// DELETE /official-prices/{id} — ✅ جديد — مطابقةً لعنصر "حذف" ضمن
  /// الأفعال الموحّدة التي يُدرجها مخطط حالات الاستخدام لـ"إدارة الأسعار
  /// الرسمية".
  Future<void> deleteOfficialPrice(String id) {
    return _api.delete<void>('/official-prices/$id');
  }

  /// PUT /official-prices/{id} — ✅ جديد — تعديل سعر رسمي موجود (استخدام
  /// إداري)، مطابقةً لعنصر "تعديل" في نفس المخطط.
  Future<OfficialPrice> updateOfficialPrice(
    String id, {
    required String productId,
    required String unitId,
    required double amount,
    required double price,
  }) {
    return _api.put<OfficialPrice>(
      '/official-prices/$id',
      data: {
        'product_id': productId,
        'unit_id': unitId,
        'amount': amount,
        'price': price,
      },
      fromJson: (json) => OfficialPrice.fromJson(
          (json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  /// GET /official-prices/{id}/history — ✅ جديد
  /// سجل تغييرات السعر الرسمي لمادة معيّنة عبر الزمن، مرتباً حسب تاريخ
  /// التغيير. يُتوقَّع من الـ backend إرجاع مصفوفة بهذا الشكل:
  /// { "success": true, "data": [ { "id": "...", "price": 43000,
  ///   "changed_at": "2026-05-15T00:00:00Z" }, ... ] }
  Future<List<OfficialPriceHistoryEntry>> getOfficialPriceHistory(
      String officialPriceId) {
    return _api.get<List<OfficialPriceHistoryEntry>>(
      '/official-prices/$officialPriceId/history',
      fromJson: (json) {
        final list = (json as Map<String, dynamic>)['data'] as List? ?? [];
        return list.map((e) => OfficialPriceHistoryEntry.fromJson(e)).toList();
      },
    );
  }

  // ── الوحدات ────────────────────────────────────────────────────────
  Future<List<UnitModel>> getUnits() {
    return _api.get<List<UnitModel>>(
      '/units',
      fromJson: (json) {
        final list = (json as Map<String, dynamic>)['data'] as List? ?? [];
        return list.map((e) => UnitModel.fromJson(e)).toList();
      },
    );
  }

  Future<UnitModel> createUnit(String name) {
    return _api.post<UnitModel>(
      '/units',
      data: {'name': name},
      fromJson: (json) =>
          UnitModel.fromJson((json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  /// PUT /units/{id} — ✅ جديد — تعديل اسم وحدة موجودة (كانت هذه العملية
  /// معطَّلة سابقاً بنافذة "قيد التطوير" لعدم وجود endpoint موثّق؛ أصبح
  /// موثّقاً الآن مطابقةً لعنصر "تعديل" في مخطط حالات الاستخدام).
  Future<UnitModel> updateUnit(String id, String name) {
    return _api.put<UnitModel>(
      '/units/$id',
      data: {'name': name},
      fromJson: (json) =>
          UnitModel.fromJson((json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  Future<void> deleteUnit(String id) => _api.delete<void>('/units/$id');

  // ── العلامات التجارية ──────────────────────────────────────────────
  Future<List<BrandModel>> getBrands() {
    return _api.get<List<BrandModel>>(
      '/brands',
      fromJson: (json) {
        final list = (json as Map<String, dynamic>)['data'] as List? ?? [];
        return list.map((e) => BrandModel.fromJson(e)).toList();
      },
    );
  }

  Future<BrandModel> createBrand(String name) {
    return _api.post<BrandModel>(
      '/brands',
      data: {'name': name},
      fromJson: (json) =>
          BrandModel.fromJson((json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  /// PUT /brands/{id} — ✅ جديد — تعديل اسم علامة تجارية موجودة (نفس منطق
  /// updateUnit أعلاه).
  Future<BrandModel> updateBrand(String id, String name) {
    return _api.put<BrandModel>(
      '/brands/$id',
      data: {'name': name},
      fromJson: (json) =>
          BrandModel.fromJson((json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  Future<void> deleteBrand(String id) => _api.delete<void>('/brands/$id');

  // ── المواقع والقطاعات ──────────────────────────────────────────────
  Future<List<LocationModel>> getLocations({String? search}) {
    return _api.get<List<LocationModel>>(
      '/locations',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search
      },
      fromJson: (json) {
        final list = (json as Map<String, dynamic>)['data'] as List? ?? [];
        return list.map((e) => LocationModel.fromJson(e)).toList();
      },
    );
  }

  Future<LocationModel> createLocation({
    required String sectorId,
    required String district,
  }) {
    return _api.post<LocationModel>(
      '/locations',
      data: {'sector_id': sectorId, 'district': district},
      fromJson: (json) => LocationModel.fromJson(
          (json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  /// PUT /locations/{id} — ✅ جديد — تعديل موقع/حي موجود (استخدام إداري)،
  /// مطابقةً لعنصر "تعديل" في مخطط حالات الاستخدام لـ"إدارة المواقع والكتل".
  Future<LocationModel> updateLocation(
    String id, {
    required String sectorId,
    required String district,
  }) {
    return _api.put<LocationModel>(
      '/locations/$id',
      data: {'sector_id': sectorId, 'district': district},
      fromJson: (json) => LocationModel.fromJson(
          (json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  /// DELETE /locations/{id} — ✅ جديد — حذف موقع/حي، مطابقةً لعنصر "حذف"
  /// في نفس المخطط.
  Future<void> deleteLocation(String id) {
    return _api.delete<void>('/locations/$id');
  }

  Future<List<SectorModel>> getSectors() {
    return _api.get<List<SectorModel>>(
      '/sectors',
      fromJson: (json) {
        final list = (json as Map<String, dynamic>)['data'] as List? ?? [];
        return list.map((e) => SectorModel.fromJson(e)).toList();
      },
    );
  }

  Future<SectorModel> createSector({
    required String name,
    String description = '',
  }) {
    return _api.post<SectorModel>(
      '/sectors',
      data: {'name': name, 'description': description},
      fromJson: (json) =>
          SectorModel.fromJson((json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  Future<SectorModel> updateSector(
    String id, {
    required String name,
    String description = '',
  }) {
    return _api.put<SectorModel>(
      '/sectors/$id',
      data: {'name': name, 'description': description},
      fromJson: (json) =>
          SectorModel.fromJson((json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  Future<void> deleteSector(String id) => _api.delete<void>('/sectors/$id');

  // ── لوحة الإحصائيات الإدارية ───────────────────────────────────────
  /// GET /admin/dashboard-stats
  Future<Map<String, dynamic>> getDashboardStats() {
    return _api.get<Map<String, dynamic>>(
      '/admin/dashboard-stats',
      fromJson: (json) => (json as Map<String, dynamic>)['data'] ?? json,
    );
  }

  /// GET /admin/recent-activity
  Future<List<Map<String, dynamic>>> getRecentActivity() {
    return _api.get<List<Map<String, dynamic>>>(
      '/admin/recent-activity',
      fromJson: (json) {
        final list = (json as Map<String, dynamic>)['data'] as List? ?? [];
        return list.cast<Map<String, dynamic>>();
      },
    );
  }
}
