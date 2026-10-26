import 'dart:convert';
import 'dart:typed_data';

import 'package:english_for_kids/core/api_client.dart';
import 'package:english_for_kids/features/stories/stories_controller.dart';
import 'package:english_for_kids/features/stories/stories_service.dart';
import 'package:english_for_kids/features/stories/story.dart';
import 'package:english_for_kids/features/stories/story_text.dart';
import 'package:english_for_kids/features/vocabulary/vocab_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _storyJson = {
  'id': 7,
  'nino_id': 1,
  'titulo': 'El gato y el perro',
  'texto': 'Había un cat.\n\nY un dog muy feliz.',
  'creada_en': '2026-10-25T08:14:45.238055Z',
  'audio_listo': false,
};

StoriesService _service(MockClient mock) =>
    StoriesService(ApiClient(client: mock), httpClient: mock);

void main() {
  group('Story', () {
    test('fromJson lee los campos del servidor', () {
      final story = Story.fromJson(_storyJson);
      expect(story.id, 7);
      expect(story.ninoId, 1);
      expect(story.titulo, 'El gato y el perro');
      expect(story.audioListo, isFalse);
      expect(story.creadaEn.toUtc().year, 2026);
    });

    test('describeAge', () {
      final now = DateTime(2026, 10, 25, 15);
      expect(describeAge(DateTime(2026, 10, 25, 1), now: now), 'hoy');
      expect(describeAge(DateTime(2026, 10, 24), now: now), 'ayer');
      expect(describeAge(DateTime(2026, 10, 22), now: now), 'hace 3 días');
      expect(describeAge(DateTime(2026, 10, 15), now: now), 'hace 1 semana');
      expect(describeAge(DateTime(2026, 10, 4), now: now), 'hace 3 semanas');
      expect(describeAge(DateTime(2026, 8, 1), now: now), '01/08/2026');
    });
  });

  group('texto del cuento', () {
    test('resalta palabras sin importar mayúsculas ni puntuación', () {
      final chunks = splitStoryText('El Cat, el dog. Un cat!', {'cat', 'dog'});
      final words = chunks.where((c) => c.isWord).map((c) => c.word).toList();
      expect(words, ['cat', 'dog', 'cat']);
      expect(chunks.map((c) => c.text).join(), 'El Cat, el dog. Un cat!');
      expect(chunks.first.text, 'El ');
      expect(chunks[1].text, 'Cat'); // conserva las mayúsculas originales
      expect(chunks[2].text, ', el ');
    });

    test('sin palabras del vocabulario todo es texto normal', () {
      final chunks = splitStoryText('Hola mundo feliz', {'cat'});
      expect(chunks, hasLength(1));
      expect(chunks.single.isWord, isFalse);
      expect(chunks.single.text, 'Hola mundo feliz');
    });

    test('no resalta palabras que solo contienen la palabra', () {
      final chunks = splitStoryText('category cats', {'cat'});
      expect(chunks.any((c) => c.isWord), isFalse);
    });

    test('maneja tildes y texto vacío', () {
      expect(splitStoryText('', {'cat'}), isEmpty);
      final chunks = splitStoryText('¡Qué lindo cat! ñandú', {'cat'});
      expect(chunks.where((c) => c.isWord), hasLength(1));
      expect(chunks.map((c) => c.text).join(), '¡Qué lindo cat! ñandú');
    });

    test('splitParagraphs separa por línea en blanco', () {
      expect(splitParagraphs('Uno.\n\nDos.\n \nTres.'), ['Uno.', 'Dos.', 'Tres.']);
      expect(splitParagraphs('  \n\n '), isEmpty);
    });

    test('isValidStoryWord replica las reglas del servidor', () {
      expect(isValidStoryWord('cat'), isTrue);
      expect(isValidStoryWord('ice cream'), isTrue);
      expect(isValidStoryWord("don't"), isTrue);
      expect(isValidStoryWord('árbol'), isTrue);
      expect(isValidStoryWord(''), isFalse);
      expect(isValidStoryWord('cat1'), isFalse);
      expect(isValidStoryWord('<cat>'), isFalse);
      expect(isValidStoryWord('a' * 31), isFalse);
    });

    test('vocabularyIndex usa la palabra en inglés en minúsculas', () {
      const cats = [
        VocabCategory(id: 'a', name: 'A', words: [
          Word(id: 'cat', en: 'Cat', es: 'gato'),
          Word(id: 'dog', en: 'dog', es: 'perro'),
        ]),
      ];
      final index = vocabularyIndex(cats);
      expect(index.keys, containsAll(['cat', 'dog']));
      expect(index['cat']!.es, 'gato');
    });
  });

  group('StoriesService', () {
    test('list devuelve los cuentos', () async {
      late http.Request seen;
      final service = _service(MockClient((req) async {
        seen = req;
        return _json([_storyJson]);
      }));
      final stories = await service.list(1);
      expect(stories.single.titulo, 'El gato y el perro');
      expect(seen.url.path, '/stories');
      expect(seen.url.queryParameters['nino_id'], '1');
    });

    test('create envía el cuerpo esperado', () async {
      late Map<String, dynamic> body;
      final service = _service(MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return _json(_storyJson, 201);
      }));
      final story = await service.create(
        childId: 1,
        words: ['cat', 'dog'],
        contexto: 'en el parque',
      );
      expect(story.id, 7);
      expect(body, {
        'nino_id': 1,
        'palabras': ['cat', 'dog'],
        'contexto': 'en el parque',
        'idioma': 'es',
      });
    });

    test('create traduce 429, 422 y 502 a mensajes amables', () async {
      for (final (status, text) in [
        (429, 'Mañana hacemos más'),
        (422, 'Prueba con otras'),
        (502, 'ratito'),
      ]) {
        final service = _service(MockClient((_) async => _json({'detail': 'x'}, status)));
        try {
          await service.create(childId: 1, words: ['cat']);
          fail('debía lanzar ApiException');
        } on ApiException catch (e) {
          expect(e.statusCode, status);
          expect(friendlyStoryError(e), contains(text));
        }
      }
    });

    test('audio envía el token y devuelve los bytes', () async {
      late http.Request seen;
      final api = ApiClient(client: MockClient((_) async => _json({})))..token = 'abc';
      final mock = MockClient((req) async {
        seen = req;
        return http.Response.bytes([1, 2, 3], 200);
      });
      final bytes = await StoriesService(api, httpClient: mock).audio(7);
      expect(bytes, Uint8List.fromList([1, 2, 3]));
      expect(seen.headers['Authorization'], 'Bearer abc');
      expect(seen.url.path, '/stories/7/audio');
    });

    test('audio con error del servidor lanza ApiException amable', () async {
      final service = _service(MockClient((_) async => http.Response('boom', 502)));
      expect(
        service.audio(7),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('voz'))),
      );
    });
  });

  group('StoriesController', () {
    test('load llena la lista y create la agrega al principio', () async {
      final controller = StoriesController(
        service: _service(MockClient((req) async {
          if (req.method == 'POST') {
            return _json({..._storyJson, 'id': 8, 'titulo': 'Nuevo'}, 201);
          }
          return _json([_storyJson]);
        })),
        childId: 1,
      );
      await controller.load();
      expect(controller.status, StoriesStatus.ready);
      expect(controller.stories, hasLength(1));

      final created = await controller.create(words: ['cat']);
      expect(created?.id, 8);
      expect(controller.stories.first.titulo, 'Nuevo');
      expect(controller.creating, isFalse);
    });

    test('load con error deja un mensaje y create sin palabras válidas no llama al servidor', () async {
      var calls = 0;
      final controller = StoriesController(
        service: _service(MockClient((_) async {
          calls++;
          return _json({'detail': 'x'}, 500);
        })),
        childId: 1,
      );
      await controller.load();
      expect(controller.status, StoriesStatus.error);
      expect(controller.error, isNotEmpty);

      calls = 0;
      expect(await controller.create(words: ['', '<x>']), isNull);
      expect(controller.createError, contains('palabra'));
      expect(calls, 0);
    });

    test('ignora un segundo create mientras uno está en curso', () async {
      var posts = 0;
      final controller = StoriesController(
        service: _service(MockClient((req) async {
          posts++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return _json(_storyJson, 201);
        })),
        childId: 1,
      );
      final first = controller.create(words: ['cat']);
      final second = await controller.create(words: ['cat']);
      expect(second, isNull);
      expect(await first, isNotNull);
      expect(posts, 1);
    });

    test('audioFor descarga una sola vez por cuento', () async {
      var downloads = 0;
      final controller = StoriesController(
        service: _service(MockClient((_) async {
          downloads++;
          return http.Response.bytes([9, 9], 200);
        })),
        childId: 1,
      );
      await controller.audioFor(7);
      await controller.audioFor(7);
      expect(downloads, 1);
    });
  });
}
