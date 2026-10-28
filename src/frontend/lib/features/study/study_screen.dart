import 'dart:math' as math;

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

/// Colores de cada idioma: círculo detrás del personaje, burbuja y acento.
class _LangStyle {
  const _LangStyle({
    required this.circle,
    required this.bubble,
    required this.accent,
  });

  final Color circle;
  final Color bubble;
  final Color accent;
}

const Map<Lang, _LangStyle> _styles = {
  // Español: verde
  Lang.es: _LangStyle(
    circle: Color(0xFFC5E8B7),
    bubble: Color(0xFFE2F3DA),
    accent: Color(0xFF43A047),
  ),
  // Inglés: lavanda
  Lang.en: _LangStyle(
    circle: Color(0xFFD9CCF2),
    bubble: Color(0xFFECE5F9),
    accent: Color(0xFF7E57C2),
  ),
};

/// Estudio de una palabra: imagen arriba, un personaje por idioma con su
/// burbuja, y el micrófono en un panel abajo. El idioma activo se resalta.
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
        return allowed ? '¡Toca para hablar!' : 'Voz sin permiso';
    }
  }

  String _caption(Lang lang) => lang == Lang.en ? _word.en : _word.es;

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
          listenable: Listenable.merge(
            [_audio, _mic, widget.session.consent],
          ),
          builder: (context, _) {
            final allowed = widget.session.consent.voiceAllowed;
            final complete = _mic.wordComplete;

            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Column(
                    children: [
                      // Imagen de la palabra
                      Expanded(
                        child: Row(
                          children: [
                            _ArrowButton(
                              icon: Icons.chevron_left,
                              onTap: () => _go(-1),
                            ),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: WordImage(word: word, emojiSize: 140),
                              ),
                            ),
                            _ArrowButton(
                              icon: Icons.chevron_right,
                              onTap: () => _go(1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Personajes con su burbuja
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final lang in kLanguageOrder)
                            Expanded(
                              child: _CharacterColumn(
                                language: lang,
                                caption: _caption(lang),
                                speaking: _audio.speaking,
                                isActive: _mic.activeLang == lang,
                                isDone: lang == Lang.en
                                    ? _mic.doneEn
                                    : _mic.doneEs,
                                onTap: () => _mic.selectLanguage(lang),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (complete) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: FilledButton.icon(
                            onPressed: () => _go(1),
                            icon: const Icon(Icons.arrow_forward, size: 30),
                            label: const Text('Siguiente'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(60),
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Panel del micrófono
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFEADFCB),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 26,
                              child: Center(
                                child: Text(
                                  _feedback(allowed),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _MicButton(
                              state: _mic.state,
                              enabled: allowed && !_mic.transitioning,
                              level: _mic.soundLevel,
                              onTap: _onMic,
                            ),
                          ],
                        ),
                      ),
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
      iconSize: 32,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 80),
      padding: EdgeInsets.zero,
      icon: Icon(icon),
    );
  }
}

/// Personaje dentro de un círculo de color (sin "piso") y su burbuja debajo.
/// El personaje sobresale un poco por arriba y por abajo del círculo.
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
    final style = _styles[language]!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth - 8, 180.0);
        final rise = size * kCharacterRise;
        final drop = size * kCharacterDrop;
        final total = size + rise + drop;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: total,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // El círculo del idioma activo se ve más fuerte y con brillo.
                  Positioned(
                    left: 0,
                    top: rise,
                    width: size,
                    height: size,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? style.circle
                            : style.circle.withValues(alpha: 0.5),
                        border: Border.all(
                          color: isActive ? style.accent : Colors.transparent,
                          width: 4,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: style.accent.withValues(alpha: 0.35),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ]
                            : const [],
                      ),
                    ),
                  ),
                  // El personaje ocupa toda la altura y sobresale del círculo.
                  Positioned.fill(
                    child: TalkingCharacter(
                      folder: kCharacterFolder[language]!,
                      language: language,
                      speakingLanguage: speaking,
                      onTap: onTap,
                      height: total,
                      canvasFill: kCharacterCanvasFill,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _SpeechBubble(
              text: caption,
              color: style.bubble,
              accent: style.accent,
              isDone: isDone,
              width: math.min(constraints.maxWidth - 8, 190.0),
              onTap: onTap,
            ),
          ],
        );
      },
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.text,
    required this.color,
    required this.accent,
    required this.isDone,
    required this.width,
    required this.onTap,
  });

  final String text;
  final Color color;
  final Color accent;
  final bool isDone;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: CustomPaint(
          painter: _BubblePainter(color),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      maxLines: 1,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.volume_up_rounded, color: accent, size: 24),
                if (isDone) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Globo de diálogo con la colita hacia arriba (apunta al personaje).
class _BubblePainter extends CustomPainter {
  const _BubblePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const tail = 10.0;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, tail, size.width, size.height - tail),
      const Radius.circular(22),
    );
    final path = Path()
      ..addRRect(body)
      ..moveTo(size.width / 2 - 12, tail)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width / 2 + 12, tail)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => oldDelegate.color != color;
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
      icon = const Icon(Icons.mic_off, color: Colors.white, size: 40);
    } else {
      switch (widget.state) {
        case MicState.listening:
          background = Colors.redAccent;
          icon = const Icon(Icons.mic, color: Colors.white, size: 44);
        case MicState.processing:
          background = scheme.primary;
          icon = const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white),
          );
        case MicState.success:
          background = Colors.green;
          icon = const Icon(Icons.star, color: Colors.white, size: 44);
        case MicState.tryAgain:
          background = scheme.primary;
          icon = const Icon(Icons.mic, color: Colors.white, size: 44);
        case MicState.unavailable:
          background = Colors.grey.shade500;
          icon = const Icon(Icons.mic_off, color: Colors.white, size: 40);
        case MicState.ready:
          background = scheme.primary;
          icon = const Icon(Icons.mic, color: Colors.white, size: 44);
      }
    }

    return Semantics(
      button: true,
      label: 'Micrófono',
      child: SizedBox(
        width: 104,
        height: 104,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, widget.level]),
          builder: (context, child) {
            // El anillo exterior crece con el sonido que "oye" el micrófono.
            final extra = 4 + 8 * _pulse.value + 18 * widget.level.value;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (listening)
                  Positioned(
                    left: -extra,
                    right: -extra,
                    top: -extra,
                    bottom: -extra,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: background.withValues(
                          alpha: 0.16 + 0.22 * widget.level.value,
                        ),
                      ),
                    ),
                  ),
                // Aro suave fijo alrededor del botón
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: background.withValues(alpha: 0.22),
                    ),
                  ),
                ),
                child!,
              ],
            );
          },
          child: Center(
            child: Material(
              color: background,
              shape: const CircleBorder(),
              elevation: widget.enabled ? 4 : 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onTap,
                child: SizedBox(
                  width: 88,
                  height: 88,
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
