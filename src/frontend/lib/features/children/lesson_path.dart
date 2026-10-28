import 'package:flutter/material.dart';

import '../vocabulary/card_colors.dart';
import '../vocabulary/vocab_models.dart';
import '../vocabulary/word_image.dart';

const Color _kRing = Color(0xFFF3D98B);
const Color _kRoad = Color(0xFFF7E7B4);

/// Lecciones en círculos unidos por un camino que va zigzagueando.
class LessonPath extends StatelessWidget {
  const LessonPath({
    super.key,
    required this.categories,
    required this.onOpen,
  });

  final List<VocabCategory> categories;
  final ValueChanged<VocabCategory> onOpen;

  static const double _rowHeight = 190;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final diameter = (width * 0.34).clamp(90.0, 140.0).toDouble();
        final centers = lessonCenters(categories.length, width, diameter);
        final height = categories.length * _rowHeight + 24;

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _RoadPainter(centers)),
              ),
              for (var i = 0; i < categories.length; i++)
                Positioned(
                  left: centers[i].dx - diameter / 2 - 20,
                  top: centers[i].dy - diameter / 2,
                  width: diameter + 40,
                  child: _LessonBubble(
                    category: categories[i],
                    color: cardColor(i),
                    diameter: diameter,
                    onTap: () => onOpen(categories[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Centro de cada círculo: izquierda, derecha, izquierda…
  @visibleForTesting
  static List<Offset> lessonCenters(int count, double width, double diameter) {
    return [
      for (var i = 0; i < count; i++)
        Offset(
          width * (i.isEven ? 0.27 : 0.73),
          12 + diameter / 2 + i * _rowHeight,
        ),
    ];
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.centers);

  final List<Offset> centers;

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;

    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var i = 1; i < centers.length; i++) {
      final a = centers[i - 1];
      final b = centers[i];
      final midY = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = _kRoad
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) => old.centers != centers;
}

class _LessonBubble extends StatelessWidget {
  const _LessonBubble({
    required this.category,
    required this.color,
    required this.diameter,
    required this.onTap,
  });

  final VocabCategory category;
  final Color color;
  final double diameter;
  final VoidCallback onTap;

  Widget _cover(double size) {
    final emoji = category.emoji;
    final Widget emojiWidget = emoji == null
        ? Icon(Icons.category, size: size * 0.5)
        : FittedBox(child: Text(emoji, style: TextStyle(fontSize: size)));

    final cover = category.cover;
    if (cover != null) {
      return Image.asset(
        'assets/images/$cover',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => emojiWidget,
      );
    }
    if (emoji != null) return emojiWidget;
    if (category.words.isNotEmpty) {
      return WordImage(word: category.words.first, emojiSize: size * 0.6);
    }
    return emojiWidget;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: category.name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: diameter,
              height: diameter,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: _kRing, width: 7),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                padding: EdgeInsets.all(diameter * 0.14),
                child: _cover(diameter * 0.5),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
