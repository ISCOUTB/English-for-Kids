import 'package:flutter/material.dart';

import '../study/study_screen.dart';
import '../study/study_session.dart';
import 'card_colors.dart';
import 'vocab_models.dart';
import 'word_image.dart';

/// Tarjetas de una categoría: al tocar una se abre la pantalla de estudio.
class WordsScreen extends StatelessWidget {
  const WordsScreen({
    super.key,
    required this.category,
    required this.session,
  });

  final VocabCategory category;
  final StudySession session;

  @override
  Widget build(BuildContext context) {
    final words = category.words;

    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
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
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudyScreen(
                    session: session,
                    category: category,
                    initialIndex: i,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.word,
    required this.color,
    required this.onTap,
  });

  final Word word;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: WordImage(word: word),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                word.en,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
