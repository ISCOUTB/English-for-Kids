import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../progress/progress_service.dart';

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

/// Máximo de intentos que se recuerdan en memoria.
const int kMaxStoredAttempts = 500;

/// Máximo de intentos esperando conexión; si se pasa, se descartan los más viejos.
const int kMaxPendingAttempts = 500;

/// El servidor acepta hasta 50 intentos por llamada.
const int kAttemptBatchSize = 50;

/// Guarda los intentos y los envía al servidor en segundo plano (módulo
/// `progress`). Si no hay conexión, quedan en cola y se reintentan después.
///
/// Limitación: la cola vive en memoria; si la app se cierra sin conexión, esos
/// intentos se pierden.
class ProgressRepository {
  ProgressRepository({ProgressService? service}) : _service = service;

  final ProgressService? _service;
  final List<Attempt> _attempts = [];
  final List<Attempt> _pending = [];
  Timer? _timer;
  bool _flushing = false;

  List<Attempt> get attempts => List.unmodifiable(_attempts);

  /// Intentos esperando ser enviados (de todos los niños).
  int get pendingCount => _pending.length;

  int pendingFor(int childId) =>
      _pending.where((a) => a.childId == childId).length;

  void recordAttempt(
    String palabra,
    String idioma,
    bool acierto,
    bool asistido, {
    int? childId,
  }) {
    final attempt = Attempt(
      word: palabra,
      language: idioma,
      success: acierto,
      assisted: asistido,
      at: DateTime.now(),
      childId: childId,
    );

    _attempts.add(attempt);
    if (_attempts.length > kMaxStoredAttempts) _attempts.removeAt(0);

    if (_service != null && childId != null) {
      _pending.add(attempt);
      if (_pending.length > kMaxPendingAttempts) _pending.removeAt(0);
      _scheduleFlush();
    }

    debugPrint(
      '📝 Intento: $palabra [$idioma] -> '
      '${acierto ? (asistido ? 'acierto asistido' : 'acierto') : 'otra vez'}',
    );
  }

  /// Espera un momento para enviar varios intentos juntos.
  void _scheduleFlush() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () => unawaited(flush()));
  }

  /// Envía lo pendiente. Nunca lanza errores: si falla, lo deja en cola.
  Future<void> flush() async {
    final service = _service;
    if (service == null || _flushing || _pending.isEmpty) return;

    _flushing = true;
    try {
      while (_pending.isNotEmpty) {
        final childId = _pending.first.childId!;
        final batch = _pending
            .where((a) => a.childId == childId)
            .take(kAttemptBatchSize)
            .toList();

        try {
          await service.sendAttempts(childId, batch);
        } on ApiException catch (e) {
          // Sin conexión o servidor caído: se queda en cola. Si el servidor
          // rechaza los datos (niño borrado, datos inválidos), se descartan
          // para no atascar la cola para siempre.
          if (!_shouldDrop(e)) return;
        } catch (_) {
          return;
        }
        _pending.removeWhere(batch.contains);
      }
    } finally {
      _flushing = false;
    }
  }

  bool _shouldDrop(ApiException e) {
    final status = e.statusCode;
    if (e.isNetwork || status == null) return false;
    if (status == 401 || status == 408 || status == 429) return false;
    return status >= 400 && status < 500;
  }

  /// Olvida lo que estaba pendiente de un niño (por ejemplo al borrar su progreso).
  void discardPending(int childId) {
    _pending.removeWhere((a) => a.childId == childId);
  }

  void dispose() {
    _timer?.cancel();
  }
}
