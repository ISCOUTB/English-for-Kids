import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/session_storage.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import '../children/add_child_sheet.dart';
import '../children/avatars.dart';
import '../children/child.dart';
import '../children/child_home_screen.dart';
import '../children/children_controller.dart';
import '../children/children_service.dart';
import '../consent/consent_controller.dart';
import '../consent/consent_screen.dart';
import '../consent/consent_service.dart';

/// Pantalla principal del tutor: elige con qué niño se juega y gestiona
/// los perfiles y el permiso de voz.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    required this.api,
    required this.storage,
  });

  final AuthController auth;
  final ApiClient api;
  final SessionStorage storage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ChildrenController _children;
  late final ConsentController _consent;

  @override
  void initState() {
    super.initState();
    _children = ChildrenController(
      service: ChildrenService(widget.api),
      storage: widget.storage,
    );
    _consent = ConsentController(ConsentService(widget.api));
    _refresh();
  }

  @override
  void dispose() {
    _children.dispose();
    _consent.dispose();
    super.dispose();
  }

  Future<void> _refresh() => Future.wait([_children.load(), _consent.load()]);

  void _openConsent() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConsentScreen(controller: _consent)),
    );
  }

  Future<void> _openChild(Child child) async {
    await _children.select(child);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChildHomeScreen(child: child, consent: _consent),
      ),
    );
  }

  Future<void> _addChild() {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddChildSheet(controller: _children),
    );
  }

  Future<void> _deleteChild(Child child) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar a ${child.apodo}?'),
        content: const Text(
          'Se borrará este perfil. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final error = await _children.remove(child);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Perfil eliminado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('English for Kids'),
        actions: [
          ListenableBuilder(
            listenable: _consent,
            builder: (context, _) => IconButton(
              tooltip: 'Permiso de voz',
              icon: Icon(_consent.voiceAllowed ? Icons.mic : Icons.mic_off),
              onPressed: _openConsent,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') widget.auth.logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_children, _consent, widget.auth]),
          builder: (context, _) {
            if (_children.loading && _children.children.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final list = _children.children;

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    '¡Hola, ${widget.auth.tutor?.nombre ?? ''}!',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    list.isEmpty
                        ? 'Crea el primer perfil para empezar.'
                        : '¿Quién va a jugar hoy?',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  if (_children.offline) ...[
                    const MessageBanner(
                      text: 'Sin conexión: mostrando los últimos perfiles '
                          'guardados.',
                      icon: Icons.cloud_off,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_children.error != null) ...[
                    MessageBanner(
                      text: _children.error!,
                      icon: Icons.error_outline,
                      isError: true,
                      actionLabel: 'Reintentar',
                      onAction: _refresh,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_consent.loaded && !_consent.voiceAllowed) ...[
                    MessageBanner(
                      text: 'Activa el permiso de voz para que los niños '
                          'puedan practicar su pronunciación.',
                      icon: Icons.mic_off,
                      actionLabel: 'Revisar permiso',
                      onAction: _openConsent,
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.9,
                    children: [
                      for (final child in list)
                        _ChildCard(
                          child: child,
                          isActive: child.id == _children.activeId,
                          onTap: () => _openChild(child),
                          onDelete: () => _deleteChild(child),
                        ),
                      _AddCard(onTap: _addChild),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  final Child child;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isActive ? primary : const Color(0xFFEADFCB),
          width: isActive ? 3 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      avatarEmoji(child.avatar),
                      style: const TextStyle(fontSize: 52),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      child.apodo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      ageLabel(child.rangoEdad),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                tooltip: 'Opciones',
                icon: const Icon(Icons.more_vert, size: 22),
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle, size: 52, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                'Agregar niño',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
