import 'study_config.dart';

/// Juez local de pronunciación: rápido, gratis y sin internet.

/// Rango de edad del niño.
enum AgeBand { young, older }

/// "3-4" -> young (muy indulgente); "5-6" o desconocido -> older.
AgeBand ageBandFor(String rangoEdad) =>
    rangoEdad.trim().startsWith('3') ? AgeBand.young : AgeBand.older;

/// Palabras que el reconocedor suele escribir distinto pero suenan igual.
const Map<String, List<String>> kAliases = {
  'red': ['read'],
  'blue': ['blew'],
  'pear': ['pair', 'pare'],
  'white': ['wight'],
};

/// Muletillas que el reconocedor devuelve con ruido: no cuentan en las
/// reglas flexibles.
const Set<String> _fillers = {
  'the', 'a', 'an', 'uh', 'um', 'oh', 'i', 'it', 'is', 'to', 'and', 'of',
  'mm', 'hmm', 'ah', 'eh', 'la', 'el', 'los', 'las', 'un', 'una', 'de', 'y',
  'en', 'que', 'es',
};

/// Minúsculas, sin tildes (la ñ cuenta como n), sin signos, espacios simples.
String normalizeText(String input) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final buffer = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Clave fonética simplificada del INGLÉS. Conserva las vocales
/// ("dog" y "dug" son distintas); sirve para variantes de escritura como
/// "elefant" / "elephant".
String phoneticKey(String word) {
  var s = normalizeText(word).replaceAll(' ', '');
  s = s
      .replaceAll('ph', 'f')
      .replaceAll('ck', 'k')
      .replaceAll('qu', 'kw')
      .replaceAll('x', 'ks')
      .replaceAll('z', 's')
      .replaceAll('ee', 'i')
      .replaceAll('oo', 'u');
  s = s.replaceFirst(RegExp(r'^kn'), 'n').replaceFirst(RegExp(r'^wr'), 'r');
  s = s.replaceAllMapped(RegExp(r'c(?=[eiy])'), (_) => 's');
  s = s.replaceAllMapped(RegExp(r'c(?!h)'), (_) => 'k');
  s = s.replaceFirst(RegExp(r'y$'), 'i');
  s = s.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
  return s;
}

/// Clave fonética del ESPAÑOL: b=v, ll=y, h muda, c/k/qu, z=s=c suave,
/// g/j suaves, rr=r.
String phoneticKeyEs(String word) {
  var s = normalizeText(word).replaceAll(' ', '');
  s = s.replaceAll('ch', '#').replaceAll('h', '');
  s = s.replaceAll('ll', 'y');
  s = s.replaceAll('qu', 'k');
  s = s.replaceAllMapped(RegExp(r'g(?=[ei])'), (_) => 'j'); // g suave
  s = s.replaceAllMapped(RegExp(r'gu(?=[ei])'), (_) => 'g'); // gue, gui
  s = s.replaceAllMapped(RegExp(r'c(?=[ei])'), (_) => 's'); // c suave
  s = s.replaceAll('c', 'k').replaceAll('q', 'k');
  s = s.replaceAll('z', 's').replaceAll('v', 'b');
  s = s.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!); // rr -> r, etc.
  return s;
}

/// Solo las consonantes de una clave (la vocal inicial se marca con *).
/// Es la forma más indulgente de comparar: "dog" y "dug" dan lo mismo.
String consonantSkeleton(String key) {
  final b = StringBuffer();
  for (var i = 0; i < key.length; i++) {
    final c = key[i];
    if ('aeiou'.contains(c)) {
      if (i == 0) b.write('*');
    } else {
      b.write(c);
    }
  }
  return b.toString().replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final curr = List<int>.filled(b.length + 1, 0);
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      final del = prev[j] + 1;
      final ins = curr[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      curr[j] = [del, ins, sub].reduce((x, y) => x < y ? x : y);
    }
    prev = curr;
  }
  return prev[b.length];
}

