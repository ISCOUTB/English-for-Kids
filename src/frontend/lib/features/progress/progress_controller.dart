import '../../core/api_client.dart';
import '../../core/safe_notifier.dart';
import '../study/progress_repository.dart';
import 'progress_models.dart';
import 'progress_service.dart';

enum ProgressStatus { loading, ready, error }

/// Estado del panel de progreso de UN niño.
class ProgressController extends SafeChangeNotifier {
  ProgressController({
    required this.service,
    required this.repository,
    required this.childId,
  });

  final ProgressService service;
  final ProgressRepository repository;
  final int childId;

  ProgressStatus _status = ProgressStatus.loading;
  ProgressSummary? _summary;
  String? _error;

  ProgressStatus get status => _status;
  ProgressSummary? get summary => _summary;
  String? get error => _error;

  /// Intentos de este niño que aún no se han podido enviar al servidor.
  int get pendingAttempts => repository.pendingFor(childId);

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _status = ProgressStatus.loading;
      _error = null;
      notifyListeners();
    }

    // Primero se envían los intentos pendientes, para que el resumen esté al día.
    await repository.flush();

    try {
      _summary = await service.summary(childId);
      _status = ProgressStatus.ready;
      _error = null;
    } on ApiException catch (e) {
      _fail(e.message, silent);
    } catch (_) {
      _fail('No pudimos cargar el progreso. Intenta de nuevo.', silent);
    }
    notifyListeners();
  }

  void _fail(String message, bool silent) {
    // Un refresco que falla no borra lo que ya se estaba mostrando.
    if (silent && _summary != null) return;
    _error = message;
    _status = ProgressStatus.error;
  }

  /// Borra el progreso. Devuelve un mensaje de error, o null si salió bien.
  Future<String?> reset() async {
    try {
      repository.discardPending(childId);
      await service.reset(childId);
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'No pudimos borrar el progreso. Intenta de nuevo.';
    }
    await load(silent: true);
    return null;
  }
}
