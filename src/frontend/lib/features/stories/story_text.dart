import '../vocabulary/vocab_models.dart';

/// Máximo de palabras por cuento (el servidor rechaza más de 8).
const int kMaxStoryWords = 8;

/// Trozo de texto del cuento. Si [word] no es null, es una palabra del
/// vocabulario (en minúsculas) que se resalta y se puede tocar.
class TextChunk {
  const TextChunk(this.text, {this.word});

  final String text;
  final String? word;

  bool get isWord => word != null;
}

// Letras de cualquier idioma, con apóstrofes o guiones SOLO en medio.
final RegExp _tokenPattern =
    RegExp(r"[\p{L}]+(?:['’\-][\p{L}]+)*", unicode: true);

// Mismas reglas que el servidor: solo letras, espacios, guiones o apóstrofes
// en medio, y máximo 30 caracteres.
final RegExp _storyWordPattern =
    RegExp(r"^[\p{L}]+(?:[ '\-][\p{L}]+)*$", unicode: true);

/// true si el servidor aceptaría esta palabra para un cuento.
bool isValidStoryWord(String word) {
  final clean = word.trim();
  return clean.isNotEmpty &&
      clean.length <= 30 &&
      _storyWordPattern.hasMatch(clean);
}

/// Divide [text] en trozos normales y trozos resaltados.
/// [highlight] son palabras en minúsculas (las del vocabulario).
List<TextChunk> splitStoryText(String text, Set<String> highlight) {
  final chunks = <TextChunk>[];
  final buffer = StringBuffer();

  void flush() {
    if (buffer.isNotEmpty) {
      chunks.add(TextChunk(buffer.toString()));
      buffer.clear();
    }
  }

  var cursor = 0;
  for (final match in _tokenPattern.allMatches(text)) {
    if (match.start > cursor) buffer.write(text.substring(cursor, match.start));
    final token = match.group(0)!;
    final key = token.toLowerCase();
    if (highlight.contains(key)) {
      flush();
      chunks.add(TextChunk(token, word: key));
    } else {
      buffer.write(token);
    }
    cursor = match.end;
  }
  if (cursor < text.length) buffer.write(text.substring(cursor));
  flush();
  return chunks;
}

/// Párrafos del cuento (el servidor los separa con una línea en blanco).
List<String> splitParagraphs(String text) {
  return text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}

/// Palabra en inglés (minúsculas) -> palabra del vocabulario.
Map<String, Word> vocabularyIndex(List<VocabCategory> categories) {
  final index = <String, Word>{};
  for (final category in categories) {
    for (final word in category.words) {
      index.putIfAbsent(word.en.toLowerCase(), () => word);
    }
  }
  return index;
}
