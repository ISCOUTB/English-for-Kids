import 'package:flutter/material.dart';

import 'vocab_models.dart';

/// Imagen local de la palabra; si no existe, muestra su emoji.
class WordImage extends StatelessWidget {
  const WordImage({super.key, required this.word, this.emojiSize = 72});

  final Word word;
  final double emojiSize;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: FittedBox(
        child: Text(word.emoji ?? '🖼️', style: TextStyle(fontSize: emojiSize)),
      ),
    );

    final image = word.image;
    if (image == null) return fallback;

    return Image.asset(
      'assets/images/$image',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
