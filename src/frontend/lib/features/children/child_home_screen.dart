import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../consent/consent_controller.dart';
import '../progress/progress_screen.dart';
import '../progress/progress_service.dart';
import '../study/progress_repository.dart';
import '../study/speech_judge_service.dart';
import '../stories/stories_list_screen.dart';
import '../stories/stories_service.dart';
import '../study/study_session.dart';
import '../vocabulary/vocab_models.dart';
import '../vocabulary/vocab_repository.dart';
import '../vocabulary/words_screen.dart';
import 'avatars.dart';
import 'child.dart';
import 'lesson_path.dart';

/// Pantalla del niño: barra de abajo con Lecciones, Cuentos y Progreso.
/// Las lecciones funcionan sin conexión.
class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({
    super.key,
    required this.child,
    required this.consent,
    required this.speech,
    required this.progress,
    required this.progressService,
    required this.stories,
  });

  final Child child;
  final ConsentController consent;
  final SpeechJudgeService speech;
  final ProgressRepository progress;
  final ProgressService progressService;
  final StoriesService stories;

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  int _tab = 0;

  late final StudySession _session = StudySession(
    child: widget.child,
    consent: widget.consent,
    speech: widget.speech,
    progress: widget.progress,
  );

  Widget _body() {
    switch (_tab) {
      case 1:
        return StoriesListScreen(
          key: const ValueKey('cuentos'),
          child: widget.child,
          service: widget.stories,
        );
      case 2:
        // Se crea de nuevo al entrar, así siempre muestra el progreso al día.
        return ProgressScreen(
          key: const ValueKey('progreso'),
          child: widget.child,
          service: widget.progressService,
          repository: widget.progress,
        );
      default:
        return _LessonsTab(
          key: const ValueKey('lecciones'),
          child: widget.child,
          session: _session,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _body(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Lecciones',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Cuentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Progreso',
          ),
        ],
      ),
    );
  }
}

/// Pestaña de lecciones: el camino de círculos.
class _LessonsTab extends StatefulWidget {
  const _LessonsTab({super.key, required this.child, required this.session});

  final Child child;
  final StudySession session;

  @override
  State<_LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<_LessonsTab> {
  late final Future<List<VocabCategory>> _future = VocabularyRepository.load();

  void _open(VocabCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            WordsScreen(category: category, session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              return Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: MessageBanner(
                    text: 'No se pudo cargar el vocabulario.\n\n'
                        'Detalle: ${snapshot.error}',
                    icon: Icons.error_outline,
                    isError: true,
                  ),
                ),
              );
            }

            final categories = snapshot.data ?? const <VocabCategory>[];
            if (categories.isEmpty) {
              return const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: MessageBanner(
                    text: 'Todavía no hay categorías de vocabulario.',
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                    child: Text(
                      '¿Qué quieres aprender hoy?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  LessonPath(categories: categories, onOpen: _open),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
