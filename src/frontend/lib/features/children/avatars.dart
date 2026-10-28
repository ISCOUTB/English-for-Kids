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

/// Ya no se pregunta la edad al crear el perfil: se usa el rango más pequeño,
/// que es el más tolerante al juzgar la pronunciación.
const String kDefaultAgeRange = '3-4';

String ageLabel(String range) => '${range.replaceAll('-', ' a ')} años';
