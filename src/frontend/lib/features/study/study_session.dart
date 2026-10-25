import '../children/child.dart';
import '../consent/consent_controller.dart';
import 'progress_repository.dart';
import 'speech_judge_service.dart';

/// Lo que necesitan las pantallas de estudio: el niño activo, el permiso de
/// voz y los servicios de reconocimiento y progreso.
class StudySession {
  const StudySession({
    required this.child,
    required this.consent,
    required this.speech,
    required this.progress,
  });

  final Child child;
  final ConsentController consent;
  final SpeechJudgeService speech;
  final ProgressRepository progress;
}
