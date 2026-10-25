import 'package:audioplayers/audioplayers.dart';

import 'vocab_models.dart';

/// Reproduce la pronunciación de una palabra desde los audios locales.
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> play(Word word) async {
    final file = word.audio;
    if (file == null) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/$file'));
    } catch (_) {
      // Si el audio no existe o falla, la tarjeta simplemente no suena.
    }
  }

  void dispose() {
    _player.dispose();
  }
}