double similarity(String a, String b) {
  final longest = a.length > b.length ? a.length : b.length;
  if (longest == 0) return 1;
  return 1 - levenshtein(a, b) / longest;
}

/// Formas de una palabra sin plural: "dogs" -> dog, "flores" -> flor.
Set<String> _forms(String w) {
  final forms = <String>{w};
  if (w.length > 3 && w.endsWith('s')) forms.add(w.substring(0, w.length - 1));
  if (w.length > 4 && w.endsWith('es')) forms.add(w.substring(0, w.length - 2));
  return forms;
}

/// true si alguna de las alternativas que escuchó el teléfono cuenta como
/// acierto para [target] (la palabra en el idioma [lang]).
///
/// Reglas para todos: igual o contenida como palabra completa ("la manzana"),
/// singular/plural, palabra separada por espacios, alias y misma clave
/// fonética. Las palabras de 3 letras solo usan esas reglas.
///
/// Según la edad, en palabras de 4+ letras:
/// - 3-4 años: sonido inicial compartido, parte de la palabra (3+ letras) o
///   similitud >= 0.7. Además la clave fonética ignora las vocales.
/// - 5-6 años: similitud >= 0.75 (>= 0.8 en palabras de 6+ letras).
bool localJudge(
  String target,
  List<String> alternatives, {
  Lang lang = Lang.en,
  AgeBand band = AgeBand.older,
}) {
  final t = normalizeText(target);
  if (t.isEmpty) return false;

  String keyOf(String s) => lang == Lang.en ? phoneticKey(s) : phoneticKeyEs(s);

  final tCompact = t.replaceAll(' ', '');
  final tForms = _forms(t);
  final tKey = keyOf(t);
  final tSkeleton = consonantSkeleton(tKey);
  final aliases = lang == Lang.en
      ? (kAliases[t] ?? const <String>[]).map(normalizeText).toSet()
      : <String>{};

  final young = band == AgeBand.young;
  final loose = tCompact.length >= 4;
  final threshold = young ? 0.7 : (tCompact.length >= 6 ? 0.8 : 0.75);

  for (final raw in alternatives) {
    final alt = normalizeText(raw);
    if (alt.isEmpty) continue;
    final tokens = alt.split(' ');
    final altCompact = alt.replaceAll(' ', '');

    // Igual, o la contiene como palabra completa ("la manzana")
    if (alt == t || ' $alt '.contains(' $t ')) return true;
    // Singular / plural
    if (tokens.any((w) => _forms(w).any(tForms.contains))) return true;
    // Separada por espacios ("egg plant")
    if (altCompact == tCompact) return true;
    // Alias conocidos
    if (aliases.contains(alt) || tokens.any(aliases.contains)) return true;

    // Misma clave fonética
    final keys = <String>{keyOf(alt), ...tokens.map(keyOf)};
    if (keys.contains(tKey)) return true;
    if (young &&
        tSkeleton.length >= 2 &&
        keys.any((k) => consonantSkeleton(k) == tSkeleton)) {
      return true;
    }

    if (!loose) continue;

    // Parecido por distancia
    final words =
        tokens.where((w) => w.length >= 2 && !_fillers.contains(w)).toList();
    final candidates = <String>{altCompact, ...words};
    if (candidates.any((c) => similarity(c, tCompact) >= threshold)) return true;

    if (young) {
      for (final w in words) {
        final k = keyOf(w);
        // Mismo sonido inicial: 2 primeras letras o misma consonante inicial
        if (k.length >= 2 && tKey.length >= 2 &&
            k.substring(0, 2) == tKey.substring(0, 2)) {
          return true;
        }
        if (k.isNotEmpty && !'aeiou'.contains(tKey[0]) && k[0] == tKey[0]) {
          return true;
        }
        // Parte de la palabra ("man" para "manzana")
        if (w.length >= 3 &&
            (tCompact.contains(w) || (k.length >= 3 && tKey.contains(k)))) {
          return true;
        }
      }
    }
  }
  return false;
}
