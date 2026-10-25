import '../../core/api_client.dart';
import 'study_config.dart';

/// Segunda opinión del servidor. Solo recibe TEXTO, nunca audio.
class SpeechJudgeService {
  SpeechJudgeService(this._api);

  final ApiClient _api;

  /// true si el servidor responde "acierto". Lanza ApiException si falla.
  Future<bool> judge({
    required int childId,
    required String word,
    required List<String> heard,
  }) async {
    final data = await _api.post(
      '/speech/judge',
      body: {
        'nino_id': childId,
        'palabra': word,
        'escuchado': heard.take(kMaxAlternatives).toList(),
      },
      timeout: kJudgeTimeout,
    );
    return data is Map && data['resultado'] == 'acierto';
  }
}
