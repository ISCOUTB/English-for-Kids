import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/api_client.dart';
import '../../core/config.dart';
import 'story.dart';

/// Crear un cuento tarda varios segundos: la IA escribe el texto.
const Duration kCreateStoryTimeout = Duration(seconds: 45);

/// La primera vez, el servidor también genera la voz (puede tardar bastante).
const Duration kStoryAudioTimeout = Duration(seconds: 60);

/// Mensaje amable para mostrar al niño o al tutor (nunca técnico).
String friendlyStoryError(ApiException e) {
  if (e.isNetwork) return e.message;
  switch (e.statusCode) {
    case 429:
      return 'Hoy ya hicimos muchos cuentos. ¡Mañana hacemos más!';
    case 422:
      return 'Alguna palabra no sirvió para el cuento. Prueba con otras.';
    case 502:
    case 503:
      return 'No pudimos crear el cuento ahora. Inténtalo en un ratito.';
    default:
      return e.message;
  }
}

class StoriesService {
  StoriesService(this._api, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final ApiClient _api;
  final http.Client _http;

  Future<List<Story>> list(int childId) async {
    final data = await _api.get('/stories?nino_id=$childId');
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Story.fromJson)
          .toList();
    }
    throw ApiException('Respuesta inesperada del servidor.');
  }

  Future<Story> create({
    required int childId,
    required List<String> words,
    String? contexto,
    String language = 'es',
  }) async {
    final data = await _api.post(
      '/stories',
      body: {
        'nino_id': childId,
        'palabras': words,
        'contexto': contexto,
        'idioma': language,
      },
      timeout: kCreateStoryTimeout,
    );
    if (data is Map<String, dynamic>) return Story.fromJson(data);
    throw ApiException('Respuesta inesperada del servidor.');
  }

  /// Descarga la narración (mp3). Este endpoint exige el token, y el
  /// reproductor no puede enviar cabeceras: por eso se baja como bytes.
  Future<Uint8List> audio(int storyId) async {
    final http.Response res;
    try {
      res = await _http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/stories/$storyId/audio'),
        headers: {
          if (_api.token != null) 'Authorization': 'Bearer ${_api.token}',
          'Accept': 'audio/mpeg',
        },
      ).timeout(kStoryAudioTimeout);
    } on TimeoutException {
      throw ApiException(
        'La voz tardó demasiado en llegar. Intenta de nuevo.',
        isNetwork: true,
      );
    } on SocketException {
      throw ApiException(
        'No hay conexión a internet. Revisa tu red e intenta de nuevo.',
        isNetwork: true,
      );
    } on http.ClientException {
      throw ApiException(
        'No pudimos conectar con el servidor. Intenta de nuevo.',
        isNetwork: true,
      );
    }

    if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) return res.bodyBytes;

    if (res.statusCode == 401 && _api.token != null) {
      _api.onUnauthorized?.call();
    }
    throw ApiException(_audioMessage(res.statusCode), statusCode: res.statusCode);
  }

  String _audioMessage(int status) {
    if (status == 404) return 'No encontramos ese cuento.';
    if (status >= 500) {
      return 'No pudimos preparar la voz ahora. Inténtalo en un ratito.';
    }
    return 'No se pudo preparar la voz (código $status).';
  }
}
