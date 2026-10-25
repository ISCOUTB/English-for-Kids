import 'package:english_for_kids/features/study/local_judge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeText', () {
    test('quita tildes, signos y espacios extra', () {
      expect(normalizeText('  ¡Árbol!  '), 'arbol');
      expect(normalizeText('It\'s  A   Dog.'), 'it s a dog');
    });
  });

  group('localJudge', () {
    test('acepta la palabra exacta', () {
      expect(localJudge('dog', ['dog']), isTrue);
      expect(localJudge('dog', ['Dog!']), isTrue);
    });

    test('NO acepta "dug" para "dog" en local', () {
      expect(localJudge('dog', ['dug']), isFalse);
    });

    test('acepta si la contiene como palabra completa', () {
      expect(localJudge('dog', ['the dog']), isTrue);
      expect(localJudge('dog', ['hot dog please']), isTrue);
    });

    test('NO acepta si solo la contiene dentro de otra palabra', () {
      expect(localJudge('dog', ['dogma']), isFalse);
    });

    test('acepta singular y plural', () {
      expect(localJudge('bananas', ['banana']), isTrue);
      expect(localJudge('dog', ['dogs']), isTrue);
    });

    test('acepta la palabra separada por espacios', () {
      expect(localJudge('eggplant', ['egg plant']), isTrue);
      expect(localJudge('toothbrush', ['tooth brush']), isTrue);
    });

    test('acepta alias conocidos', () {
      expect(localJudge('red', ['read']), isTrue);
      expect(localJudge('pear', ['pair']), isTrue);
    });

    test('"elefant" acepta "elephant" (clave fonética, 6+ letras)', () {
      expect(localJudge('elephant', ['elefant']), isTrue);
    });

    test('usa distancia de Levenshtein solo con 6+ letras', () {
      // 1 letra distinta en una palabra larga: acepta
      expect(localJudge('strawberry', ['strawbarry']), isTrue);
      // en una palabra corta no se aplica
      expect(localJudge('cat', ['cap']), isFalse);
      expect(localJudge('cat', ['cut']), isFalse);
    });

    test('rechaza palabras distintas y listas vacías', () {
      expect(localJudge('dog', ['banana']), isFalse);
      expect(localJudge('dog', const []), isFalse);
      expect(localJudge('dog', ['']), isFalse);
    });

    test('mira todas las alternativas', () {
      expect(localJudge('apple', ['a pull', 'apple', 'ample']), isTrue);
    });
  });

  group('phoneticKey', () {
    test('mantiene las vocales para distinguir dog de dug', () {
      expect(phoneticKey('dog') == phoneticKey('dug'), isFalse);
    });

    test('unifica variantes de escritura', () {
      expect(phoneticKey('elephant'), phoneticKey('elefant'));
      expect(phoneticKey('strawberry'), phoneticKey('strawbery'));
    });
  });
}
