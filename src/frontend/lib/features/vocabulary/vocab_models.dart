/// Una palabra de estudio. Las rutas de audio son relativas a assets/
/// (por ejemplo 'audio/ingles/apple.mp3'); [image] es el nombre del archivo
/// dentro de assets/images/.
class Word {
  const Word({
    required this.id,
    required this.en,
    required this.es,
    this.image,
    this.audioEn,
    this.audioEs,
    this.emoji,
  });

  final String id;
  final String en;
  final String es;
  final String? image;
  final String? audioEn;
  final String? audioEs;
  final String? emoji;
}

class VocabCategory {
  const VocabCategory({
    required this.id,
    required this.name,
    required this.words,
    this.emoji,
    this.cover,
  });

  final String id;
  final String name;
  final String? emoji;

  /// Imagen de portada (archivo dentro de assets/images/). Opcional.
  final String? cover;
  final List<Word> words;
}
