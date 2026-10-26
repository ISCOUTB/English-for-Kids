import 'package:english_for_kids/features/study/study_config.dart';
import 'package:english_for_kids/features/study/study_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudyFlow', () {
    test('empieza en inglés, sin nada hecho', () {
      final f = StudyFlow();
      expect(f.active, Lang.en);
      expect(f.doneEn, isFalse);
      expect(f.doneEs, isFalse);
      expect(f.wordComplete, isFalse);
    });

    test('acierta en inglés -> pasa a español', () {
      final f = StudyFlow();
      final r = f.registerSuccess();
      expect(r.success, isTrue);
      expect(r.assisted, isFalse);
      expect(r.next, FlowNext.toSpanish);
      expect(f.doneEn, isTrue);
      expect(f.doneEs, isFalse);
    });

    test('acierta en español primero -> pasa a inglés', () {
      final f = StudyFlow()..select(Lang.es);
      final r = f.registerSuccess();
      expect(r.next, FlowNext.toEnglish);
      expect(f.doneEs, isTrue);
      expect(f.doneEn, isFalse);
    });

    test('en -> es -> palabra completa', () {
      final f = StudyFlow();
      expect(f.registerSuccess().next, FlowNext.toSpanish);
      f.select(Lang.es); // lo hace el audio de transición al terminar
      final r = f.registerSuccess();
      expect(r.next, FlowNext.wordComplete);
      expect(f.wordComplete, isTrue);
    });

    test('es -> en -> palabra completa', () {
      final f = StudyFlow()..select(Lang.es);
      expect(f.registerSuccess().next, FlowNext.toEnglish);
      f.select(Lang.en);
      expect(f.registerSuccess().next, FlowNext.wordComplete);
    });

    test('repetir un idioma ya hecho sin el otro vuelve a pasar al otro', () {
      final f = StudyFlow();
      f.registerSuccess();
      expect(f.registerSuccess().next, FlowNext.toSpanish);
    });

    test('cambiar de idioma no penaliza', () {
      final f = StudyFlow();
      f.registerFailure();
      f.select(Lang.es);
      expect(f.active, Lang.es);
      expect(f.failStreak, 0);
    });

    test('3 fallos seguidos cuentan como acierto asistido', () {
      final f = StudyFlow();
      final r1 = f.registerFailure();
      final r2 = f.registerFailure();
      expect(r1.success, isFalse);
      expect(r2.success, isFalse);
      expect(r2.next, FlowNext.none);

      final r3 = f.registerFailure();
      expect(r3.success, isTrue);
      expect(r3.assisted, isTrue);
      expect(r3.next, FlowNext.toSpanish);
      expect(f.doneEn, isTrue);
      expect(f.failStreak, 0);
    });

    test('un acierto reinicia la racha de fallos', () {
      final f = StudyFlow();
      f.registerFailure();
      f.registerFailure();
      expect(f.registerSuccess().assisted, isFalse);
      expect(f.failStreak, 0);
      // y vuelven a hacer falta 3 fallos
      expect(f.registerFailure().success, isFalse);
    });

    test('cambiar de idioma corta la racha (no es el mismo idioma)', () {
      final f = StudyFlow();
      f.registerFailure();
      f.registerFailure();
      f.select(Lang.es);
      f.select(Lang.en);
      expect(f.registerFailure().assisted, isFalse);
    });

    test('un acierto asistido en el segundo idioma completa la palabra', () {
      final f = StudyFlow();
      f.registerSuccess();
      f.select(Lang.es);
      f.registerFailure();
      f.registerFailure();
      final r = f.registerFailure();
      expect(r.assisted, isTrue);
      expect(r.next, FlowNext.wordComplete);
    });

    test('resetForWord vuelve todo a empezar', () {
      final f = StudyFlow();
      f.registerSuccess();
      f.select(Lang.es);
      f.registerFailure();
      f.resetForWord();
      expect(f.active, Lang.en);
      expect(f.doneEn, isFalse);
      expect(f.doneEs, isFalse);
      expect(f.failStreak, 0);
    });
  });
}
