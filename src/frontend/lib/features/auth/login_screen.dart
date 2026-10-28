import 'package:flutter/material.dart';

import '../../core/config.dart';
import 'auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _correoFocus = FocusNode();

  AuthMode _mode = AuthMode.login;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _correoFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await widget.auth.submit(
      _mode,
      nombre: _nombre.text.trim(),
      correo: _correo.text.trim(),
    );
  }

  Future<void> _google() async {
    FocusScope.of(context).unfocus();
    await widget.auth.signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        final busy = widget.auth.busy;
        final error = widget.auth.error;
        final isLogin = _mode == AuthMode.login;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '🦉',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 72),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'English for Kids',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Espacio para padres, madres y tutores',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 32),
                        _GoogleButton(busy: busy, onPressed: _google),
                        const SizedBox(height: 10),
                        Text(
                          'Elige la cuenta de Google con la que quieres entrar. '
                          'Si es tu primera vez, se crea tu cuenta automáticamente.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                        if (AppConfig.basicLoginEnabled) ...[
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'solo pruebas',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._basicForm(busy, isLogin),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    error,
                                    style: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Acceso con nombre y correo (sin verificar). Solo se muestra en compilaciones
  /// de prueba (BASIC_LOGIN=true).
  List<Widget> _basicForm(bool busy, bool isLogin) {
    return [
      SegmentedButton<AuthMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: AuthMode.login, label: Text('Entrar')),
          ButtonSegment(value: AuthMode.register, label: Text('Crear cuenta')),
        ],
        selected: {_mode},
        onSelectionChanged: busy
            ? null
            : (s) {
                setState(() => _mode = s.first);
                widget.auth.clearError();
              },
      ),
      const SizedBox(height: 20),
      TextFormField(
        controller: _nombre,
        enabled: !busy,
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.name],
        decoration: const InputDecoration(
          labelText: 'Nombre',
          prefixIcon: Icon(Icons.person_outline),
        ),
        validator: (v) {
          if (v == null || v.trim().length < 2) return 'Escribe tu nombre';
          return null;
        },
        onFieldSubmitted: (_) => _correoFocus.requestFocus(),
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _correo,
        focusNode: _correoFocus,
        enabled: !busy,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(
          labelText: 'Correo',
          prefixIcon: Icon(Icons.mail_outline),
        ),
        validator: (v) {
          if (v == null || !_emailRegex.hasMatch(v.trim())) {
            return 'Escribe un correo válido';
          }
          return null;
        },
        onFieldSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: busy ? null : _submit,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(isLogin ? 'Entrar con nombre y correo' : 'Crear cuenta'),
      ),
    ];
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF3C4043),
        disabledBackgroundColor: Colors.white70,
        side: const BorderSide(color: Color(0xFFDADCE0)),
        minimumSize: const Size.fromHeight(58),
      ),
      child: busy
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'G',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4285F4),
                  ),
                ),
                SizedBox(width: 12),
                Text('Continuar con Google'),
              ],
            ),
    );
  }
}
