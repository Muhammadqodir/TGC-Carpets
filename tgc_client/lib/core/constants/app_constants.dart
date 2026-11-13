class AppConstants {
  AppConstants._();

  static const String appName = 'TGC Carpets';
  /// The server, production unless a local run passes
  /// `--dart-define=TGC_API_ORIGIN=http://127.0.0.1:8010`. Release builds
  /// pass nothing, so they always talk to production.
  static const String apiOrigin = String.fromEnvironment(
    'TGC_API_ORIGIN',
    defaultValue: 'https://erp.tgc-carpets.uz',
  );

  static const String baseUrl = '$apiOrigin/api/v1';
  static const String storageUrl = '$apiOrigin/storage/';

  /// Base URL for public (non-versioned) API endpoints such as app-update checks.
  static const String publicApiUrl = '$apiOrigin/api';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';

  /// Minimum width at which the app switches to a desktop layout.
  static const double desktopBreakpoint = 800.0;
}
