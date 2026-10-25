import 'package:flutter/foundation.dart';

class Attempt {
  const Attempt({
    required this.word,
    required this.success,
    required this.at,
    this.childId,
  });

  final String word;
  final bool success;
  final DateTime at;
  final int? childId;
}

/// Guarda los intentos en memoria. En la sección 6 se conectará al backend.
class ProgressRepository {
  final List<Attempt> _attempts = [];

  List<Attempt> get attempts => List.unmodifiable(_attempts);

  void recordAttempt(String palabra, bool acierto, {int? childId}) {
    _attempts.add(
      Attempt(
        word: palabra,
        success: acierto,
        at: DateTime.now(),
        childId: childId,
      ),
    );
    debugPrint('📝 Intento: $palabra -> ${acierto ? 'acierto' : 'otra vez'}');
  }
}
