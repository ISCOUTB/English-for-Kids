import 'dart:async';

import 'package:flutter/material.dart';

import 'study_config.dart';

/// Personaje con tres posiciones de boca. Mientras su idioma está sonando
/// alterna los cuadros 1-2-3-2; al terminar vuelve al 1 (boca cerrada).
class TalkingCharacter extends StatefulWidget {
  const TalkingCharacter({
    super.key,
    required this.folder,
    required this.language,
    required this.speakingLanguage,
    required this.onTap,
    this.height = 150,
  });

  /// Carpeta del personaje dentro de assets/personajes/ (nino o nina).
  final String folder;

  /// Idioma que habla este personaje.
  final Lang language;

  /// Idioma que suena ahora mismo (null si no suena nada).
  final Lang? speakingLanguage;

  final VoidCallback onTap;
  final double height;

  @override
  State<TalkingCharacter> createState() => _TalkingCharacterState();
}

class _TalkingCharacterState extends State<TalkingCharacter> {
  Timer? _timer;
  int _step = 0;
  double _scale = 1;
  bool _precached = false;

  bool get _talking => widget.speakingLanguage == widget.language;

  String _path(int frame) =>
      'assets/personajes/${widget.folder}/${widget.folder}_$frame.png';

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    for (var frame = 1; frame <= 3; frame++) {
      final path = _path(frame);
      precacheImage(
        AssetImage(path),
        context,
        onError: (e, st) => debugPrint('⚠️ No se encontró $path'),
      );
    }
  }

  @override
  void didUpdateWidget(TalkingCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    if (_talking) {
      _timer ??= Timer.periodic(kMouthFrameInterval, (_) {
        if (mounted) setState(() => _step++);
      });
    } else if (_timer != null) {
      _timer!.cancel();
      _timer = null;
      _step = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tap() async {
    widget.onTap();
    setState(() => _scale = 1.08);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    setState(() => _scale = 1);
  }

  @override
  Widget build(BuildContext context) {
    final frame = _talking ? kMouthSequence[_step % kMouthSequence.length] : 1;
    final path = _path(frame);

    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 80, minHeight: 80),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: Image.asset(
              path,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) {
                debugPrint('⚠️ No se encontró $path');
                return Center(
                  child: Text(
                    widget.language == Lang.en ? '🧒' : '👧',
                    style: const TextStyle(fontSize: 64),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
