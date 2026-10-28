/// Idioma que habla cada personaje.
enum Lang { en, es }

/// Qué personaje habla cada idioma. Cambia aquí la asignación
/// (las carpetas están en assets/personajes/).
const Map<Lang, String> kCharacterFolder = {
  Lang.en: 'nina',
  Lang.es: 'nino',
};

/// Orden de izquierda a derecha en la pantalla de estudio.
const List<Lang> kLanguageOrder = [Lang.es, Lang.en];

// --- Tamaño de los personajes (ajustables) ---

/// Fracción de la altura del PNG que ocupa el personaje (el resto es margen
/// transparente). Con 677x369 el niño ocupa ~0.6. Si recortas los PNG justo al
/// personaje, pon 1.0.
const double kCharacterCanvasFill = 0.6;

/// Cuánto sobresale el personaje por arriba y por abajo del círculo
/// (fracción del diámetro del círculo).
const double kCharacterRise = 0.10;
const double kCharacterDrop = 0.08;

/// Cada cuánto cambia la boca mientras suena el audio.
const Duration kMouthFrameInterval = Duration(milliseconds: 120);

/// Orden de los cuadros de la boca: 1 cerrada, 2 media, 3 abierta.
const List<int> kMouthSequence = [1, 2, 3, 2];

const int kMaxAlternatives = 5;
const Duration kJudgeTimeout = Duration(seconds: 3);

// --- Reconocedor (pensado para niños pequeños) ---
const Duration kListenFor = Duration(seconds: 8);
const Duration kPauseFor = Duration(seconds: 3);

/// Nivel de sonido (escala de Android, aprox. -2 a 10) a partir del cual
/// se considera que el niño hizo ruido o balbuceó.
const double kSoundThreshold = 3.0;
const double kSoundMin = -2.0;
const double kSoundMax = 10.0;

// --- Flujo inglés <-> español ---

/// Fallos seguidos (misma palabra e idioma) tras los que cuenta como acierto
/// asistido.
const int kAssistedAfter = 3;

/// Audio al acertar en inglés (está en la carpeta de INGLÉS). Rutas relativas
/// a assets/. Si el archivo no existe, se salta el audio y el flujo sigue.
const String kTransitionToSpanish = 'audio/ingles/in_Spanish.mp3';

/// Audio al acertar en español (está en la carpeta de ESPAÑOL).
const String kTransitionToEnglish = 'audio/espanol/ahora_ingles.mp3';

/// Sonidos de la celebración completa de una palabra, en este orden.
const List<String> kCompleteSounds = [
  'audio/ingles/success.mp3',
  'audio/ingles/winning_star.mp3',
];

/// Cuánto dura la celebración breve antes del audio de transición.
const Duration kShortCelebration = Duration(milliseconds: 1200);
