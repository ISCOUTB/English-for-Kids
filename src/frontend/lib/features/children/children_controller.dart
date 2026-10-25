import 'dart:convert';

import '../../core/api_client.dart';
import '../../core/safe_notifier.dart';
import '../../core/session_storage.dart';
import 'child.dart';
import 'children_service.dart';

class ChildrenController extends SafeChangeNotifier {
  ChildrenController({
    required ChildrenService service,
    required SessionStorage storage,
  })  : _service = service,
        _storage = storage;

  final ChildrenService _service;
  final SessionStorage _storage;

  List<Child> _children = [];
  bool _loading = true;
  bool _offline = false;
  String? _error;
  int? _activeId;

  List<Child> get children => List.unmodifiable(_children);
  bool get loading => _loading;

  /// true si se están mostrando los perfiles guardados por falta de conexión.
  bool get offline => _offline;
  String? get error => _error;
  int? get activeId => _activeId;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    _activeId = await _storage.readActiveChild();

    try {
      _children = await _service.list();
      _offline = false;
      await _saveCache();
    } on ApiException catch (e) {
      if (e.isNetwork) {
        final cached = await _readCache();
        if (cached != null) {
          _children = cached;
          _offline = true;
        } else {
          _error = e.message;
        }
      } else {
        _error = e.message;
      }
    } catch (_) {
      _error = 'No pudimos cargar los perfiles. Intenta de nuevo.';
    }

    if (_activeId != null && !_children.any((c) => c.id == _activeId)) {
      _activeId = null;
      await _storage.saveActiveChild(null);
    }

    _loading = false;
    notifyListeners();
  }

  /// Devuelve null si todo salió bien, o el mensaje de error.
  Future<String?> add({
    required String apodo,
    required String rangoEdad,
    required String avatar,
  }) async {
    try {
      final child = await _service.create(
        apodo: apodo,
        rangoEdad: rangoEdad,
        avatar: avatar,
      );
      _children = [..._children, child];
      _offline = false;
      await _saveCache();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Algo salió mal. Intenta de nuevo.';
    }
  }

  /// Devuelve null si todo salió bien, o el mensaje de error.
  Future<String?> remove(Child child) async {
    try {
      await _service.delete(child.id);
      _children = _children.where((c) => c.id != child.id).toList();
      if (_activeId == child.id) {
        _activeId = null;
        await _storage.saveActiveChild(null);
      }
      await _saveCache();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Algo salió mal. Intenta de nuevo.';
    }
  }

  Future<void> select(Child child) async {
    _activeId = child.id;
    notifyListeners();
    await _storage.saveActiveChild(child.id);
  }

  Future<void> _saveCache() {
    return _storage.saveChildrenCache(
      jsonEncode(_children.map((c) => c.toJson()).toList()),
    );
  }

  Future<List<Child>?> _readCache() async {
    final raw = await _storage.readChildrenCache();
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(Child.fromJson)
            .toList();
      }
    } catch (_) {}
    return null;
  }
}
