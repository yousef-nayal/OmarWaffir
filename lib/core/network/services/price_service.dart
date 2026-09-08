import '../../../models/models.dart';
import '../api_client.dart';
import '../api_response.dart';

/// خدمة الأسعار المُقدَّمة من المستخدمين — راجع API_DOCUMENTATION.md → "الأسعار"
class PriceService {
  final ApiClient _api;
  PriceService({ApiClient? api}) : _api = api ?? ApiClient();

  /// GET /prices?status=&page=&per_page= — (مراجعة الإدارة)
  Future<ApiResponse<List<PriceEntry>>> getPrices({
    String? status,
    int page = 1,
    int perPage = 20,
  }) {
    return _api.get<ApiResponse<List<PriceEntry>>>(
      '/prices',
      queryParameters: {
        'page': page,
        'per_page': perPage,
      },
      fromJson: (json) => ApiResponse.fromJson(
        json as Map<String, dynamic>,
        (data) => (data as List).map((e) => PriceEntry.fromJson(e)).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ✅ إصلاح جوهري — كانت هذه الدالة تستقبل unit كنص حر (مثل 'كغ') وترسله
  // مباشرة، رغم أن عمود Price.unit_id في قاعدة البيانات الفعلي هو مفتاح
  // أجنبي إلزامي يشير لجدول Unit، لا نص حر. كما كان اسم الحقل المُرسَل
  // 'quantity' بينما العمود الفعلي في قاعدة البيانات اسمه amount.
  //
  // الآن تستقبل unitId (معرّف حقيقي مُختار من قائمة الوحدات الفعلية)
  // وbrandId (اختياري، نفس المنطق)، وترسل amount بدل quantity.
  // ══════════════════════════════════════════════════════════════════
  Future<PriceEntry> submitPrice({
    required String productId,
    required String storeId,
    required double price,
    required String unitId,
    required double amount,
    required String brandId,
  }) {
    return _api.post<PriceEntry>(
      '/prices',
      data: {
        'product_id': productId,
        'store_id': storeId,
        'price': price,
        'unit_id': unitId,
        'amount': amount,
        'brand_id': brandId,
      },
      fromJson: (json) =>
          PriceEntry.fromJson((json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  /// POST /prices/{id}/vote — تقييم إعجاب/عدم إعجاب لسعر
  Future<void> votePrice(String id, {required bool isUp}) {
    return _api.post<void>('/prices/$id/vote', data: {'is_up': isUp});
  }

  /// DELETE /prices/{id} — ✅ جديد — (استخدام إداري) حذف سعر نهائياً.
  /// حلّت محل reviewPrice (موافقة/رفض) السابقة: جدول Price في قاعدة
  /// البيانات الفعلية لا يحتوي عمود status إطلاقاً (راجع
  /// Waffir_Database.txt)، فلا وجود فعلي لحالة "قيد المراجعة/مقبول/مرفوض"
  /// يمكن حفظها. مخطط حالات الاستخدام يُدرج "حذف السعر" صراحة كالإجراء
  /// الوحيد المطلوب ضمن "مراجعة الأسعار" — فأصبح الحذف هو مسار المراجعة
  /// الإدارية الفعلي (حذف أي سعر خاطئ/مضلِّل يكتشفه المسؤول أثناء المراجعة).
  Future<void> deletePrice(String id) {
    return _api.delete<void>('/prices/$id');
  }
}
