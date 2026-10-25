import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../consent/consent_controller.dart';
import '../vocabulary/card_colors.dart';
import '../vocabulary/vocab_models.dart';
import '../vocabulary/vocab_repository.dart';
import '../vocabulary/word_image.dart';
import '../vocabulary/words_screen.dart';
import 'avatars.dart';
import 'child.dart';

/// Pantalla del niño: categorías de vocabulario (funcionan sin conexión).
class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({
    super.key,
    required this.child,
    required this.consent,
  });

  final Child child;

  /// Se usará en la sección 4 para activar el micrófono solo con permiso.
  final ConsentController consent;

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  late final Future<List<VocabCategory>> _future = VocabularyRepository.load();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${avatarEmoji(widget.child.avatar)}  ${widget.child.apodo}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<VocabCategory>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: MessageBanner(
                  text: 'No se pudo cargar el vocabulario. Revisa que exista '
                      'assets/vocabulary/vocabulary.json y que esté declarado '
                      'en pubspec.yaml.',
                  icon: Icons.error_outline,
                  isError: true,
                ),
              );
            }

            final categories = snapshot.data ?? const <VocabCategory>[];
            if (categories.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: MessageBanner(
                  text: 'Todavía no hay categorías de vocabulario.',
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                  child: Text(
                    '¿Qué quieres aprender hoy?',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1,
                  children: [
                    for (var i = 0; i < categories.length; i++)
                      _CategoryCard(
                        category: categories[i],
                        color: cardColor(i),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.color});

  final VocabCategory category;
  final Color color;

  Widget _cover() {
    final emoji = category.emoji;
    final Widget emojiWidget = emoji == null
        ? const Icon(Icons.category, size: 56)
        : FittedBox(child: Text(emoji, style: const TextStyle(fontSize: 64)));

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
      return WordImage(word: category.words.first, emojiSize: 56);
    }
    return emojiWidget;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WordsScreen(category: category),
            ),
          );
        },
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: _cover(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
