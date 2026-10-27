import '../../core/api_client.dart';
import '../study/progress_repository.dart';
import 'progress_models.dart';

/// Habla con el módulo `progress` del servidor.
class ProgressService {
  ProgressService(this._api);

  final ApiClient _api;

  /// Envía un lote de intentos (el servidor acepta hasta 50 por llamada).
  Future<void> sendAttempts(int childId, List<Attempt> attempts) async {
    await _api.post(
      '/progress/attempts',
      body: {
        'nino_id': childId,
        'intentos': [
          for (final a in attempts)
            {
              'palabra': a.word,
              'idioma': a.language,
              'acierto': a.success,
              'asistido': a.assisted,
              'fecha': a.at.toUtc().toIso8601String(),
            },
        ],
      },
    );
  }

  Future<ProgressSummary> summary(int childId) async {
    // Para que los días y la racha cuenten en la hora del tutor, no en UTC.
    final offset = DateTime.now().timeZoneOffset.inMinutes;
    final data = await _api.get('/progress/$childId/summary?tz_offset_min=$offset');
    if (data is Map<String, dynamic>) return ProgressSummary.fromJson(data);
    throw ApiException('Respuesta inesperada del servidor.');
  }

  Future<void> reset(int childId) async {
    await _api.delete('/progress/$childId');
  }
}
