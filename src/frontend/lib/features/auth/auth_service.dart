import '../../core/api_client.dart';
import 'tutor.dart';

/// Llamadas a /auth/*. No guarda estado: de eso se encarga AuthController.
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<String> login(String nombre, String correo) async {
    try {
      final data = await _api.post(
        '/auth/login',
        body: {'nombre': nombre, 'correo': correo},
      );
      return _tokenOrThrow(data);
    } on ApiException catch (e) {
      if (e.statusCode == 422) {
        throw ApiException(
          'Revisa que el nombre y el correo sean válidos.',
          statusCode: 422,
        );
      }
      if (const {400, 401, 403, 404}.contains(e.statusCode)) {
        throw ApiException(
          'No encontramos una cuenta con ese nombre y correo. '
          'Revisa los datos o crea una cuenta.',
          statusCode: e.statusCode,
        );
      }
      rethrow;
    }
  }

  Future<String> register(String nombre, String correo) async {
    try {
      final data = await _api.post(
        '/auth/register',
        body: {'nombre': nombre, 'correo': correo},
      );
      final token = _extractToken(data);
      // Si el registro no devuelve token, iniciamos sesión enseguida.
      return token ?? await login(nombre, correo);
    } on ApiException catch (e) {
      if (e.statusCode == 422) {
        throw ApiException(
          'Revisa que el nombre y el correo sean válidos.',
          statusCode: 422,
        );
      }
      if (e.statusCode == 409) {
        throw ApiException(
          'Ese correo ya está registrado. Prueba con «Entrar».',
          statusCode: e.statusCode,
        );
      }
      rethrow;
    }
  }

  /// Tutor de la sesión actual (requiere que ApiClient.token esté puesto).
  Future<Tutor> me() async {
    final data = await _api.get('/auth/me');
    if (data is Map<String, dynamic>) return Tutor.fromJson(data);
    throw ApiException('Respuesta inesperada del servidor.');
  }

  String _tokenOrThrow(dynamic data) {
    final token = _extractToken(data);
    if (token == null) {
      throw ApiException('Respuesta inesperada del servidor.');
    }
    return token;
  }

  String? _extractToken(dynamic data) {
    if (data is Map) {
      for (final key in const ['access_token', 'token', 'accessToken', 'jwt']) {
        final value = data[key];
        if (value is String && value.isNotEmpty) return value;
      }
    }
    return null;
  }
}
