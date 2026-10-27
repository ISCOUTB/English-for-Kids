/// Resultados por idioma de una palabra.
class LangStats {
  const LangStats({this.intentos = 0, this.aciertos = 0});

  final int intentos;
  final int aciertos;

  factory LangStats.fromJson(Object? json) {
    if (json is! Map) return const LangStats();
    return LangStats(
      intentos: (json['intentos'] as num?)?.toInt() ?? 0,
      aciertos: (json['aciertos'] as num?)?.toInt() ?? 0,
    );
  }
}

enum WordState { dominada, practicando, reforzar }

WordState _parseState(Object? value) {
  switch (value) {
    case 'dominada':
      return WordState.dominada;
    case 'reforzar':
      return WordState.reforzar;
    default:
      return WordState.practicando;
  }
}

class WordProgress {
  const WordProgress({
    required this.palabra,
    required this.estado,
    required this.intentos,
    required this.aciertos,
    required this.asistidos,
    required this.en,
    required this.es,
    required this.ultimaPractica,
  });

  /// Nombre de la palabra en inglés (identificador).
  final String palabra;
  final WordState estado;
  final int intentos;
  final int aciertos;
  final int asistidos;
  final LangStats en;
  final LangStats es;
  final DateTime ultimaPractica;

  factory WordProgress.fromJson(Map<String, dynamic> json) {
    return WordProgress(
      palabra: (json['palabra'] ?? '').toString(),
      estado: _parseState(json['estado']),
      intentos: (json['intentos'] as num?)?.toInt() ?? 0,
      aciertos: (json['aciertos'] as num?)?.toInt() ?? 0,
      asistidos: (json['asistidos'] as num?)?.toInt() ?? 0,
      en: LangStats.fromJson(json['en']),
      es: LangStats.fromJson(json['es']),
      ultimaPractica:
          DateTime.tryParse((json['ultima_practica'] ?? '').toString())?.toLocal() ??
              DateTime.now(),
    );
  }
}

class DayStats {
  const DayStats({
    required this.fecha,
    required this.intentos,
    required this.aciertos,
  });

  /// Día (a medianoche, hora local del tutor).
  final DateTime fecha;
  final int intentos;
  final int aciertos;

  factory DayStats.fromJson(Map<String, dynamic> json) {
    return DayStats(
      fecha: DateTime.tryParse((json['fecha'] ?? '').toString()) ?? DateTime.now(),
      intentos: (json['intentos'] as num?)?.toInt() ?? 0,
      aciertos: (json['aciertos'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProgressSummary {
  const ProgressSummary({
    required this.ninoId,
    required this.totalIntentos,
    required this.totalAciertos,
    required this.aciertosAsistidos,
    required this.palabrasPracticadas,
    required this.palabrasDominadas,
    required this.palabrasPorReforzar,
    required this.diasActivosSemana,
    required this.rachaDias,
    required this.ultimosDias,
    required this.palabras,
  });

  final int ninoId;
  final int totalIntentos;
  final int totalAciertos;
  final int aciertosAsistidos;
  final int palabrasPracticadas;
  final int palabrasDominadas;
  final int palabrasPorReforzar;
  final int diasActivosSemana;
  final int rachaDias;
  final List<DayStats> ultimosDias;
  final List<WordProgress> palabras;

  bool get isEmpty => totalIntentos == 0;

  List<WordProgress> wordsIn(WordState state) =>
      palabras.where((w) => w.estado == state).toList();

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw.whereType<Map<String, dynamic>>().map(parse).toList();
    }

    return ProgressSummary(
      ninoId: n('nino_id'),
      totalIntentos: n('total_intentos'),
      totalAciertos: n('total_aciertos'),
      aciertosAsistidos: n('aciertos_asistidos'),
      palabrasPracticadas: n('palabras_practicadas'),
      palabrasDominadas: n('palabras_dominadas'),
      palabrasPorReforzar: n('palabras_por_reforzar'),
      diasActivosSemana: n('dias_activos_semana'),
      rachaDias: n('racha_dias'),
      ultimosDias: list('ultimos_dias', DayStats.fromJson),
      palabras: list('palabras', WordProgress.fromJson),
    );
  }
}
