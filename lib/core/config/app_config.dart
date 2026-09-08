/// ══════════════════════════════════════════════════════════════════════════
/// إعدادات عامة للتطبيق — نقطة تحكم واحدة لمطوّر الـ backend
/// ══════════════════════════════════════════════════════════════════════════
///
/// عند الانتهاء من ربط الـ backend الحقيقي:
///   1) غيّر [useMockData] إلى false.
///   2) شغّل التطبيق مع الـ base URL الصحيح:
///        flutter run --dart-define=API_BASE_URL=https://your-api.com/v1
///   3) كل الشاشات ستتحول تلقائياً لقراءة البيانات من الـ API عبر
///      الـ Providers (ProductProvider, StoreProvider, ...) بدل MockData.
///
/// شكل كل endpoint وكل حقل JSON موثّق بالكامل في API_DOCUMENTATION.md
/// في جذر المشروع — هذا هو المرجع الذي يجب أن يتّبعه مطوّر الـ backend.
/// ══════════════════════════════════════════════════════════════════════════
class AppConfig {
  AppConfig._();

  /// true = التطبيق يعرض بيانات وهمية (MockData) لأغراض العرض والتصميم.
  /// false = التطبيق يقرأ وّيكتب من الـ backend الحقيقي عبر ApiClient.
  static const bool useMockData = true;

  /// حجم الصفحة الافتراضي لأي endpoint يدعم pagination
  static const int defaultPageSize = 20;
}
