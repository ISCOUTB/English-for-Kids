import 'package:flutter/material.dart';

import 'audio_service.dart';
import 'card_colors.dart';
import 'vocab_models.dart';
import 'word_image.dart';

/// Tarjetas de una categoría: al tocar una, suena la palabra.
class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key, required this.category});

  final VocabCategory category;

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  final AudioService _audio = AudioService();

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.category.words;

    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.85,
          ),
          itemCount: words.length,
          itemBuilder: (context, i) => _WordCard(
            word: words[i],
            color: cardColor(i),
            onPlay: () => _audio.play(words[i]),
          ),
        ),
      ),
    );
  }
}

class _WordCard extends StatefulWidget {
  const _WordCard({
    required this.word,
    required this.color,
    required this.onPlay,
  });

  final Word word;
  final Color color;
  final VoidCallback onPlay;

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> {
  double _scale = 1;

  Future<void> _tap() async {
    widget.onPlay();
    setState(() => _scale = 1.08);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    setState(() => _scale = 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Material(
        color: widget.color,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: InkWell(
          onTap: _tap,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: WordImage(word: widget.word),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  widget.word.en,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
