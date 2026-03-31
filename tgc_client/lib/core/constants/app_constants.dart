class AppConstants {
  AppConstants._();

  static const String appName = 'TGC Carpets';
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';
  static const String storageUrl = 'http://127.0.0.1:8000/storage/';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}
