import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../../core/api_client.dart';
import '../../core/safe_notifier.dart';

enum NarrationState { idle, loading, playing, paused, error }

/// Reproduce la narración de un cuento: descarga, reproduce, pausa y sigue.
class StoryNarration extends SafeChangeNotifier {
  StoryNarration({required this.loadBytes}) {
    _doneSub = _player.onPlayerComplete.listen((_) {
      _set(NarrationState.idle);
    });
  }

  /// Cómo obtener el mp3 (el controlador lo guarda en caché).
  final Future<Uint8List> Function() loadBytes;

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _doneSub;
  bool _closed = false;

  NarrationState _state = NarrationState.idle;
  String? _error;

  NarrationState get state => _state;
  String? get error => _error;

  void _set(NarrationState value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }

  /// Un solo botón: empezar, pausar o seguir según el estado.
  Future<void> toggle() async {
    switch (_state) {
      case NarrationState.loading:
        return;
      case NarrationState.playing:
        await pause();
      case NarrationState.paused:
        try {
          await _player.resume();
          _set(NarrationState.playing);
        } catch (_) {
          await _start();
        }
      case NarrationState.idle:
      case NarrationState.error:
        await _start();
    }
  }

  Future<void> _start() async {
    _error = null;
    _set(NarrationState.loading);
    try {
      final bytes = await loadBytes();
      if (_closed) return;
      await _player.play(BytesSource(bytes));
      if (_closed) return;
      _set(NarrationState.playing);
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('No pudimos reproducir la voz. Inténtalo otra vez.');
    }
  }

  void _fail(String message) {
    if (_closed) return;
    _error = message;
    _set(NarrationState.error);
  }

  Future<void> pause() async {
    if (_state != NarrationState.playing) return;
    try {
      await _player.pause();
    } catch (_) {}
    _set(NarrationState.paused);
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    _set(NarrationState.idle);
  }

  @override
  void dispose() {
    _closed = true;
    _doneSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
