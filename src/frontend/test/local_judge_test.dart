import 'package:english_for_kids/features/study/local_judge.dart';
import 'package:english_for_kids/features/study/study_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const en = Lang.en;
  const es = Lang.es;
  const young = AgeBand.young; // 3-4 años
  const older = AgeBand.older; // 5-6 años

  group('ageBandFor', () {
    test('3-4 es young y 5-6 es older', () {
      expect(ageBandFor('3-4'), AgeBand.young);
      expect(ageBandFor('5-6'), AgeBand.older);
      expect(ageBandFor('otra cosa'), AgeBand.older);
    });
  });

  group('normalizeText', () {
    test('quita tildes y signos; la ñ cuenta como n', () {
      expect(normalizeText('  ¡Árbol!  '), 'arbol');
      expect(normalizeText('niño'), 'nino');
      expect(normalizeText("It's  A   Dog."), 'it s a dog');
    });
  });

  group('inglés - 5 a 6 años', () {
    bool judge(String target, List<String> heard) =>
        localJudge(target, heard, lang: en, band: older);

    test('acepta exacta, con signos y dentro de una frase', () {
      expect(judge('dog', ['dog']), isTrue);
      expect(judge('dog', ['Dog!']), isTrue);
      expect(judge('dog', ['the dog']), isTrue);
      expect(judge('dog', ['hot dog please']), isTrue);
    });

    test('NO acepta "dug" para "dog" (lo manda al backend)', () {
      expect(judge('dog', ['dug']), isFalse);
    });

    test('NO acepta si solo está dentro de otra palabra', () {
      expect(judge('dog', ['dogma']), isFalse);
    });

    test('singular, plural y palabras separadas', () {
      expect(judge('bananas', ['banana']), isTrue);
      expect(judge('dog', ['dogs']), isTrue);
      expect(judge('eggplant', ['egg plant']), isTrue);
      expect(judge('toothbrush', ['tooth brush']), isTrue);
    });

    test('alias conocidos', () {
      expect(judge('red', ['read']), isTrue);
      expect(judge('pear', ['pair']), isTrue);
    });

    test('"elefant" acepta "elephant"', () {
      expect(judge('elephant', ['elefant']), isTrue);
    });

    test('similitud en palabras de 4+ letras', () {
      expect(judge('strawberry', ['strawbarry']), isTrue); // 0.9 >= 0.8
      expect(judge('ball', ['bell']), isTrue); // 0.75 >= 0.75
      expect(judge('apple', ['apricot']), isFalse);
    });

    test('las palabras de 3 letras solo exactas o por clave fonética', () {
      expect(judge('cat', ['cap']), isFalse);
      expect(judge('cat', ['cut']), isFalse);
    });

    test('rechaza lo distinto y las listas vacías', () {
      expect(judge('dog', ['banana']), isFalse);
      expect(judge('dog', const []), isFalse);
      expect(judge('dog', ['']), isFalse);
    });

    test('mira todas las alternativas', () {
      expect(judge('apple', ['a pull', 'apple', 'ample']), isTrue);
    });
  });

  group('inglés - 3 a 4 años (muy indulgente)', () {
    bool judge(String target, List<String> heard) =>
        localJudge(target, heard, lang: en, band: young);

    test('"dog" acepta "dug" a los 3-4 años pero no a los 5-6', () {
      expect(judge('dog', ['dug']), isTrue);
      expect(localJudge('dog', ['dug'], lang: en, band: older), isFalse);
    });

    test('sigue rechazando palabras con otras consonantes', () {
      expect(judge('dog', ['dock']), isFalse);
      expect(judge('dog', ['banana']), isFalse);
    });

    test('acepta el sonido inicial y partes de la palabra', () {
      expect(judge('apple', ['apricot']), isTrue); // mismas 2 primeras letras
      expect(judge('tomato', ['tom']), isTrue); // parte de la palabra
    });

    test('ignora muletillas como "the"', () {
      expect(judge('tree', ['the']), isFalse);
      expect(judge('cat', ['the']), isFalse);
    });
  });

  group('español', () {
    bool judge(String target, List<String> heard,
            {AgeBand band = older}) =>
        localJudge(target, heard, lang: es, band: band);

    test('"manzana" acepta "mansana" (z = s)', () {
      expect(judge('manzana', ['mansana']), isTrue);
      expect(judge('manzana', ['mansana'], band: young), isTrue);
    });

    test('"manzana" acepta "man" solo a los 3-4 años', () {
      expect(judge('manzana', ['man'], band: young), isTrue);
      expect(judge('manzana', ['man']), isFalse);
    });

    test('acepta la palabra dentro de una frase y con artículo', () {
      expect(judge('manzana', ['la manzana']), isTrue);
      expect(judge('pelota', ['la pelota']), isTrue);
      expect(judge('pelota', ['una pelota']), isTrue);
    });

    test('plurales', () {
      expect(judge('manzana', ['manzanas']), isTrue);
      expect(judge('pantalones', ['pantalon']), isTrue);
      expect(judge('flores', ['flor']), isTrue);
    });

    test('equivalencias fonéticas del español', () {
      expect(judge('bota', ['vota']), isTrue); // b = v
      expect(judge('llamada', ['yamada']), isTrue); // ll = y
      expect(judge('zapato', ['sapato']), isTrue); // z = s
      expect(judge('cereza', ['sereza']), isTrue); // c suave = s
      expect(judge('abrazo', ['avraso']), isTrue);
      expect(judge('cohete', ['kohete']), isTrue); // c = k, h muda
      expect(judge('carro', ['caro']), isTrue); // rr = r
    });

    test('tildes, ñ y varias palabras', () {
      expect(judge('árbol', ['arbol']), isTrue);
      expect(
        judge('cepillo de dientes', ['cepillo de dientes']),
        isTrue,
      );
    });

    test('rechaza palabras distintas', () {
      expect(judge('manzana', ['banana']), isFalse);
      expect(judge('pelota', ['pelea']), isFalse);
    });
  });

  group('claves fonéticas', () {
    test('inglés: mantiene las vocales y unifica variantes', () {
      expect(phoneticKey('dog') == phoneticKey('dug'), isFalse);
      expect(phoneticKey('elephant'), phoneticKey('elefant'));
      expect(phoneticKey('strawberry'), phoneticKey('strawbery'));
    });

    test('inglés: el esqueleto de consonantes iguala "dog" y "dug"', () {
      expect(
        consonantSkeleton(phoneticKey('dog')),
        consonantSkeleton(phoneticKey('dug')),
      );
    });

    test('español', () {
      expect(phoneticKeyEs('hola'), phoneticKeyEs('ola'));
      expect(phoneticKeyEs('guerra'), phoneticKeyEs('guera'));
      expect(phoneticKeyEs('queso'), phoneticKeyEs('keso'));
      expect(phoneticKeyEs('gente'), phoneticKeyEs('jente'));
      // g suave y g fuerte no son lo mismo
      expect(phoneticKeyEs('guerra') == phoneticKeyEs('gerra'), isFalse);
    });
  });
}
