import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/api_client.dart';
import '../../core/safe_notifier.dart';
import '../consent/consent_controller.dart';
import '../vocabulary/audio_service.dart';
import '../vocabulary/vocab_models.dart';
import 'local_judge.dart';
import 'progress_repository.dart';
import 'speech_judge_service.dart';
import 'study_config.dart';

enum MicState { ready, listening, processing, success, tryAgain, unavailable }

/// Orquesta el micrófono: escucha en el teléfono, juzga en local y, solo si
/// hace falta, pregunta al servidor con texto. El audio nunca sale de la app.
class PronunciationController extends SafeChangeNotifier {
  PronunciationController({
    required this.childId,
    required this.judge,
    required this.progress,
    required this.consent,
    required this.audio,
  });

  final int childId;
  final SpeechJudgeService judge;
  final ProgressRepository progress;
  final ConsentController consent;
  final StudyAudio audio;

  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;

  MicState _state = MicState.ready;
  String? _message;
  Word? _word;

  int _attempt = 0;
  bool _handled = false;
  Timer? _guardTimer;
  Timer? _statusTimer;
  Timer? _resetTimer;

  MicState get state => _state;
  String? get message => _message;

  /// Cambia la palabra de estudio y reinicia el micrófono.
  void setWord(Word word) {
    _word = word;
    _cancelAll();
    _state = MicState.ready;
    _message = null;
    notifyListeners();
  }

  void _cancelAll() {
    _attempt++;
    _guardTimer?.cancel();
    _statusTimer?.cancel();
    _resetTimer?.cancel();
    if (_stt.isListening) unawaited(_stt.cancel());
  }

  /// Toque del niño sobre el micrófono.
  Future<void> toggle() async {
    if (_state == MicState.processing) return;
    if (_state == MicState.listening) {
      try {
        await _stt.stop();
      } catch (_) {}
      return;
    }
    await _start();
  }

  Future<void> _start() async {
    // Sin consentimiento no se pide el permiso del sistema ni se escucha.
    if (!consent.voiceAllowed) return;

    _resetTimer?.cancel();
    final attempt = ++_attempt;
    await audio.stop();

    if (!_sttReady) {
      try {
        _sttReady = await _stt.initialize(
          onStatus: _onStatus,
          onError: _onError,
        );
      } catch (e) {
        debugPrint('⚠️ speech_to_text no pudo iniciar: $e');
        _sttReady = false;
      }
      if (!_sttReady) {
        _fail('Pídele a un adulto que revise el micrófono 🎤');
        return;
      }
    }
    if (attempt != _attempt) return;

    _handled = false;
    _message = null;
    _state = MicState.listening;
    notifyListeners();

    _guardTimer?.cancel();
    _guardTimer = Timer(
      const Duration(seconds: 10),
      () => _finish(attempt, const []),
    );

    try {
      await _stt.listen(
        onResult: (result) => _onResult(attempt, result),
        localeId: 'en_US',
        listenFor: const Duration(seconds: 6),
        pauseFor: const Duration(seconds: 2),
        listenOptions: SpeechListenOptions(
          partialResults: false,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ listen falló: $e');
      _finish(attempt, const []);
    }
  }

  void _onResult(int attempt, SpeechRecognitionResult result) {
    if (!result.finalResult) return;

    final heard = <String>[];
    for (final alt in result.alternates) {
      final text = alt.recognizedWords.trim();
      if (text.isNotEmpty && !heard.contains(text)) heard.add(text);
    }
    final main = result.recognizedWords.trim();
    if (heard.isEmpty && main.isNotEmpty) heard.add(main);

    _finish(attempt, heard.take(kMaxAlternatives).toList());
  }

  void _onStatus(String status) {
    if ((status == 'done' || status == 'notListening') &&
        _state == MicState.listening) {
      final attempt = _attempt;
      _statusTimer?.cancel();
      // Pequeña espera por si el resultado final llega justo después.
      _statusTimer = Timer(
        const Duration(milliseconds: 900),
        () => _finish(attempt, const []),
      );
    }
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint('⚠️ speech_to_text: ${error.errorMsg}');
    if (error.errorMsg == 'error_permission') {
      _fail('Pídele a un adulto que active el micrófono 🎤');
      return;
    }
    if (_state == MicState.listening) _finish(_attempt, const []);
  }

  void _finish(int attempt, List<String> heard) {
    if (attempt != _attempt || _handled) return;
    _handled = true;
    _guardTimer?.cancel();
    _statusTimer?.cancel();
    unawaited(_evaluate(attempt, heard));
  }

  Future<void> _evaluate(int attempt, List<String> heard) async {
    final word = _word;
    if (word == null) return;

    _state = MicState.processing;
    _message = null;
    notifyListeners();

    // 1) juez local; 2) solo si no acepta y hay algo escuchado, el servidor
    var ok = localJudge(word.en, heard);
    if (!ok && heard.isNotEmpty) ok = await _askServer(word, heard);

    if (attempt != _attempt) return;

    progress.recordAttempt(word.en, ok, childId: childId);

    if (ok) {
      _state = MicState.success;
      _message = '¡Muy bien! 🌟';
      unawaited(audio.playSuccess());
    } else {
      _state = MicState.tryAgain;
      _message = '¡Casi! Inténtalo otra vez 💪';
      unawaited(audio.speak(Lang.en, word));
    }
    notifyListeners();

    _resetTimer = Timer(const Duration(milliseconds: 2600), () {
      if (attempt != _attempt) return;
      _state = MicState.ready;
      _message = null;
      notifyListeners();
    });
  }

  Future<bool> _askServer(Word word, List<String> heard) async {
    try {
      return await judge.judge(
        childId: childId,
        word: word.en,
        heard: heard,
      );
    } on ApiException catch (e) {
      debugPrint('⚠️ /speech/judge: ${e.statusCode} ${e.message}');
      if (e.statusCode == 403) {
        // Falta consentimiento: refresca para ocultar el micrófono.
        unawaited(consent.load());
      }
      // Timeout, 429, 502, 503, sin internet, 404: se trata como "otra vez".
      return false;
    } catch (e) {
      debugPrint('⚠️ /speech/judge: $e');
      return false;
    }
  }

  void _fail(String message) {
    _guardTimer?.cancel();
    _state = MicState.unavailable;
    _message = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _guardTimer?.cancel();
    _statusTimer?.cancel();
    _resetTimer?.cancel();
    if (_sttReady) unawaited(_stt.cancel());
    super.dispose();
  }
}
