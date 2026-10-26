import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../children/child.dart';
import '../vocabulary/card_colors.dart';
import 'create_story_screen.dart';
import 'stories_controller.dart';
import 'stories_service.dart';
import 'story.dart';
import 'story_reader_screen.dart';

/// Tarjeta grande de la pantalla del niño que abre "Cuentos".
class StoriesEntryCard extends StatelessWidget {
  const StoriesEntryCard({super.key, required this.child, required this.service});

  final Child child;
  final StoriesService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: const Color(0xFFFFD6E7),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StoriesListScreen(child: child, service: service),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Text('📖', style: TextStyle(fontSize: 48)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cuentos',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Crea historias con tus palabras',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista de cuentos del niño, con el botón para crear uno nuevo.
class StoriesListScreen extends StatefulWidget {
  const StoriesListScreen({super.key, required this.child, required this.service});

  final Child child;
  final StoriesService service;

  @override
  State<StoriesListScreen> createState() => _StoriesListScreenState();
}

class _StoriesListScreenState extends State<StoriesListScreen> {
  late final StoriesController _controller = StoriesController(
    service: widget.service,
    childId: widget.child.id,
  );

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CreateStoryScreen(child: widget.child, controller: _controller),
      ),
    );
  }

  void _openStory(Story story) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryReaderScreen(story: story, controller: _controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📖 Cuentos', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _content(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                onPressed: _openCreate,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Crear cuento nuevo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);

    switch (_controller.status) {
      case StoriesStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case StoriesStatus.error:
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: MessageBanner(
              text: _controller.error ?? 'No pudimos cargar los cuentos.',
              icon: Icons.error_outline,
              isError: true,
              actionLabel: 'Reintentar',
              onAction: _controller.load,
            ),
          ),
        );

      case StoriesStatus.ready:
        final stories = _controller.stories;
        if (stories.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📚', style: TextStyle(fontSize: 72)),
                  const SizedBox(height: 12),
                  Text(
                    '¡Todavía no tienes cuentos!\nCrea el primero con tus palabras.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _controller.load(silent: true),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: stories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _StoryTile(
              story: stories[i],
              color: cardColor(i),
              onTap: () => _openStory(stories[i]),
            ),
          ),
        );
    }
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({
    required this.story,
    required this.color,
    required this.onTap,
  });

  final Story story;
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('📖', style: TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(describeAge(story.creadaEn),
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (story.audioListo)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text('🔊', style: TextStyle(fontSize: 24)),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
