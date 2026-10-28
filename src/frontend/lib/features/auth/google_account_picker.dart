import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config.dart';

/// Falla al elegir la cuenta de Google, con un mensaje listo para mostrar.
class GoogleSignInFailure implements Exception {
  GoogleSignInFailure(this.message);

  final String message;

  @override
  String toString() => 'GoogleSignInFailure: $message';
}

/// Muestra el selector de cuentas de Google y devuelve el token de identidad.
abstract class GoogleAccountPicker {
  /// El token de identidad, o null si la persona cerró el selector sin elegir.
  Future<String?> pickIdToken();

  /// Cierra la sesión de Google del teléfono (para que vuelva a salir el selector).
  Future<void> signOut();
}

class DeviceGoogleAccountPicker implements GoogleAccountPicker {
  DeviceGoogleAccountPicker({GoogleSignIn? plugin}) : _override = plugin;

  final GoogleSignIn? _override;

  // serverClientId = ID de cliente web: hace que Google entregue el idToken
  // que verifica nuestro servidor.
  late final GoogleSignIn _google = _override ??
      GoogleSignIn(
        scopes: const ['email'],
        serverClientId: AppConfig.googleServerClientId,
      );

  @override
  Future<String?> pickIdToken() async {
    try {
      // Se cierra cualquier sesión previa para que SIEMPRE aparezca el selector.
      await _google.signOut();
      final account = await _google.signIn();
      if (account == null) return null; // cerró el selector

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw GoogleSignInFailure(
          'Google no entregó la identificación. Intenta de nuevo.',
        );
      }
      return idToken;
    } on PlatformException catch (e) {
      debugPrint('⚠️ Google Sign-In: ${e.code} · ${e.message}');
      switch (e.code) {
        case 'sign_in_canceled':
          return null;
        case 'network_error':
          throw GoogleSignInFailure(
            'No hay conexión a internet. Revisa tu red e intenta de nuevo.',
          );
        default:
          throw GoogleSignInFailure(
            'No pudimos iniciar sesión con Google (${e.code}). '
            'Si el problema sigue, avisa al equipo.',
          );
      }
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {
      // No es grave: la próxima vez se vuelve a cerrar antes de elegir.
    }
  }
}
