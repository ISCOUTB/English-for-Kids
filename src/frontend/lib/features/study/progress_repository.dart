import 'package:flutter/foundation.dart';

class Attempt {
  const Attempt({
    required this.word,
    required this.language,
    required this.success,
    required this.assisted,
    required this.at,
    this.childId,
  });

  /// Identificador de la palabra (su nombre en inglés).
  final String word;

  /// "en" o "es".
  final String language;
  final bool success;

  /// true si el acierto vino de 3 fallos seguidos (el tutor lo ve distinto).
  final bool assisted;
  final DateTime at;
  final int? childId;
}

/// Guarda los intentos en memoria. En la sección 6 se conectará al backend.
class ProgressRepository {
  final List<Attempt> _attempts = [];

  List<Attempt> get attempts => List.unmodifiable(_attempts);

  void recordAttempt(
    String palabra,
    String idioma,
    bool acierto,
    bool asistido, {
    int? childId,
  }) {
    _attempts.add(
      Attempt(
        word: palabra,
        language: idioma,
        success: acierto,
        assisted: asistido,
        at: DateTime.now(),
        childId: childId,
      ),
    );
    debugPrint(
      '📝 Intento: $palabra [$idioma] -> '
      '${acierto ? (asistido ? 'acierto asistido' : 'acierto') : 'otra vez'}',
    );
  }
}
