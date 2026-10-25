import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/session_storage.dart';
import 'auth_service.dart';
import 'tutor.dart';

enum AuthStatus { loading, signedOut, signedIn }

enum AuthMode { login, register }

class AuthController extends ChangeNotifier {
  AuthController({
    required ApiClient api,
    required AuthService service,
    required SessionStorage storage,
  })  : _api = api,
        _service = service,
        _storage = storage {
    _api.onUnauthorized = logout;
  }

  final ApiClient _api;
  final AuthService _service;
  final SessionStorage _storage;

  AuthStatus _status = AuthStatus.loading;
  Tutor? _tutor;
  bool _busy = false;
  String? _error;

  AuthStatus get status => _status;
  Tutor? get tutor => _tutor;
  bool get busy => _busy;
  String? get error => _error;

  /// Se llama al abrir la app: recupera la sesión guardada, si existe.
  Future<void> bootstrap() async {
    final saved = await _storage.read();
    if (saved == null) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    _api.token = saved.token;
    try {
      final tutor = await _service.me();
      await _storage.save(saved.token, tutor);
      _tutor = tutor;
      _status = AuthStatus.signedIn;
    } on ApiException catch (e) {
      if (const {401, 403, 404}.contains(e.statusCode)) {
        // La sesión ya no es válida.
        await _storage.clear();
        _api.token = null;
        _status = AuthStatus.signedOut;
      } else if (saved.tutor != null) {
        // Sin conexión: se mantiene la sesión con los datos guardados.
        _tutor = saved.tutor;
        _status = AuthStatus.signedIn;
      } else {
        _api.token = null;
        _status = AuthStatus.signedOut;
      }
    } catch (_) {
      _api.token = null;
      _status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  /// Inicia sesión o crea la cuenta. Devuelve true si funcionó.
  Future<bool> submit(
    AuthMode mode, {
    required String nombre,
    required String correo,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final token = mode == AuthMode.login
          ? await _service.login(nombre, correo)
          : await _service.register(nombre, correo);
      _api.token = token;

      Tutor tutor;
      try {
        tutor = await _service.me();
      } on ApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) rethrow;
        tutor = Tutor(nombre: nombre, correo: correo);
      }

      await _storage.save(token, tutor);
      _tutor = tutor;
      _status = AuthStatus.signedIn;
      _busy = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _api.token = null;
      _error = e.message;
    } catch (_) {
      _api.token = null;
      _error = 'Algo salió mal. Intenta de nuevo.';
    }
    _busy = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    if (_status == AuthStatus.signedOut && _tutor == null) return;
    _api.token = null;
    _tutor = null;
    _status = AuthStatus.signedOut;
    await _storage.clear();
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
