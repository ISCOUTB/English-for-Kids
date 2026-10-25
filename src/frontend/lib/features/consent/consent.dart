class Consent {
  const Consent({
    required this.id,
    required this.tipo,
    required this.aceptado,
    this.fecha,
  });

  final int id;
  final String tipo;
  final bool aceptado;
  final DateTime? fecha;

  factory Consent.fromJson(Map<String, dynamic> json) {
    return Consent(
      id: (json['id'] as num).toInt(),
      tipo: (json['tipo'] ?? '').toString(),
      aceptado: json['aceptado'] == true,
      fecha: DateTime.tryParse((json['fecha'] ?? '').toString())?.toLocal(),
    );
  }
}

String formatDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
