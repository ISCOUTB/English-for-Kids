/// Avatares disponibles. En el servidor se guarda la clave (por ejemplo "zorro").
const Map<String, String> kAvatars = {
  'zorro': '🦊',
  'leon': '🦁',
  'panda': '🐼',
  'conejo': '🐰',
  'rana': '🐸',
  'pulpo': '🐙',
  'unicornio': '🦄',
  'dino': '🦖',
};

String avatarEmoji(String key) => kAvatars[key] ?? '🙂';

/// Rangos de edad que ofrece la app.
const List<String> kAgeRanges = ['3-4', '5-6'];

String ageLabel(String range) => '${range.replaceAll('-', ' a ')} años';
