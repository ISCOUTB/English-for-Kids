import 'dart:math';

import 'package:flutter/material.dart';

/// Pregunta de suma sencilla para que un niño pequeño no entre solo a la zona
/// del tutor. No es seguridad: es una barrera de uso.
class ParentalChallenge {
  const ParentalChallenge(this.a, this.b);

  final int a;
  final int b;

  int get answer => a + b;
  String get question => '¿Cuánto es $a + $b?';

  /// Sumas con resultado de dos cifras (11 a 18): difíciles para 3 a 6 años.
  factory ParentalChallenge.random([Random? random]) {
    final rnd = random ?? Random();
    return ParentalChallenge(6 + rnd.nextInt(4), 5 + rnd.nextInt(5));
  }

  bool accepts(String input) => int.tryParse(input.trim()) == answer;
}

/// Muestra la pregunta; devuelve true solo si la respuesta es correcta.
Future<bool> askParentalGate(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _ParentalGateDialog(challenge: ParentalChallenge.random()),
  );
  return result == true;
}

class _ParentalGateDialog extends StatefulWidget {
  const _ParentalGateDialog({required this.challenge});

  final ParentalChallenge challenge;

  @override
  State<_ParentalGateDialog> createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends State<_ParentalGateDialog> {
  final TextEditingController _input = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.challenge.accepts(_input.text)) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _wrong = true);
      _input.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🔒 Solo para adultos'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.challenge.question,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Escribe el resultado',
              errorText: _wrong ? 'Esa no es la respuesta. Inténtalo otra vez.' : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
          child: const Text('Entrar'),
        ),
      ],
    );
  }
}
