import '../../core/api_client.dart';
import 'study_config.dart';

/// Segunda opinión del servidor. Solo recibe TEXTO, nunca audio.
class SpeechJudgeService {
  SpeechJudgeService(this._api);

  final ApiClient _api;

  /// [word] es la palabra EN ESE IDIOMA (por ejemplo "manzana" para es).
  /// true si el servidor responde "acierto". Lanza ApiException si falla.
  Future<bool> judge({
    required int childId,
    required String word,
    required Lang lang,
    required List<String> heard,
  }) async {
    final data = await _api.post(
      '/speech/judge',
      body: {
        'nino_id': childId,
        'palabra': word,
        'idioma': lang.name,
        'escuchado': heard.take(kMaxAlternatives).toList(),
      },
      timeout: kJudgeTimeout,
    );
    return data is Map && data['resultado'] == 'acierto';
  }
}
