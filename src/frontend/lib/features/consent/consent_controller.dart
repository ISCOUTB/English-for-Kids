import '../../core/api_client.dart';
import '../../core/safe_notifier.dart';
import 'consent.dart';
import 'consent_service.dart';

/// Estado del permiso de voz del tutor. La decisión más reciente es la que vale.
class ConsentController extends SafeChangeNotifier {
  ConsentController(this._service);

  final ConsentService _service;

  bool _loaded = false;
  bool _busy = false;
  String? _error;
  Consent? _voice;

  /// true cuando ya se pudo consultar el estado en el servidor.
  bool get loaded => _loaded;
  bool get busy => _busy;
  String? get error => _error;
  Consent? get lastDecision => _voice;

  /// El micrófono solo puede activarse si esto es true (RNF-04).
  bool get voiceAllowed => _voice?.aceptado ?? false;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      final all = await _service.list();
      final voice = all.where((c) => c.tipo == 'voz').toList();
      _voice = voice.isEmpty
          ? null
          : voice.reduce((a, b) => b.id > a.id ? b : a);
      _loaded = true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'No pudimos consultar el permiso. Intenta de nuevo.';
    }
    notifyListeners();
  }

  /// Acepta (true) o revoca (false). Devuelve true si se guardó.
  Future<bool> setVoice(bool accepted) async {
    _busy = true;
    _error = null;
    notifyListeners();

    var ok = false;
    try {
      _voice = await _service.setVoice(accepted);
      _loaded = true;
      ok = true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Algo salió mal. Intenta de nuevo.';
    }

    _busy = false;
    notifyListeners();
    return ok;
  }
}
