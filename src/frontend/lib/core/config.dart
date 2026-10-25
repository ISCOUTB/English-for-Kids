class AppConfig {
  /// URL base de la API. Se puede cambiar al compilar con:
  /// flutter build apk --dart-define=API_BASE_URL=https://mi-dominio.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'http://english-for-kids-iha3bf-988335-144-24-4-187.sslip.io',
  );

  static const Duration requestTimeout = Duration(seconds: 15);
}
