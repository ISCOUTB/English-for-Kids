/// Un cuento tal como lo devuelve el servidor (GET /stories).
class Story {
  const Story({
    required this.id,
    required this.ninoId,
    required this.titulo,
    required this.texto,
    required this.creadaEn,
    required this.audioListo,
  });

  final int id;
  final int ninoId;
  final String titulo;
  final String texto;
  final DateTime creadaEn;

  /// true si la narración ya se generó antes (abrirla es más rápido).
  final bool audioListo;

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: (json['id'] as num).toInt(),
      ninoId: (json['nino_id'] as num).toInt(),
      titulo: (json['titulo'] ?? '').toString(),
      texto: (json['texto'] ?? '').toString(),
      creadaEn: DateTime.tryParse((json['creada_en'] ?? '').toString())
              ?.toLocal() ??
          DateTime.now(),
      audioListo: json['audio_listo'] == true,
    );
  }
}

/// Fecha amable para niños y tutores: "hoy", "ayer", "hace 3 días"...
String describeAge(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  // Se compara en UTC para que un cambio de horario no mueva el resultado.
  final today = DateTime.utc(current.year, current.month, current.day);
  final day = DateTime.utc(date.year, date.month, date.day);
  final days = today.difference(day).inDays;

  if (days <= 0) return 'hoy';
  if (days == 1) return 'ayer';
  if (days < 7) return 'hace $days días';
  if (days < 14) return 'hace 1 semana';
  if (days < 30) return 'hace ${days ~/ 7} semanas';

  final dd = day.day.toString().padLeft(2, '0');
  final mm = day.month.toString().padLeft(2, '0');
  return '$dd/$mm/${day.year}';
}
