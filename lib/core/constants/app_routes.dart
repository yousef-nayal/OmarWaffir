class AppRoutes {
  // Auth
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String adminLogin = '/admin-login';
  static const String forgotPassword = '/forgot-password';
  static const String otpVerification = '/otp-verification';
  static const String resetPassword = '/reset-password';

  // User
  static const String userHome = '/home';
  static const String products = '/products';
  static const String productDetail = '/product-detail';
  static const String stores = '/stores';
  static const String profile = '/profile';
  static const String userSettings = '/settings';
  static const String addPrice = '/add-price';
  static const String officialPrices = '/official-prices';
  // ✅ جديد — سجل تغييرات مادة واحدة من الأسعار الرسمية
  static const String officialPriceHistory = '/official-price-history';
  // ✅ جديد — اقتراح متجر جديد من شاشة "المتاجر"
  static const String addStore = '/add-store';

  // Legal
  static const String privacyPolicy = '/privacy-policy';
  static const String termsOfService = '/terms';

  // Admin
  static const String adminDashboard = '/admin/dashboard';
  static const String adminPriceReview = '/admin/price-review';
  static const String adminReports = '/admin/reports';
  static const String adminUsers = '/admin/users';
  static const String adminProducts = '/admin/products';
  static const String adminStores = '/admin/stores';
  static const String adminLocations = '/admin/locations';
  static const String adminUnits = '/admin/units';
  static const String adminBrands = '/admin/brands';
  static const String adminOfficialPrices = '/admin/official-prices';
  static const String adminAnalytics = '/admin/analytics';
  static const String adminSettings = '/admin/settings';
}

class AppConstants {
  static const String appName = 'وفّر';
  static const String appTagline = 'اعرف السعر الحقيقي';
  static const String currency = 'ل.س';
}