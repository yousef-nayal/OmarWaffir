import '../../../models/models.dart';
import '../api_client.dart';
import '../api_response.dart';

/// خدمة المنتجات — راجع API_DOCUMENTATION.md → قسم "المنتجات"
class ProductService {
  final ApiClient _api;
  ProductService({ApiClient? api}) : _api = api ?? ApiClient();

  /// GET /products?search=&category=&page=&per_page=
  Future<ApiResponse<List<ProductModel>>> getProducts({
    String? search,
    String? category,
    int page = 1,
    int perPage = 20,
  }) {
    return _api.get<ApiResponse<List<ProductModel>>>(
      '/products',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (category != null && category.isNotEmpty) 'category': category,
        'page': page,
        'per_page': perPage,
      },
      fromJson: (json) => ApiResponse.fromJson(
        json as Map<String, dynamic>,
        (data) => (data as List).map((e) => ProductModel.fromJson(e)).toList(),
      ),
    );
  }

  /// GET /products/{id}
  Future<ProductModel> getProductById(String id) {
    return _api.get<ProductModel>(
      '/products/$id',
      fromJson: (json) =>
          ProductModel.fromJson((json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  /// GET /products/{id}/prices — كل الأسعار المسجّلة لمنتج معيّن
  Future<List<PriceEntry>> getProductPrices(String id) {
    return _api.get<List<PriceEntry>>(
      '/products/$id/prices',
      fromJson: (json) {
        final data = json;
        final list = data is List
            ? data
            : (data as Map<String, dynamic>)['data'] as List? ?? [];
        return list.map((e) => PriceEntry.fromJson(e)).toList();
      },
    );
  }

  /// POST /products — (استخدام إداري) إضافة منتج جديد
  Future<ProductModel> createProduct({
    required String name,
    required String category,
  }) {
    return _api.post<ProductModel>(
      '/products',
      data: {'name': name, 'category': category},
      fromJson: (json) =>
          ProductModel.fromJson((json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  /// PUT /products/{id} — ✅ جديد — تعديل منتج موجود (استخدام إداري)،
  /// مطابقةً لعنصر "تعديل" الناقص سابقاً ضمن الأفعال الموحّدة في مخطط
  /// حالات الاستخدام لـ"إدارة المنتجات".
  Future<ProductModel> updateProduct(
    String id, {
    required String name,
    required String category,
  }) {
    return _api.put<ProductModel>(
      '/products/$id',
      data: {'name': name, 'category': category},
      fromJson: (json) =>
          ProductModel.fromJson((json as Map<String, dynamic>)['data'] ?? json),
    );
  }

  /// DELETE /products/{id} — (استخدام إداري)
  Future<void> deleteProduct(String id) {
    return _api.delete<void>('/products/$id');
  }
}
