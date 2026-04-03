class AppConstants {
  AppConstants._();

  static const String appName = 'TGC Carpets';
  static const String baseUrl = 'https://erp.tgc-carpets.uz/api/v1';
  static const String storageUrl = 'https://erp.tgc-carpets.uz/storage/';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}
