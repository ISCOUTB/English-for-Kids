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
import 'study_flow.dart';

enum MicState { ready, listening, processing, success, tryAgain, unavailable }

/// Orquesta el estudio de una palabra: micrófono, juez local, servidor,
/// idioma activo y el flujo inglés <-> español. El audio nunca sale de la app.
class PronunciationController extends SafeChangeNotifier {
  PronunciationController({
    required this.childId,
    required this.band,
    required this.judge,
    required this.progress,
    required this.consent,
    required this.audio,
  });

  final int childId;
  final AgeBand band;
  final SpeechJudgeService judge;
  final ProgressRepository progress;
  final ConsentController consent;
  final StudyAudio audio;

  final StudyFlow flow = StudyFlow();

  /// Nivel de sonido normalizado 0..1 para animar el anillo del micrófono.
  final ValueNotifier<double> soundLevel = ValueNotifier<double>(0);

  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;
  final Map<Lang, String?> _locales = {};

  MicState _state = MicState.ready;
  String? _message;
  Word? _word;
  bool _transitioning = false;

  int _attempt = 0;
  bool _handled = false;
  double _maxLevel = 0;
  final List<String> _partials = [];
  Timer? _guardTimer;
  Timer? _statusTimer;
  Timer? _resetTimer;

  MicState get state => _state;
  String? get message => _message;
  Lang get activeLang => flow.active;
  bool get doneEn => flow.doneEn;
  bool get doneEs => flow.doneEs;
  bool get wordComplete => flow.wordComplete;

  /// true mientras suena el audio de transición: el micrófono no está
  /// disponible (así no capta el audio del propio teléfono).
  bool get transitioning => _transitioning;

  /// Nueva palabra: todo se reinicia en inglés.
  void setWord(Word word) {
    _word = word;
    _cancelAll();
    flow.resetForWord();
    _state = MicState.ready;
    _message = null;
    notifyListeners();
  }

  /// El niño toca un personaje: suena su idioma y pasa a ser el activo,
  /// sin penalización.
  void selectLanguage(Lang lang) {
    final word = _word;
    if (word == null) return;
    _cancelAll();
    flow.select(lang);
    _state = MicState.ready;
    _message = null;
    notifyListeners();
    unawaited(audio.speak(lang, word));
  }

  void _cancelAll() {
    _attempt++;
    _transitioning = false;
    _guardTimer?.cancel();
    _statusTimer?.cancel();
    _resetTimer?.cancel();
    soundLevel.value = 0;
    if (_stt.isListening) unawaited(_stt.cancel());
  }

