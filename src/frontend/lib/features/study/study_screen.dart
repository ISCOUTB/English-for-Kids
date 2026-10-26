import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../vocabulary/audio_service.dart';
import '../vocabulary/vocab_models.dart';
import '../vocabulary/word_image.dart';
import 'local_judge.dart';
import 'pronunciation_controller.dart';
import 'study_config.dart';
import 'study_session.dart';
import 'talking_character.dart';

/// Estudio de una palabra: imagen arriba; abajo, un personaje por idioma y
/// el micrófono en el centro. El idioma activo se resalta.
class StudyScreen extends StatefulWidget {
  const StudyScreen({
    super.key,
    required this.session,
    required this.category,
    required this.initialIndex,
  });

  final StudySession session;
  final VocabCategory category;
  final int initialIndex;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late int _index = widget.initialIndex;
  late final StudyAudio _audio = StudyAudio();
  late final PronunciationController _mic;

  Word get _word => widget.category.words[_index];

  @override
  void initState() {
    super.initState();
    _mic = PronunciationController(
      childId: widget.session.child.id,
      band: ageBandFor(widget.session.child.rangoEdad),
      judge: widget.session.speech,
      progress: widget.session.progress,
      consent: widget.session.consent,
      audio: _audio,
    )..setWord(_word);
  }

  @override
  void dispose() {
    _mic.dispose();
    _audio.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final count = widget.category.words.length;
    setState(() => _index = (_index + delta + count) % count);
    _audio.stop();
    _mic.setWord(_word);
  }

  void _onMic() {
    if (_mic.transitioning) return;
    if (!widget.session.consent.voiceAllowed) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Pídele a un adulto que active el permiso de voz.'),
          ),
        );
      return;
    }
    _mic.toggle();
  }

  String _feedback(bool allowed) {
    switch (_mic.state) {
      case MicState.listening:
        return '¡Te escucho! 👂';
      case MicState.processing:
        return '';
      case MicState.success:
      case MicState.tryAgain:
      case MicState.unavailable:
        return _mic.message ?? '';
      case MicState.ready:
        if (_mic.transitioning) return '🔊';
        return allowed ? 'Toca el micrófono y repite 🎤' : 'Voz sin permiso';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = _word;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.category.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_audio, _mic, widget.session.consent]),
          builder: (context, _) {
            final allowed = widget.session.consent.voiceAllowed;
            final complete = _mic.wordComplete;

            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _ArrowButton(
                              icon: Icons.chevron_left,
                              onTap: () => _go(-1),
                            ),
                            Expanded(
                              child: Material(
                                color: Colors.white,
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  side: const BorderSide(
                                    color: Color(0xFFEADFCB),
                                    width: 1.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: WordImage(word: word, emojiSize: 140),
                                ),
                              ),
                            ),
                            _ArrowButton(
                              icon: Icons.chevron_right,
                              onTap: () => _go(1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _CharacterColumn(
                              language: Lang.en,
                              caption: word.en,
                              speaking: _audio.speaking,
                              isActive: _mic.activeLang == Lang.en,
                              isDone: _mic.doneEn,
                              onTap: () => _mic.selectLanguage(Lang.en),
                            ),
                          ),
                          _MicButton(
                            state: _mic.state,
                            enabled: allowed && !_mic.transitioning,
                            level: _mic.soundLevel,
                            onTap: _onMic,
                          ),
                          Expanded(
                            child: _CharacterColumn(
                              language: Lang.es,
                              caption: word.es,
                              speaking: _audio.speaking,
                              isActive: _mic.activeLang == Lang.es,
                              isDone: _mic.doneEs,
                              onTap: () => _mic.selectLanguage(Lang.es),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 30,
                        child: Center(
                          child: Text(
                            _feedback(allowed),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (complete) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FilledButton.icon(
                            onPressed: () => _go(1),
                            icon: const Icon(Icons.arrow_forward, size: 32),
                            label: const Text('Siguiente'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(68),
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_mic.state == MicState.success)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _Celebration(
                        emojis: complete ? '🏆🎉🌟' : '🎉⭐🎉',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      iconSize: 36,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 80),
      padding: EdgeInsets.zero,
      icon: Icon(icon),
    );
  }
}

class _CharacterColumn extends StatelessWidget {
  const _CharacterColumn({
    required this.language,
    required this.caption,
    required this.speaking,
    required this.isActive,
    required this.isDone,
    required this.onTap,
  });

  final Lang language;
  final String caption;
  final Lang? speaking;
  final bool isActive;
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brillo suave alrededor del personaje del idioma activo.
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive ? primary : Colors.transparent,
              width: 3,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : const [],
          ),
          child: TalkingCharacter(
            folder: kCharacterFolder[language]!,
            language: language,
            speakingLanguage: speaking,
            onTap: onTap,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  caption,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (isDone) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ],
        ),
      ],
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton({
    required this.state,
    required this.enabled,
    required this.level,
    required this.onTap,
  });

  final MicState state;
  final bool enabled;

  /// Nivel de sonido 0..1: el anillo "oye" al niño.
  final ValueListenable<double> level;
  final VoidCallback onTap;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.state == MicState.listening) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final listening = widget.state == MicState.listening;

    final Color background;
    final Widget icon;
    if (!widget.enabled) {
      background = Colors.grey.shade400;
      icon = const Icon(Icons.mic_off, color: Colors.white, size: 44);
    } else {
      switch (widget.state) {
        case MicState.listening:
          background = Colors.redAccent;
          icon = const Icon(Icons.mic, color: Colors.white, size: 48);
        case MicState.processing:
          background = scheme.primary;
          icon = const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: Colors.white,
            ),
          );
        case MicState.success:
          background = Colors.green;
          icon = const Icon(Icons.star, color: Colors.white, size: 48);
        case MicState.tryAgain:
          background = scheme.primary;
          icon = const Icon(Icons.mic, color: Colors.white, size: 48);
        case MicState.unavailable:
          background = Colors.grey.shade500;
          icon = const Icon(Icons.mic_off, color: Colors.white, size: 44);
        case MicState.ready:
          background = scheme.primary;
          icon = const Icon(Icons.mic, color: Colors.white, size: 48);
      }
    }

    return Semantics(
      button: true,
      label: 'Micrófono',
      child: SizedBox(
        width: 140,
        height: 140,
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulse, widget.level]),
            builder: (context, child) {
              final ring = 96 + 18 * _pulse.value + 30 * widget.level.value;
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (listening)
                    Container(
                      width: ring,
                      height: ring,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: background.withValues(
                          alpha: 0.18 + 0.22 * widget.level.value,
                        ),
                      ),
                    ),
                  child!,
                ],
              );
            },
            child: Material(
              color: background,
              shape: const CircleBorder(),
              elevation: widget.enabled ? 4 : 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onTap,
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: Center(child: icon),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Celebration extends StatelessWidget {
  const _Celebration({required this.emojis});

  final String emojis;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.2, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: Text(emojis, style: const TextStyle(fontSize: 84)),
      ),
    );
  }
}
