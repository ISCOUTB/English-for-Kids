import 'dart:convert';

import 'package:english_for_kids/core/api_client.dart';
import 'package:english_for_kids/core/session_storage.dart';
import 'package:english_for_kids/features/auth/auth_controller.dart';
import 'package:english_for_kids/features/auth/auth_service.dart';
import 'package:english_for_kids/features/auth/google_account_picker.dart';
import 'package:english_for_kids/features/auth/tutor.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Selector de cuentas simulado.
class _FakePicker implements GoogleAccountPicker {
  String? token = 'id-token-de-google';
  Object? error;
  int signOuts = 0;

  @override
  Future<String?> pickIdToken() async {
    if (error != null) throw error!;
    return token;
  }

  @override
  Future<void> signOut() async => signOuts++;
}

/// Almacenamiento de sesión en memoria (sin el plugin del teléfono).
class _MemoryStorage extends SessionStorage {
  String? savedToken;
  Tutor? savedTutor;
  bool cleared = false;

  @override
  Future<void> save(String token, Tutor tutor) async {
    savedToken = token;
    savedTutor = tutor;
  }

  @override
  Future<void> clear() async {
    cleared = true;
    savedToken = null;
    savedTutor = null;
  }
}

/// Plugin de Google simulado: falla con el código que se le indique.
class _FailingGoogleSignIn extends GoogleSignIn {
  _FailingGoogleSignIn(this.code) : super();

  final String code;

  @override
  Future<GoogleSignInAccount?> signOut() async => null;

  @override
  Future<GoogleSignInAccount?> signIn() async =>
      throw PlatformException(code: code, message: 'prueba');
}

({AuthController auth, _FakePicker picker, _MemoryStorage storage, List<http.Request> requests})
    _build(Future<http.Response> Function(http.Request) handler) {
  final requests = <http.Request>[];
  final mock = MockClient((req) async {
    requests.add(req);
    return handler(req);
  });
  final api = ApiClient(client: mock);
  final picker = _FakePicker();
  final storage = _MemoryStorage();
  final auth = AuthController(
    api: api,
    service: AuthService(api),
    storage: storage,
    googlePicker: picker,
  );
  return (auth: auth, picker: picker, storage: storage, requests: requests);
}

const _tutorJson = {'id': 1, 'nombre': 'Ana Gómez', 'correo': 'ana@gmail.com'};

void main() {
  group('signInWithGoogle', () {
    test('envía el token a /auth/google y abre la sesión', () async {
      final t = _build((req) async {
        if (req.url.path == '/auth/google') {
          return _json({'access_token': 'jwt-1', 'tutor': _tutorJson});
        }
        return _json(_tutorJson); // /auth/me
      });

      expect(await t.auth.signInWithGoogle(), isTrue);

      final post = t.requests.firstWhere((r) => r.url.path == '/auth/google');
      expect(jsonDecode(post.body), {'id_token': 'id-token-de-google'});
      expect(t.auth.status, AuthStatus.signedIn);
      expect(t.auth.tutor?.correo, 'ana@gmail.com');
      expect(t.storage.savedToken, 'jwt-1');
      expect(t.auth.error, isNull);
      expect(t.auth.busy, isFalse);
    });

    test('si cierra el selector no es un error', () async {
      final t = _build((_) async => _json({}));
      t.picker.token = null;

      expect(await t.auth.signInWithGoogle(), isFalse);
      expect(t.auth.error, isNull);
      expect(t.auth.busy, isFalse);
      expect(t.auth.status, AuthStatus.loading); // no cambió nada
      expect(t.requests, isEmpty);
    });

    test('un fallo del selector muestra su mensaje', () async {
      final t = _build((_) async => _json({}));
      t.picker.error = GoogleSignInFailure('No hay conexión a internet.');

      expect(await t.auth.signInWithGoogle(), isFalse);
      expect(t.auth.error, 'No hay conexión a internet.');
      expect(t.requests, isEmpty);
    });

    test('401 del servidor muestra un mensaje amable y no deja token', () async {
      final api = ApiClient(client: MockClient((_) async => _json({'detail': 'x'}, 401)));
      final picker = _FakePicker();
      final auth = AuthController(
        api: api,
        service: AuthService(api),
        storage: _MemoryStorage(),
        googlePicker: picker,
      );

      expect(await auth.signInWithGoogle(), isFalse);
      expect(auth.error, contains('verificar tu cuenta de Google'));
      expect(api.token, isNull);
    });

    test('503 y 403 tienen su propio mensaje', () async {
      for (final (status, text) in [(503, 'aún no está listo'), (403, 'no está verificado')]) {
        final api = ApiClient(client: MockClient((_) async => _json({'detail': 'x'}, status)));
        final auth = AuthController(
          api: api,
          service: AuthService(api),
          storage: _MemoryStorage(),
          googlePicker: _FakePicker(),
        );
        expect(await auth.signInWithGoogle(), isFalse);
        expect(auth.error, contains(text));
      }
    });

    test('cerrar sesión limpia todo y cierra la sesión de Google', () async {
      final t = _build((req) async {
        if (req.url.path == '/auth/google') {
          return _json({'access_token': 'jwt-1', 'tutor': _tutorJson});
        }
        return _json(_tutorJson);
      });
      await t.auth.signInWithGoogle();

      await t.auth.logout();
      expect(t.auth.status, AuthStatus.signedOut);
      expect(t.auth.tutor, isNull);
      expect(t.storage.cleared, isTrue);
      expect(t.picker.signOuts, 1);
    });
  });

  group('DeviceGoogleAccountPicker', () {
    test('cancelar el selector devuelve null', () async {
      final picker = DeviceGoogleAccountPicker(plugin: _FailingGoogleSignIn('sign_in_canceled'));
      expect(await picker.pickIdToken(), isNull);
    });

    test('sin red da un mensaje de conexión', () async {
      final picker = DeviceGoogleAccountPicker(plugin: _FailingGoogleSignIn('network_error'));
      expect(
        picker.pickIdToken(),
        throwsA(isA<GoogleSignInFailure>().having((e) => e.message, 'message', contains('conexión'))),
      );
    });

    test('otro error incluye el código para poder diagnosticarlo', () async {
      final picker = DeviceGoogleAccountPicker(plugin: _FailingGoogleSignIn('sign_in_failed'));
      expect(
        picker.pickIdToken(),
        throwsA(isA<GoogleSignInFailure>().having((e) => e.message, 'message', contains('sign_in_failed'))),
      );
    });
  });
}
