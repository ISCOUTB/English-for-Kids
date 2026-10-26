import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../core/safe_notifier.dart';
import '../study/study_config.dart';
import 'vocab_models.dart';

/// Reproduce la palabra en inglés o en español y avisa qué idioma está
/// sonando para animar al personaje correcto.
class StudyAudio extends SafeChangeNotifier {
  StudyAudio() {
    _doneSub = _voice.onPlayerComplete.listen((_) => _setSpeaking(null));
  }

  final AudioPlayer _voice = AudioPlayer();
  final AudioPlayer _fx = AudioPlayer();
  StreamSubscription<void>? _doneSub;

  Lang? _speaking;

  /// Sube cada vez que algo nuevo cancela lo anterior.
  int _epoch = 0;

  /// Idioma que suena ahora mismo (null si no suena nada).
  Lang? get speaking => _speaking;

  void _setSpeaking(Lang? lang) {
    if (_speaking == lang) return;
    _speaking = lang;
    notifyListeners();
  }

  /// Detiene lo que suene y reproduce la palabra en el idioma pedido.
  Future<void> speak(Lang lang, Word word) async {
    final path = lang == Lang.en ? word.audioEn : word.audioEs;
    _epoch++;
    if (path == null) {
      debugPrint('⚠️ Sin audio ${lang.name} para "${word.id}"');
      return;
    }
    try {
      await _voice.stop();
      _setSpeaking(lang);
      await _voice.play(AssetSource(path));
    } catch (e) {
      debugPrint('⚠️ No se pudo reproducir assets/$path: $e');
      _setSpeaking(null);
    }
  }

  /// Reproduce un audio de interfaz (nadie mueve la boca) y espera a que
  /// termine. Devuelve false si otra cosa lo canceló mientras sonaba. Si el
  /// archivo no existe, sigue sin él y devuelve true.
  Future<bool> playUntilDone(String path) async {
    final mine = ++_epoch;
    try {
      await _voice.stop();
      _setSpeaking(null);
      await _voice.play(AssetSource(path));
      await _voice.onPlayerComplete.first.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('⚠️ Audio omitido assets/$path: $e');
    }
    return mine == _epoch;
  }

  /// Reproduce varios sonidos de interfaz, uno tras otro.
  Future<void> playFxSequence(List<String> paths) async {
    for (final path in paths) {
      try {
        await _fx.stop();
        await _fx.play(AssetSource(path));
        await _fx.onPlayerComplete.first.timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('⚠️ Sonido omitido assets/$path: $e');
      }
    }
  }

  Future<void> stop() async {
    _epoch++;
    try {
      await _voice.stop();
    } catch (_) {}
    _setSpeaking(null);
  }

  @override
  void dispose() {
    _epoch++;
    _doneSub?.cancel();
    _voice.dispose();
    _fx.dispose();
    super.dispose();
  }
}
