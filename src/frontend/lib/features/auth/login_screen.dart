import 'dart:math' as math;

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
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF3D6), Color(0xFFFFE3E8)],
              ),
            ),
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Spacer(),
                                const _Logo(),
                                const Spacer(),
                                if (error != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: theme
                                              .colorScheme.onErrorContainer,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            error,
                                            style: TextStyle(
                                              color: theme.colorScheme
                                                  .onErrorContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (AppConfig.basicLoginEnabled) ...[
                                  ..._basicForm(busy, isLogin),
                                  const SizedBox(height: 20),
                                ],
                                _GoogleButton(busy: busy, onPressed: _google),
                                const SizedBox(height: 12),
                                Text(
                                  'Espacio para padres, madres y tutores',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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

/// Logo de la app. Busca assets/icon/logo.png (con fondo transparente); si no
/// existe usa assets/icon/icon.png y, si tampoco, el búho de siempre.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    const owl = Text('🦉', textAlign: TextAlign.center, style: TextStyle(fontSize: 96));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: Image.asset(
        'assets/icon/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/icon/icon.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => owl,
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: const Color(0x33000000),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: busy ? null : onPressed,
        child: SizedBox(
          height: 60,
          child: Center(
            child: busy
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GoogleLogo(size: 26),
                      SizedBox(width: 14),
                      Text(
                        'Continuar con Google',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3C4043),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// La "G" de Google dibujada con código (no hace falta ningún archivo).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke,
        size.height - stroke);
    final center = rect.center;

    void arc(Color color, double fromDeg, double sweepDeg) {
      canvas.drawArc(
        rect,
        fromDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(_red, 210, 105); // arriba
    arc(_yellow, 135, 75); // izquierda
    arc(_green, 45, 90); // abajo
    arc(_blue, 0, 45); // derecha

    // Barra horizontal de la "G".
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - stroke / 2,
        size.width,
        center.dy + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
