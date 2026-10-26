import 'study_config.dart';

/// Qué debe pasar después de un intento.
enum FlowNext { none, toSpanish, toEnglish, wordComplete }

class FlowResult {
  const FlowResult({
    required this.success,
    required this.assisted,
    required this.next,
  });

  /// true si cuenta como acierto (incluye el asistido).
  final bool success;

  /// true si el acierto vino de 3 fallos seguidos.
  final bool assisted;
  final FlowNext next;
}

/// Estado de una palabra: idioma activo, qué idiomas ya se hicieron y la
/// racha de fallos. No depende de Flutter, así que se prueba fácil.
class StudyFlow {
  Lang active = Lang.en;
  bool doneEn = false;
  bool doneEs = false;
  int failStreak = 0;

  bool get wordComplete => doneEn && doneEs;

  /// Nueva palabra: todo vuelve a empezar en inglés.
  void resetForWord() {
    active = Lang.en;
    doneEn = false;
    doneEs = false;
    failStreak = 0;
  }

  /// Cambia el idioma activo (sin penalización). Cortar la racha de fallos
  /// porque ya no es "el mismo idioma".
  void select(Lang lang) {
    if (lang == active) return;
    active = lang;
    failStreak = 0;
  }

  FlowResult registerSuccess() => _complete(assisted: false);

  FlowResult registerFailure() {
    failStreak++;
    if (failStreak >= kAssistedAfter) return _complete(assisted: true);
    return const FlowResult(success: false, assisted: false, next: FlowNext.none);
  }

  FlowResult _complete({required bool assisted}) {
    if (active == Lang.en) {
      doneEn = true;
    } else {
      doneEs = true;
    }
    failStreak = 0;

    final FlowNext next;
    if (wordComplete) {
      next = FlowNext.wordComplete;
    } else {
      next = active == Lang.en ? FlowNext.toSpanish : FlowNext.toEnglish;
    }
    return FlowResult(success: true, assisted: assisted, next: next);
  }
}
