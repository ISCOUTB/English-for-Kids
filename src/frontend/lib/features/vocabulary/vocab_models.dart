String? _clean(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Una palabra del vocabulario.
/// [image] y [audio] son nombres de archivo dentro de assets/images/ y
/// assets/audio/. [emoji] se muestra si la imagen no existe.
class Word {
  const Word({
    required this.id,
    required this.en,
    this.image,
    this.audio,
    this.emoji,
  });

  final String id;
  final String en;
  final String? image;
  final String? audio;
  final String? emoji;

  factory Word.fromJson(Map<String, dynamic> json) {
    final en = (json['en'] ?? json['word'] ?? json['id'] ?? '').toString();
    return Word(
      id: (json['id'] ?? en).toString(),
      en: en,
      image: _clean(json['image']),
      audio: _clean(json['audio']),
      emoji: _clean(json['emoji']),
    );
  }
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

  factory VocabCategory.fromJson(Map<String, dynamic> json) {
    final rawWords = (json['words'] as List?) ?? const [];
    return VocabCategory(
      id: (json['id'] ?? json['name'] ?? '').toString(),
      name: (json['name'] ?? json['id'] ?? '').toString(),
      emoji: _clean(json['emoji']),
      cover: _clean(json['cover']),
      words: rawWords
          .whereType<Map<String, dynamic>>()
          .map(Word.fromJson)
          .where((w) => w.en.isNotEmpty)
          .toList(),
    );
  }
}
