import 'package:flutter/material.dart';

import '../../core/parental_gate.dart';
import '../../core/widgets.dart';
import '../children/avatars.dart';
import '../children/child.dart';
import '../stories/story.dart' show describeAge;
import '../stories/story_text.dart' show vocabularyIndex;
import '../study/progress_repository.dart';
import '../vocabulary/vocab_models.dart';
import '../vocabulary/vocabulary_manifest.dart';
import '../vocabulary/word_image.dart';
import 'progress_controller.dart';
import 'progress_models.dart';
import 'progress_service.dart';
import 'week_bars.dart';

const Color _kGreen = Color(0xFFC8E6C9);
const Color _kOrange = Color(0xFFFFCCBC);
const Color _kBlue = Color(0xFFBBDEFB);

/// Panel del tutor: cómo va un niño. Verlo es libre; borrar el progreso pide
/// la pregunta para adultos.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    required this.child,
    required this.service,
    required this.repository,
  });

  final Child child;
  final ProgressService service;
  final ProgressRepository repository;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final ProgressController _controller = ProgressController(
    service: widget.service,
    repository: widget.repository,
    childId: widget.child.id,
  );

  final Map<String, Word> _vocabulary = vocabularyIndex(kVocabulary);

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

  Future<void> _confirmReset() async {
    // Borrar es cosa de adultos: aquí sí se pide la suma.
    if (!await askParentalGate(context)) return;
    if (!mounted) return;
    final name = widget.child.apodo;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Borrar el progreso de $name?'),
        content: const Text(
          'Se borrarán sus intentos y estadísticas. Esta acción no se puede deshacer. '
          'El perfil y los cuentos no se borran.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final error = await _controller.reset();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Progreso borrado.')),
    );
  }

  void _showWord(WordProgress progress) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _WordSheet(
        progress: progress,
        word: _vocabulary[progress.palabra.toLowerCase()],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Progreso',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            switch (_controller.status) {
              case ProgressStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case ProgressStatus.error:
                return Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: MessageBanner(
                      text: _controller.error ?? 'No pudimos cargar el progreso.',
                      icon: Icons.error_outline,
                      isError: true,
                      actionLabel: 'Reintentar',
                      onAction: _controller.load,
                    ),
                  ),
                );
              case ProgressStatus.ready:
                return RefreshIndicator(
                  onRefresh: () => _controller.load(silent: true),
                  child: _content(context, _controller.summary!),
                );
            }
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ProgressSummary s) {
    final theme = Theme.of(context);
    final heading = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _Header(child: widget.child, summary: s),
        const SizedBox(height: 16),
        if (_controller.pendingAttempts > 0) ...[
          MessageBanner(
            text: 'Hay ${_controller.pendingAttempts} intentos por sincronizar. '
                'Se enviarán cuando haya conexión.',
            icon: Icons.cloud_off,
          ),
          const SizedBox(height: 16),
        ],
        if (s.isEmpty)
          _EmptyState(name: widget.child.apodo)
        else ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _StatCard(
                emoji: '⭐',
                value: '${s.palabrasDominadas}',
                label: 'Palabras dominadas',
                color: _kGreen,
              ),
              _StatCard(
                emoji: '📚',
                value: '${s.palabrasPracticadas}',
                label: 'Palabras practicadas',
                color: _kBlue,
              ),
              _StatCard(
                emoji: '🎯',
                value: '${s.totalAciertos} de ${s.totalIntentos}',
                label: s.aciertosAsistidos > 0
                    ? 'Aciertos (${s.aciertosAsistidos} con ayuda)'
                    : 'Aciertos',
                color: const Color(0xFFFFF59D),
              ),
              _StatCard(
                emoji: '🔥',
                value: s.rachaDias == 1 ? '1 día' : '${s.rachaDias} días',
                label: 'Racha seguida',
                color: _kOrange,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Últimos 7 días', style: heading),
          const SizedBox(height: 4),
          Text(
            'Practicó ${s.diasActivosSemana} de 7 días. Cada barra son los intentos del día.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFEADFCB)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
              child: WeekBars(days: s.ultimosDias),
            ),
          ),
          ..._wordSection(context, '💪 Para reforzar', 'Les cuesta un poco: conviene practicarlas juntos.',
              s.wordsIn(WordState.reforzar), _kOrange),
          ..._wordSection(context, '⭐ Dominadas', '3 aciertos en inglés sin ayuda.',
              s.wordsIn(WordState.dominada), _kGreen),
          ..._wordSection(context, '🌱 Practicando', null, s.wordsIn(WordState.practicando), _kBlue),
          const SizedBox(height: 20),
          Text(
            'Solo se cuentan los intentos con el micrófono. Un acierto "con ayuda" '
            'ocurre tras varios intentos seguidos sin acertar y no cuenta para dominar la palabra.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        if (!s.isEmpty)
          Center(
            child: TextButton.icon(
              onPressed: _confirmReset,
              icon: const Icon(Icons.delete_outline),
              label: Text('Borrar el progreso de ${widget.child.apodo}'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  List<Widget> _wordSection(
    BuildContext context,
    String title,
    String? subtitle,
    List<WordProgress> words,
    Color color,
  ) {
    if (words.isEmpty) return const [];
    final theme = Theme.of(context);

    return [
      const SizedBox(height: 20),
      Text(title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      if (subtitle != null) ...[
        const SizedBox(height: 2),
        Text(subtitle, style: theme.textTheme.bodySmall),
      ],
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final w in words)
            _WordChip(
              progress: w,
              word: _vocabulary[w.palabra.toLowerCase()],
              color: color,
              onTap: () => _showWord(w),
            ),
        ],
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.child, required this.summary});

  final Child child;
  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = summary.isEmpty
        ? 'Todavía no ha practicado con el micrófono'
        : summary.rachaDias >= 2
            ? '¡${summary.rachaDias} días seguidos practicando!'
            : 'Ha practicado ${summary.diasActivosSemana} de los últimos 7 días';

    return Row(
      children: [
        Text(avatarEmoji(child.avatar), style: const TextStyle(fontSize: 56)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                child.apodo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Text('📊', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 12),
          Text(
            'Aquí verás el avance de $name',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando practique repitiendo palabras con el micrófono, sus aciertos y '
            'las palabras que ya domina aparecerán aquí.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.progress,
    required this.word,
    required this.color,
    required this.onTap,
  });

  final WordProgress progress;
  final Word? word;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(word?.emoji ?? '🔤', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    progress.palabra,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${progress.aciertos}/${progress.intentos} aciertos',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordSheet extends StatelessWidget {
  const _WordSheet({required this.progress, required this.word});

  final WordProgress progress;
  final Word? word;

  String _stateLabel() => switch (progress.estado) {
        WordState.dominada => '⭐ Dominada',
        WordState.reforzar => '💪 Para reforzar',
        WordState.practicando => '🌱 Practicando',
      };

  String _line(String flag, String name, LangStats stats) => stats.intentos == 0
      ? '$flag $name: sin intentos'
      : '$flag $name: ${stats.aciertos} de ${stats.intentos} aciertos';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (word != null)
              SizedBox(height: 120, width: 120, child: WordImage(word: word!, emojiSize: 80)),
            const SizedBox(height: 8),
            Text(
              word == null ? progress.palabra : '${word!.en} · ${word!.es}',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(_stateLabel(), style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_line('🇬🇧', 'Inglés', progress.en), style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text(_line('🇪🇸', 'Español', progress.es), style: theme.textTheme.bodyLarge),
                  if (progress.asistidos > 0) ...[
                    const SizedBox(height: 4),
                    Text('🤝 Aciertos con ayuda: ${progress.asistidos}',
                        style: theme.textTheme.bodyLarge),
                  ],
                  const SizedBox(height: 4),
                  Text('🕒 Última práctica: ${describeAge(progress.ultimaPractica)}',
                      style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
