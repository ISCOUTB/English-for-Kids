import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/auth/tutor.dart';

class SavedSession {
  const SavedSession(this.token, this.tutor);

  final String token;
  final Tutor? tutor;
}

/// Guarda en el teléfono la sesión del tutor y algunos datos de apoyo.
class SessionStorage {
  SessionStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kToken = 'session_token';
  static const _kTutor = 'session_tutor';
  static const _kActiveChild = 'active_child_id';
  static const _kChildrenCache = 'children_cache';

  Future<SavedSession?> read() async {
    try {
      final token = await _storage.read(key: _kToken);
      if (token == null || token.isEmpty) return null;

      Tutor? tutor;
      final raw = await _storage.read(key: _kTutor);
      if (raw != null) {
        try {
          tutor = Tutor.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {
          tutor = null;
        }
      }
      return SavedSession(token, tutor);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(String token, Tutor tutor) async {
    try {
      await _storage.write(key: _kToken, value: token);
      await _storage.write(key: _kTutor, value: jsonEncode(tutor.toJson()));
    } catch (_) {
      // Si no se puede guardar, la sesión dura solo mientras la app esté abierta.
    }
  }

  // --- Niño activo (con quién se juega) ---

  Future<int?> readActiveChild() async {
    try {
      final raw = await _storage.read(key: _kActiveChild);
      return raw == null ? null : int.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveActiveChild(int? id) async {
    try {
      if (id == null) {
        await _storage.delete(key: _kActiveChild);
      } else {
        await _storage.write(key: _kActiveChild, value: id.toString());
      }
    } catch (_) {}
  }

  // --- Copia local de los perfiles (para abrir la app sin conexión) ---

  Future<String?> readChildrenCache() async {
    try {
      return await _storage.read(key: _kChildrenCache);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveChildrenCache(String json) async {
    try {
      await _storage.write(key: _kChildrenCache, value: json);
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _kToken);
      await _storage.delete(key: _kTutor);
      await _storage.delete(key: _kActiveChild);
      await _storage.delete(key: _kChildrenCache);
    } catch (_) {}
  }
}
