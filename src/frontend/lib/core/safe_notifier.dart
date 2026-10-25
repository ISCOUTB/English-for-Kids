import 'package:flutter/foundation.dart';

/// ChangeNotifier que ignora notificaciones llegadas después de dispose()
/// (por ejemplo, una petición que termina cuando el tutor ya cerró sesión).
class SafeChangeNotifier extends ChangeNotifier {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
