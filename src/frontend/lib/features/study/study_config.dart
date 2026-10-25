/// Idioma que habla cada personaje.
enum Lang { en, es }

/// Qué personaje habla cada idioma. Cambia aquí la asignación
/// (las carpetas están en assets/personajes/).
const Map<Lang, String> kCharacterFolder = {
  Lang.en: 'nino',
  Lang.es: 'nina',
};

/// Cada cuánto cambia la boca mientras suena el audio.
const Duration kMouthFrameInterval = Duration(milliseconds: 120);

/// Orden de los cuadros de la boca: 1 cerrada, 2 media, 3 abierta.
const List<int> kMouthSequence = [1, 2, 3, 2];

/// Sonido de éxito (ruta relativa a assets/).
const String kSuccessSound = 'audio/ingles/success.mp3';

const int kMaxAlternatives = 5;
const Duration kJudgeTimeout = Duration(seconds: 3);
