import 'dart:typed_data';

import '../../core/api_client.dart';
import '../../core/safe_notifier.dart';
import 'stories_service.dart';
import 'story.dart';
import 'story_text.dart';

enum StoriesStatus { loading, ready, error }

/// Estado de los cuentos de UN niño: la lista, la creación y la caché de voz.
class StoriesController extends SafeChangeNotifier {
  StoriesController({required this.service, required this.childId});

  final StoriesService service;
  final int childId;

  StoriesStatus _status = StoriesStatus.loading;
  List<Story> _stories = const [];
  String? _error;
  bool _creating = false;
  String? _createError;
  final Map<int, Uint8List> _audioCache = {};

  StoriesStatus get status => _status;
  List<Story> get stories => _stories;
  String? get error => _error;
  bool get creating => _creating;
  String? get createError => _createError;

  /// [silent] = true (por ejemplo al arrastrar para refrescar) mantiene la
  /// lista visible en lugar de mostrar el indicador de carga.
  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _status = StoriesStatus.loading;
      _error = null;
      notifyListeners();
    }
    try {
      _stories = await service.list(childId);
      _status = StoriesStatus.ready;
      _error = null;
    } on ApiException catch (e) {
      _fail(friendlyStoryError(e), silent);
    } catch (_) {
      _fail('No pudimos cargar los cuentos.', silent);
    }
    notifyListeners();
  }

  void _fail(String message, bool silent) {
    // Un refresco que falla no borra la lista que ya se tenía.
    if (silent && _stories.isNotEmpty) return;
    _error = message;
    _status = StoriesStatus.error;
  }

  void clearCreateError() {
    if (_createError == null) return;
    _createError = null;
    notifyListeners();
  }

  /// Devuelve el cuento creado, o null si falló (el motivo queda en
  /// [createError]). Ignora toques repetidos mientras ya se está creando.
  Future<Story?> create({
    required List<String> words,
    String? contexto,
    String language = 'es',
  }) async {
    if (_creating) return null;

    final valid = words.where(isValidStoryWord).toList();
    if (valid.isEmpty) {
      _createError = 'Elige al menos una palabra para el cuento.';
      notifyListeners();
      return null;
    }

    _creating = true;
    _createError = null;
    notifyListeners();
    try {
      final story = await service.create(
        childId: childId,
        words: valid.take(kMaxStoryWords).toList(),
        contexto: contexto,
        language: language,
      );
      _stories = [story, ..._stories];
      _status = StoriesStatus.ready;
      return story;
    } on ApiException catch (e) {
      _createError = friendlyStoryError(e);
      return null;
    } catch (_) {
      _createError = 'No pudimos crear el cuento ahora. Inténtalo en un ratito.';
      return null;
    } finally {
      _creating = false;
      notifyListeners();
    }
  }

  /// Bytes de la narración; se descargan una sola vez por sesión.
  Future<Uint8List> audioFor(int storyId) async {
    final cached = _audioCache[storyId];
    if (cached != null) return cached;
    final bytes = await service.audio(storyId);
    _audioCache[storyId] = bytes;
    return bytes;
  }
}
