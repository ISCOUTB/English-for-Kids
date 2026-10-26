import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../children/child.dart';
import '../vocabulary/card_colors.dart';
import '../vocabulary/vocab_models.dart';
import '../vocabulary/vocab_repository.dart';
import '../vocabulary/word_image.dart';
import 'stories_controller.dart';
import 'story_reader_screen.dart';
import 'story_text.dart';

/// Temas para el niño: opciones con emoji, sin escribir texto libre.
/// (etiqueta, contexto que se envía al servidor; null = sorpresa)
const List<(String, String?)> kStoryThemes = [
  ('🤷 Sorpresa', null),
  ('🌧️ Un día de lluvia', 'un día de lluvia'),
  ('🌳 En el parque', 'en el parque'),
  ('🏖️ En la playa', 'en la playa'),
  ('🏠 En casa', 'en casa'),
  ('🚀 En el espacio', 'en el espacio'),
];

/// Elegir palabras, tema e idioma y pedir el cuento.
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key, required this.child, required this.controller});

  final Child child;
  final StoriesController controller;

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  late final Future<List<VocabCategory>> _vocabulary = VocabularyRepository.load();

  final List<Word> _selected = [];
  int _themeIndex = 0;
  String _language = 'es';

  @override
  void initState() {
    super.initState();
    widget.controller.clearCreateError();
  }

  bool _isSelected(Word word) => _selected.any((w) => w.id == word.id);

  void _toggle(Word word) {
    widget.controller.clearCreateError();
    if (_isSelected(word)) {
      setState(() => _selected.removeWhere((w) => w.id == word.id));
    } else if (_selected.length >= kMaxStoryWords) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('¡Ya tienes 8 palabras! Quita una para elegir otra.')),
        );
    } else {
      setState(() => _selected.add(word));
    }
  }

  Future<void> _create() async {
    final story = await widget.controller.create(
      words: _selected.map((w) => w.en).toList(),
      contexto: kStoryThemes[_themeIndex].$2,
      language: _language,
    );
    if (!mounted || story == null) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            StoryReaderScreen(story: story, controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final creating = widget.controller.creating;

        return PopScope(
          canPop: !creating,
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'Crear un cuento',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            body: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: FutureBuilder<List<VocabCategory>>(
                          future: _vocabulary,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState != ConnectionState.done) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError || (snapshot.data ?? const []).isEmpty) {
                              return const Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: MessageBanner(
                                    text: 'No se pudo cargar el vocabulario.',
                                    icon: Icons.error_outline,
                                    isError: true,
                                  ),
                                ),
                              );
                            }
                            return _picker(context, snapshot.data!);
                          },
                        ),
                      ),
                      _bottomBar(),
                    ],
                  ),
                  if (creating) const Positioned.fill(child: _WritingOverlay()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _picker(BuildContext context, List<VocabCategory> categories) {
    final theme = Theme.of(context);
    final heading = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Text('1. Elige hasta 8 palabras', style: heading),
        const SizedBox(height: 4),
        Text('Llevas ${_selected.length} de $kMaxStoryWords',
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        for (final category in categories) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              '${category.emoji ?? ''} ${category.name}'.trim(),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.9,
            children: [
              for (var i = 0; i < category.words.length; i++)
                _WordTile(
                  word: category.words[i],
                  color: cardColor(i),
                  selected: _isSelected(category.words[i]),
                  onTap: () => _toggle(category.words[i]),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('2. ¿Dónde pasa el cuento?', style: heading),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < kStoryThemes.length; i++)
              ChoiceChip(
                label: Text(kStoryThemes[i].$1, style: const TextStyle(fontSize: 16)),
                selected: _themeIndex == i,
                onSelected: (_) => setState(() => _themeIndex = i),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text('3. ¿En qué idioma?', style: heading),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'es', label: Text('Español')),
            ButtonSegment(value: 'en', label: Text('English')),
          ],
          selected: {_language},
          onSelectionChanged: (value) => setState(() => _language = value.first),
        ),
        const SizedBox(height: 4),
        Text(
          _language == 'es'
              ? 'El cuento va en español y tus palabras salen en inglés.'
              : 'The story is told in simple English.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _bottomBar() {
    final error = widget.controller.createError;
    final canCreate = _selected.isNotEmpty && !widget.controller.creating;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MessageBanner(
                text: error,
                icon: Icons.error_outline,
                isError: true,
              ),
            ),
          FilledButton.icon(
            onPressed: canCreate ? _create : null,
            icon: const Icon(Icons.auto_stories),
            label: Text(
              _selected.isEmpty
                  ? 'Elige palabras'
                  : '¡Crear cuento! (${_selected.length})',
            ),
          ),
        ],
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.word,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Word word;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: selected
            ? BorderSide(color: scheme.primary, width: 4)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: WordImage(word: word, emojiSize: 40),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                  child: Text(
                    word.en,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.check_circle, color: scheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla de espera mientras la IA escribe el cuento.
class _WritingOverlay extends StatelessWidget {
  const _WritingOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Color(0xE6FFF8EE)),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✍️', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 16),
                Text(
                  'Estoy escribiendo tu cuento…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Puede tardar unos segundos',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
