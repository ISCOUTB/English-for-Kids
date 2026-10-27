import 'dart:convert';
import 'dart:math';

import 'package:english_for_kids/core/api_client.dart';
import 'package:english_for_kids/core/parental_gate.dart';
import 'package:english_for_kids/features/progress/progress_controller.dart';
import 'package:english_for_kids/features/progress/progress_models.dart';
import 'package:english_for_kids/features/progress/progress_service.dart';
import 'package:english_for_kids/features/study/progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _summaryJson = {
  'nino_id': 1,
  'total_intentos': 6,
  'total_aciertos': 4,
  'aciertos_asistidos': 1,
  'palabras_practicadas': 2,
  'palabras_dominadas': 1,
  'palabras_por_reforzar': 0,
  'dias_activos_semana': 2,
  'racha_dias': 2,
  'ultimos_dias': [
    {'fecha': '2026-10-26', 'intentos': 2, 'aciertos': 1},
    {'fecha': '2026-10-27', 'intentos': 4, 'aciertos': 3},
  ],
  'palabras': [
    {
      'palabra': 'apple',
      'estado': 'dominada',
      'intentos': 4,
      'aciertos': 3,
      'asistidos': 0,
      'en': {'intentos': 3, 'aciertos': 3},
      'es': {'intentos': 1, 'aciertos': 0},
      'ultima_practica': '2026-10-27T15:00:00Z',
    },
    {
      'palabra': 'cat',
      'estado': 'algo_raro',
      'intentos': 2,
      'aciertos': 1,
      'asistidos': 1,
      'en': {'intentos': 2, 'aciertos': 1},
      'es': {'intentos': 0, 'aciertos': 0},
      'ultima_practica': '2026-10-26T15:00:00Z',
    },
  ],
};

ProgressService _service(MockClient mock) => ProgressService(ApiClient(client: mock));

