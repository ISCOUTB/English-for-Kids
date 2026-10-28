import 'package:english_for_kids/features/children/lesson_path.dart';
import 'package:english_for_kids/features/vocabulary/vocab_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

VocabCategory _cat(String id, String name) =>
    VocabCategory(id: id, name: name, emoji: '🍎', words: const []);

void main() {
  test('los círculos van en zigzag y bajan fila por fila', () {
    final c = LessonPath.lessonCenters(4, 400, 120);
    expect(c[0].dx, lessThan(200));
    expect(c[1].dx, greaterThan(200));
    expect(c[2].dx, c[0].dx);
    expect(c[3].dx, c[1].dx);
    expect(c[1].dy, greaterThan(c[0].dy));
    expect(c[3].dy, greaterThan(c[2].dy));
  });

  testWidgets('muestra cada lección y abre la que se toca', (tester) async {
    VocabCategory? opened;
    final cats = [_cat('n', 'Números'), _cat('a', 'Acciones'), _cat('f', 'Alimentos')];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LessonPath(categories: cats, onOpen: (c) => opened = c),
          ),
        ),
      ),
    );

    expect(find.text('Números'), findsOneWidget);
    expect(find.text('Acciones'), findsOneWidget);

    await tester.tap(find.text('Acciones'));
    expect(opened?.id, 'a');
  });

  testWidgets('con una sola lección no falla', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonPath(categories: [_cat('n', 'Números')], onOpen: (_) {}),
        ),
      ),
    );
    expect(find.text('Números'), findsOneWidget);
  });
}