  /// Toque del niño sobre el micrófono.
  Future<void> toggle() async {
    if (_state == MicState.processing || _transitioning) return;
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
    final lang = flow.active;
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
    final locale = await _localeFor(lang);
    if (attempt != _attempt) return;

    _handled = false;
    _maxLevel = 0;
    _partials.clear();
    soundLevel.value = 0;
    _message = null;
    _state = MicState.listening;
    notifyListeners();

    _guardTimer?.cancel();
    _guardTimer = Timer(
      kListenFor + const Duration(seconds: 4),
      () => _finish(attempt, const []),
    );

    try {
      await _stt.listen(
        onResult: (result) => _onResult(attempt, result),
        onSoundLevelChange: (level) => _onSoundLevel(attempt, level),
        localeId: locale,
        listenFor: kListenFor,
        pauseFor: kPauseFor,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ listen falló: $e');
      _finish(attempt, const []);
    }
  }

  /// en-US para inglés; para español es-CO y, si no está, es-US o es-ES.
  Future<String?> _localeFor(Lang lang) async {
    if (_locales.containsKey(lang)) return _locales[lang];

    String? chosen;
    try {
      final available = await _stt.locales();
      String norm(String id) => id.replaceAll('-', '_').toLowerCase();
      final byNorm = {for (final l in available) norm(l.localeId): l.localeId};

      final preferred =
          lang == Lang.en ? ['en_US'] : ['es_CO', 'es_US', 'es_ES'];
      for (final p in preferred) {
        final hit = byNorm[p.toLowerCase()];
        if (hit != null) {
          chosen = hit;
          break;
        }
      }
      if (chosen == null) {
        final prefix = lang == Lang.en ? 'en' : 'es';
        for (final e in byNorm.entries) {
          if (e.key.startsWith(prefix)) {
            chosen = e.value;
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ No se pudieron leer los idiomas del reconocedor: $e');
    }
    if (chosen == null) {
      debugPrint('⚠️ Sin idioma ${lang.name} en el reconocedor; usa el del teléfono');
    }
    _locales[lang] = chosen;
    return chosen;
  }

  void _onSoundLevel(int attempt, double level) {
    if (attempt != _attempt || _state != MicState.listening) return;
    if (level > _maxLevel) _maxLevel = level;
    soundLevel.value =
        ((level - kSoundMin) / (kSoundMax - kSoundMin)).clamp(0.0, 1.0);
  }

  void _onResult(int attempt, SpeechRecognitionResult result) {
    if (attempt != _attempt) return;

    if (!result.finalResult) {
      // Resultado parcial: lo más reciente primero.
      final text = result.recognizedWords.trim();
      if (text.isNotEmpty) {
        _partials.remove(text);
        _partials.insert(0, text);
      }
      return;
    }

    final heard = <String>[];
    for (final alt in result.alternates) {
      final text = alt.recognizedWords.trim();
      if (text.isNotEmpty && !heard.contains(text)) heard.add(text);
    }
    final main = result.recognizedWords.trim();
    if (heard.isEmpty && main.isNotEmpty) heard.add(main);

    _finish(attempt, heard);
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

  void _finish(int attempt, List<String> finalAlternatives) {
    if (attempt != _attempt || _handled) return;
    _handled = true;
    _guardTimer?.cancel();
    _statusTimer?.cancel();

    // Alternativas finales primero y luego los parciales, hasta 5.
    final heard = <String>[];
    for (final text in [...finalAlternatives, ..._partials]) {
      if (text.isNotEmpty && !heard.contains(text)) heard.add(text);
      if (heard.length >= kMaxAlternatives) break;
    }
    unawaited(_evaluate(attempt, heard));
  }

  Future<void> _evaluate(int attempt, List<String> heard) async {
    final word = _word;
    if (word == null) return;
    final lang = flow.active;
    final target = lang == Lang.en ? word.en : word.es;

    _state = MicState.processing;
    _message = null;
    soundLevel.value = 0;
    notifyListeners();

    // 1) juez local (según idioma y edad); 2) si dudoso, el servidor con texto
    var ok = localJudge(target, heard, lang: lang, band: band);
    if (!ok && heard.isNotEmpty) ok = await _askServer(target, lang, heard);

    if (attempt != _attempt) return;

    // Sin texto y sin ruido: el niño no habló. No cuenta como intento.
    if (!ok && heard.isEmpty && _maxLevel < kSoundThreshold) {
      _state = MicState.tryAgain;
      _message = '¡No te oí! Habla más cerca 🎤';
      notifyListeners();
      _scheduleReset(attempt, const Duration(milliseconds: 2600));
      return;
    }

    final result = ok ? flow.registerSuccess() : flow.registerFailure();
    progress.recordAttempt(
      word.en,
      lang.name,
      result.success,
      result.assisted,
      childId: childId,
    );

    if (result.success) {
      await _celebrate(attempt, word, result);
    } else {
      _state = MicState.tryAgain;
      _message = heard.isEmpty
          ? '¡Te escuché! Inténtalo otra vez 👂'
          : '¡Casi! Inténtalo otra vez 💪';
      notifyListeners();
      unawaited(audio.speak(lang, word)); // repite la palabra una vez
      _scheduleReset(attempt, const Duration(milliseconds: 2600));
    }
  }

  Future<bool> _askServer(String target, Lang lang, List<String> heard) async {
    try {
      return await judge.judge(
        childId: childId,
        word: target,
        lang: lang,
        heard: heard,
      );
    } on ApiException catch (e) {
      debugPrint('⚠️ /speech/judge: ${e.statusCode} ${e.message}');
      if (e.statusCode == 403) {
        // Falta consentimiento: refresca para ocultar el micrófono.
        unawaited(consent.load());
      }
      // Timeout, 404, 429, 502, 503, sin internet: "otra vez" sin mostrar error.
      return false;
    } catch (e) {
      debugPrint('⚠️ /speech/judge: $e');
      return false;
    }
  }

  Future<void> _celebrate(int attempt, Word word, FlowResult result) async {
    if (result.next == FlowNext.wordComplete) {
      // Celebración completa: success + winning star y botón "siguiente".
      _state = MicState.success;
      _message = '¡Lo lograste! 🏆';
      notifyListeners();
      unawaited(audio.playFxSequence(kCompleteSounds));
      _scheduleReset(attempt, const Duration(milliseconds: 3200));
      return;
    }

    // Celebración breve y luego audio de transición al otro idioma.
    final toSpanish = result.next == FlowNext.toSpanish;
    final nextLang = toSpanish ? Lang.es : Lang.en;
    final transitionAudio = toSpanish ? kTransitionToSpanish : kTransitionToEnglish;

    _transitioning = true;
    _state = MicState.success;
    _message = '¡Muy bien! 🌟';
    notifyListeners();

    await Future<void>.delayed(kShortCelebration);
    if (attempt != _attempt) return;

    _state = MicState.ready;
    _message = null;
    notifyListeners();

    final completed = await audio.playUntilDone(transitionAudio);
    if (attempt != _attempt || !completed) return;

    flow.select(nextLang);
    _transitioning = false;
    notifyListeners();
  }

  void _scheduleReset(int attempt, Duration after) {
    _resetTimer?.cancel();
    _resetTimer = Timer(after, () {
      if (attempt != _attempt) return;
      _state = MicState.ready;
      _message = null;
      notifyListeners();
    });
  }

  void _fail(String message) {
    _guardTimer?.cancel();
    _state = MicState.unavailable;
    _message = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _attempt++;
    _guardTimer?.cancel();
    _statusTimer?.cancel();
    _resetTimer?.cancel();
    if (_sttReady) unawaited(_stt.cancel());
    soundLevel.dispose();
    super.dispose();
  }
}
