import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import 'consent.dart';
import 'consent_controller.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, required this.controller});

  final ConsentController controller;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _isGuardian = false;

  ConsentController get _c => widget.controller;

  Future<void> _accept() async {
    final ok = await _c.setVoice(true);
    if (ok && mounted) {
      setState(() => _isGuardian = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de voz activado.')),
      );
    }
  }

  Future<void> _revoke() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Revocar el permiso?'),
        content: const Text(
          'El micrófono dejará de usarse y los niños no podrán practicar '
          'su pronunciación hasta que vuelvas a aceptar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await _c.setVoice(false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de voz revocado.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Permiso de voz')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            final allowed = _c.voiceAllowed;
            final date = _c.lastDecision?.fecha;

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: allowed
                        ? const Color(0xFFE3F5E1)
                        : const Color(0xFFFFEBD6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        allowed ? Icons.mic : Icons.mic_off,
                        size: 36,
                        color: allowed
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              allowed ? 'Permiso activo' : 'Sin permiso',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (date != null)
                              Text(
                                'Última decisión: ${formatDateTime(date)}',
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Para qué se usa la voz?',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Para practicar la pronunciación, la app graba la voz del '
                  'niño cuando toca el botón de hablar y envía esa grabación '
                  'a un servicio externo que reconoce lo que dijo.',
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sin tu permiso, el micrófono no se activa. Puedes '
                  'revocarlo cuando quieras desde esta pantalla.',
                ),
                const SizedBox(height: 20),
                if (_c.error != null) ...[
                  MessageBanner(
                    text: _c.error!,
                    icon: Icons.error_outline,
                    isError: true,
                    actionLabel: _c.loaded ? null : 'Reintentar',
                    onAction: _c.loaded ? null : _c.load,
                  ),
                  const SizedBox(height: 16),
                ],
                if (!allowed) ...[
                  CheckboxListTile(
                    value: _isGuardian,
                    onChanged:
                        _c.busy ? null : (v) => setState(() => _isGuardian = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Soy el padre, madre o tutor y autorizo que se use la '
                      'voz del niño para practicar inglés.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: (_isGuardian && !_c.busy) ? _accept : null,
                    child: _c.busy
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Aceptar y activar'),
                  ),
                ] else
                  OutlinedButton(
                    onPressed: _c.busy ? null : _revoke,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      foregroundColor: theme.colorScheme.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _c.busy
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Text('Revocar permiso'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
