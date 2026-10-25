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

  Future<void> stop() async {
    try {
      await _voice.stop();
    } catch (_) {}
    _setSpeaking(null);
  }

  Future<void> playSuccess() async {
    try {
      await _fx.stop();
      await _fx.play(AssetSource(kSuccessSound));
    } catch (e) {
      debugPrint('⚠️ No se pudo reproducir assets/$kSuccessSound: $e');
    }
  }

  @override
  void dispose() {
    _doneSub?.cancel();
    _voice.dispose();
    _fx.dispose();
    super.dispose();
  }
}
