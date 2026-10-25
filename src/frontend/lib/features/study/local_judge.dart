/// Juez local de pronunciación: rápido, gratis y sin internet.

/// Palabras que el reconocedor suele escribir distinto pero suenan igual.
const Map<String, List<String>> kAliases = {
  'red': ['read'],
  'blue': ['blew'],
  'pear': ['pair', 'pare'],
  'white': ['wight'],
};

/// Minúsculas, sin tildes ni signos, con espacios simples.
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

/// Clave fonética simplificada del inglés.
///
/// A diferencia de Metaphone, CONSERVA las vocales: con Metaphone "dug" y
/// "dog" tendrían la misma clave y se aceptaría "dug" para "dog".
/// Sirve para variantes de escritura como "elefant" / "elephant".
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

String _singular(String w) {
  if (w.length > 3 && w.endsWith('s')) return w.substring(0, w.length - 1);
  return w;
}

/// true si alguna de las alternativas que escuchó el teléfono cuenta como
/// acierto para la palabra [target].
bool localJudge(String target, List<String> alternatives) {
  final t = normalizeText(target);
  if (t.isEmpty) return false;

  final tSingular = _singular(t);
  final tCompact = t.replaceAll(' ', '');
  final tKey = phoneticKey(t);
  final aliases = (kAliases[t] ?? const <String>[]).map(normalizeText).toSet();

  for (final raw in alternatives) {
    final alt = normalizeText(raw);
    if (alt.isEmpty) continue;
    final tokens = alt.split(' ');

    // a) igual, o la contiene como palabra completa
    if (alt == t || ' $alt '.contains(' $t ')) return true;
    // singular / plural ("dog" - "dogs")
    if (tokens.any((w) => _singular(w) == tSingular)) return true;
    // separada por espacios ("egg plant")
    if (alt.replaceAll(' ', '') == tCompact) return true;

    // b) alias conocido
    if (aliases.contains(alt) || tokens.any(aliases.contains)) return true;

    // c) misma clave fonética
    if (phoneticKey(alt) == tKey || tokens.any((w) => phoneticKey(w) == tKey)) {
      return true;
    }

    // d) parecido por distancia, solo en palabras de 6 letras o más
    if (t.length >= 6) {
      if (similarity(alt, t) >= 0.8) return true;
      if (tokens.any((w) => similarity(w, t) >= 0.8)) return true;
    }
  }
  return false;
}
