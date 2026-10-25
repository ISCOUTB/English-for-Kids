import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.isNetwork = false});

  final String message;
  final int? statusCode;

  /// true cuando no se pudo llegar al servidor (sin internet, tiempo agotado).
  final bool isNetwork;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Cliente HTTP único de la app. Añade el token y traduce los errores.
class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  /// Token JWT de la sesión actual (null si no hay sesión).
  String? token;

  /// Se llama cuando el servidor responde 401 con una sesión activa.
  void Function()? onUnauthorized;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path) {
    return _send(() => _http.get(_uri(path), headers: _headers));
  }

  Future<dynamic> post(String path, {Object? body}) {
    return _send(
      () => _http.post(_uri(path), headers: _headers, body: jsonEncode(body)),
    );
  }

  Future<dynamic> delete(String path) {
    return _send(() => _http.delete(_uri(path), headers: _headers));
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response res;
    try {
      res = await request().timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException(
        'El servidor tardó demasiado en responder. Intenta de nuevo.',
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

    dynamic decoded;
    if (res.bodyBytes.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(res.bodyBytes));
      } on FormatException {
        decoded = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;

    if (res.statusCode == 401 && token != null) {
      onUnauthorized?.call();
    }
    throw ApiException(
      _errorMessage(res.statusCode, decoded),
      statusCode: res.statusCode,
    );
  }

  String _errorMessage(int status, dynamic body) {
    if (status == 422) {
      return 'Revisa que los datos sean válidos e intenta de nuevo.';
    }
    if (status >= 500) {
      return 'El servidor tuvo un problema. Intenta de nuevo más tarde.';
    }
    if (body is Map && body['detail'] is String) {
      return body['detail'] as String;
    }
    return 'No se pudo completar la solicitud (código $status).';
  }
}
