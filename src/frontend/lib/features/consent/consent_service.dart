import '../../core/api_client.dart';
import 'consent.dart';

class ConsentService {
  ConsentService(this._api);

  final ApiClient _api;

  Future<List<Consent>> list() async {
    final data = await _api.get('/consents');
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Consent.fromJson)
          .toList();
    }
    throw ApiException('Respuesta inesperada del servidor.');
  }

  /// Registra una decisión nueva: true acepta, false revoca.
  Future<Consent> setVoice(bool aceptado) async {
    final data = await _api.post(
      '/consents',
      body: {'tipo': 'voz', 'aceptado': aceptado},
    );
    if (data is Map<String, dynamic>) return Consent.fromJson(data);
    throw ApiException('Respuesta inesperada del servidor.');
  }
}
