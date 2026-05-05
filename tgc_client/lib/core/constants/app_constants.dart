class AppConstants {
  AppConstants._();

  static const String appName = 'TGC Carpets';
  static const String baseUrl = 'https://erp.tgc-carpets.uz/api/v1';
  static const String storageUrl = 'https://erp.tgc-carpets.uz/storage/';

  /// Base URL for public (non-versioned) API endpoints such as app-update checks.
  static const String publicApiUrl = 'https://erp.tgc-carpets.uz/api';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';

  /// Minimum width at which the app switches to a desktop layout.
  static const double desktopBreakpoint = 800.0;
}