void main() {
  group('ProgressSummary', () {
    test('fromJson lee todo y tolera estados desconocidos', () {
      final s = ProgressSummary.fromJson(_summaryJson);
      expect(s.totalIntentos, 6);
      expect(s.isEmpty, isFalse);
      expect(s.rachaDias, 2);
      expect(s.ultimosDias, hasLength(2));
      expect(s.ultimosDias.last.fecha.day, 27);
      expect(s.palabras.first.estado, WordState.dominada);
      expect(s.palabras.first.en.aciertos, 3);
      expect(s.palabras.last.estado, WordState.practicando); // desconocido -> practicando
      expect(s.wordsIn(WordState.dominada), hasLength(1));
    });

    test('un JSON casi vacío no rompe la app', () {
      final s = ProgressSummary.fromJson(const {});
      expect(s.isEmpty, isTrue);
      expect(s.palabras, isEmpty);
      expect(s.ultimosDias, isEmpty);
    });
  });

  group('ParentalChallenge', () {
    test('acepta solo el resultado correcto', () {
      const c = ParentalChallenge(7, 8);
      expect(c.answer, 15);
      expect(c.question, '¿Cuánto es 7 + 8?');
      expect(c.accepts('15'), isTrue);
      expect(c.accepts(' 15 '), isTrue);
      expect(c.accepts('14'), isFalse);
      expect(c.accepts(''), isFalse);
      expect(c.accepts('quince'), isFalse);
    });

    test('las sumas aleatorias dan siempre dos cifras', () {
      final random = Random(1);
      for (var i = 0; i < 200; i++) {
        final c = ParentalChallenge.random(random);
        expect(c.answer, inInclusiveRange(11, 18));
      }
    });
  });

  group('ProgressService', () {
    test('sendAttempts arma el cuerpo esperado', () async {
      late Map<String, dynamic> body;
      final service = _service(MockClient((req) async {
        expect(req.url.path, '/progress/attempts');
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return _json({'guardados': 1}, 201);
      }));
      await service.sendAttempts(3, [
        Attempt(
          word: 'apple',
          language: 'en',
          success: true,
          assisted: false,
          at: DateTime.utc(2026, 10, 27, 15),
          childId: 3,
        ),
      ]);
      expect(body['nino_id'], 3);
      final item = (body['intentos'] as List).single as Map<String, dynamic>;
      expect(item['palabra'], 'apple');
      expect(item['idioma'], 'en');
      expect(item['acierto'], true);
      expect(item['asistido'], false);
      expect(DateTime.parse(item['fecha'] as String).isUtc, isTrue);
    });

    test('summary envía la zona horaria del tutor', () async {
      late Uri seen;
      final service = _service(MockClient((req) async {
        seen = req.url;
        return _json(_summaryJson);
      }));
      final s = await service.summary(1);
      expect(s.totalAciertos, 4);
      expect(seen.path, '/progress/1/summary');
      expect(seen.queryParameters['tz_offset_min'],
          DateTime.now().timeZoneOffset.inMinutes.toString());
    });
  });

  group('ProgressRepository', () {
    void record(ProgressRepository repo, {int childId = 1, String word = 'cat'}) {
      repo.recordAttempt(word, 'en', true, false, childId: childId);
    }

    test('flush envía todo junto y vacía la cola', () async {
      final calls = <Map<String, dynamic>>[];
      final repo = ProgressRepository(
        service: _service(MockClient((req) async {
          calls.add(jsonDecode(req.body) as Map<String, dynamic>);
          return _json({'guardados': 1}, 201);
        })),
      );
      record(repo);
      record(repo, word: 'dog');
      expect(repo.pendingCount, 2);

      await repo.flush();
      expect(repo.pendingCount, 0);
      expect(calls, hasLength(1));
      expect((calls.single['intentos'] as List), hasLength(2));
      repo.dispose();
    });

    test('sin conexión o con error del servidor se queda en cola', () async {
      var online = false;
      final repo = ProgressRepository(
        service: _service(MockClient((req) async {
          if (!online) return _json({'detail': 'x'}, 503);
          return _json({'guardados': 1}, 201);
        })),
      );
      record(repo);
      await repo.flush();
      expect(repo.pendingCount, 1);

      online = true;
      await repo.flush();
      expect(repo.pendingCount, 0);
      repo.dispose();
    });

    test('si el servidor rechaza los datos (4xx) se descartan', () async {
      final repo = ProgressRepository(
        service: _service(MockClient((_) async => _json({'detail': 'no'}, 404))),
      );
      record(repo);
      await repo.flush();
      expect(repo.pendingCount, 0);
      repo.dispose();
    });

    test('agrupa por niño y respeta el máximo por llamada', () async {
      final sizes = <int>[];
      final children = <int>[];
      final repo = ProgressRepository(
        service: _service(MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          children.add(body['nino_id'] as int);
          sizes.add((body['intentos'] as List).length);
          return _json({'guardados': 1}, 201);
        })),
      );
      for (var i = 0; i < 60; i++) {
        record(repo, childId: 1);
      }
      record(repo, childId: 2);
      expect(repo.pendingFor(1), 60);

      await repo.flush();
      expect(sizes, [50, 10, 1]);
      expect(children, [1, 1, 2]);
      expect(repo.pendingCount, 0);
      repo.dispose();
    });

    test('sin servicio solo guarda en memoria y discardPending olvida a un niño', () async {
      final local = ProgressRepository();
      record(local);
      expect(local.attempts, hasLength(1));
      expect(local.pendingCount, 0);

      final repo = ProgressRepository(
        service: _service(MockClient((_) async => _json({}, 503))),
      );
      record(repo, childId: 1);
      record(repo, childId: 2);
      repo.discardPending(1);
      expect(repo.pendingFor(1), 0);
      expect(repo.pendingFor(2), 1);
      repo.dispose();
    });
  });

  group('ProgressController', () {
    test('load envía lo pendiente y luego trae el resumen', () async {
      final order = <String>[];
      final mock = MockClient((req) async {
        order.add(req.method + req.url.path);
        if (req.method == 'POST') return _json({'guardados': 1}, 201);
        return _json(_summaryJson);
      });
      final repo = ProgressRepository(service: _service(mock))
        ..recordAttempt('cat', 'en', true, false, childId: 1);
      final controller = ProgressController(
        service: _service(mock),
        repository: repo,
        childId: 1,
      );

      await controller.load();
      expect(order, ['POST/progress/attempts', 'GET/progress/1/summary']);
      expect(controller.status, ProgressStatus.ready);
      expect(controller.summary!.palabrasDominadas, 1);
      repo.dispose();
    });

    test('un error deja un mensaje y un refresco fallido conserva lo mostrado', () async {
      var fail = false;
      final mock = MockClient((_) async => fail ? _json({'detail': 'x'}, 500) : _json(_summaryJson));
      final repo = ProgressRepository(service: _service(mock));
      final controller = ProgressController(service: _service(mock), repository: repo, childId: 1);

      await controller.load();
      expect(controller.status, ProgressStatus.ready);

      fail = true;
      await controller.load(silent: true);
      expect(controller.status, ProgressStatus.ready); // se mantiene

      await controller.load();
      expect(controller.status, ProgressStatus.error);
      expect(controller.error, isNotEmpty);
      repo.dispose();
    });

    test('reset borra en el servidor y recarga', () async {
      final methods = <String>[];
      final mock = MockClient((req) async {
        methods.add(req.method);
        if (req.method == 'DELETE') return http.Response('', 204);
        return _json({..._summaryJson, 'total_intentos': 0, 'palabras': []});
      });
      final repo = ProgressRepository(service: _service(mock));
      final controller = ProgressController(service: _service(mock), repository: repo, childId: 1);

      expect(await controller.reset(), isNull);
      expect(methods, ['DELETE', 'GET']);
      expect(controller.summary!.isEmpty, isTrue);
      repo.dispose();
    });
  });
}
