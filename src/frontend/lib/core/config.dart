class AppConfig {
  /// URL base de la API. Se puede cambiar al compilar con:
  /// flutter build apk --dart-define=API_BASE_URL=https://mi-dominio.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'http://english-for-kids-iha3bf-988335-144-24-4-187.sslip.io',
  );

  /// ID de cliente "Aplicación web" de Google Cloud (no es secreto). Con él, Google
  /// entrega a la app un token de identidad que el servidor puede verificar.
  /// Debe ser el mismo que GOOGLE_CLIENT_ID del servidor.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '566955966049-3jg8jd0omf7b90jk67mde5li4814hh2u.apps.googleusercontent.com',
  );

  /// Muestra también el acceso con nombre y correo (sin verificar). Solo para
  /// pruebas: compila con --dart-define=BASIC_LOGIN=true y activa
  /// ENABLE_BASIC_LOGIN=true en el servidor.
  static const bool basicLoginEnabled =
      bool.fromEnvironment('BASIC_LOGIN', defaultValue: false);

  static const Duration requestTimeout = Duration(seconds: 15);
}
