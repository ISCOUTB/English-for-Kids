import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../study/study_config.dart';
import '../vocabulary/audio_service.dart';
import '../vocabulary/vocab_models.dart';
import '../vocabulary/vocab_repository.dart';
import 'stories_controller.dart';
import 'story.dart';
import 'story_narration.dart';
import 'story_text.dart';

/// Lee un cuento: texto grande, palabras tocables y narración con voz.
class StoryReaderScreen extends StatefulWidget {
  const StoryReaderScreen({super.key, required this.story, required this.controller});

  final Story story;
  final StoriesController controller;

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
  late final StoryNarration _narration = StoryNarration(
    loadBytes: () => widget.controller.audioFor(widget.story.id),
  );
  final StudyAudio _wordAudio = StudyAudio();

  Map<String, Word> _index = const {};
  List<List<TextChunk>> _paragraphs = const [];
  final Map<TextChunk, TapGestureRecognizer> _taps = {};

  @override
  void initState() {
    super.initState();
    _rebuildChunks();
    _loadVocabulary();
  }

  Future<void> _loadVocabulary() async {
    final categories = await VocabularyRepository.load();
    if (!mounted) return;
    setState(() {
      _index = vocabularyIndex(categories);
      _rebuildChunks();
    });
  }

  void _disposeTaps() {
    for (final tap in _taps.values) {
      tap.dispose();
    }
    _taps.clear();
  }

  void _rebuildChunks() {
    _disposeTaps();
    final highlight = _index.keys.toSet();
    _paragraphs = [
      for (final paragraph in splitParagraphs(widget.story.texto))
        splitStoryText(paragraph, highlight),
    ];
    for (final paragraph in _paragraphs) {
      for (final chunk in paragraph) {
        final key = chunk.word;
        if (key != null) {
          _taps[chunk] = TapGestureRecognizer()..onTap = () => _onWordTap(key);
        }
      }
    }
  }

  void _onWordTap(String key) {
    final word = _index[key];
    if (word == null) return;
    // Que no suenen la narración y la palabra a la vez.
    _narration.pause();
    _wordAudio.speak(Lang.en, word);
  }

  @override
  void dispose() {
    _disposeTaps();
    _narration.dispose();
    _wordAudio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final bodyStyle = theme.textTheme.titleLarge?.copyWith(
      fontSize: 22,
      height: 1.6,
      fontWeight: FontWeight.w500,
    );
    final wordStyle = TextStyle(
      color: scheme.primary,
      fontWeight: FontWeight.w900,
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.5),
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
    );

    final hasWords = _paragraphs.any((p) => p.any((c) => c.isWord));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.story.titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _NarrationBar(narration: _narration),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.story.titulo,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 16),
                    for (final paragraph in _paragraphs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              for (final chunk in paragraph)
                                if (chunk.isWord)
                                  TextSpan(
                                    text: chunk.text,
                                    style: wordStyle,
                                    recognizer: _taps[chunk],
                                  )
                                else
                                  TextSpan(text: chunk.text),
                            ],
                          ),
                          style: bodyStyle,
                        ),
                      ),
                    if (hasWords)
                      Text(
                        'Toca las palabras de colores para escucharlas en inglés 👆',
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver a mis cuentos'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NarrationBar extends StatelessWidget {
  const _NarrationBar({required this.narration});

  final StoryNarration narration;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: narration,
      builder: (context, _) {
        final state = narration.state;

        final (IconData icon, String label) = switch (state) {
          NarrationState.idle => (Icons.volume_up, 'Escuchar el cuento'),
          NarrationState.loading => (Icons.hourglass_top, 'Preparando la voz…'),
          NarrationState.playing => (Icons.pause, 'Pausa'),
          NarrationState.paused => (Icons.play_arrow, 'Seguir escuchando'),
          NarrationState.error => (Icons.refresh, 'Intentar otra vez'),
        };

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        state == NarrationState.loading ? null : narration.toggle,
                    icon: state == NarrationState.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Icon(icon),
                    label: Text(label),
                  ),
                ),
                if (state == NarrationState.playing ||
                    state == NarrationState.paused) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: narration.stop,
                    icon: const Icon(Icons.stop),
                    tooltip: 'Detener',
                    iconSize: 28,
                  ),
                ],
              ],
            ),
            if (state == NarrationState.error && narration.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: MessageBanner(
                  text: '${narration.error!}\nPuedes leer el cuento igual.',
                  icon: Icons.error_outline,
                  isError: true,
                ),
              ),
          ],
        );
      },
    );
  }
}
