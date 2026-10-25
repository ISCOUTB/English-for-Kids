import 'package:flutter/material.dart';

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
                        const SizedBox(height: 28),
                        SegmentedButton<AuthMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: AuthMode.login,
                              label: Text('Entrar'),
                            ),
                            ButtonSegment(
                              value: AuthMode.register,
                              label: Text('Crear cuenta'),
                            ),
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
                            if (v == null || v.trim().length < 2) {
                              return 'Escribe tu nombre';
                            }
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
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: busy ? null : _submit,
                          child: busy
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(isLogin ? 'Entrar' : 'Crear cuenta'),
                        ),
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
}
