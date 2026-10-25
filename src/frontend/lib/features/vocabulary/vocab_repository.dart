import 'vocab_models.dart';
import 'vocabulary_manifest.dart';

/// El vocabulario viene de vocabulary_manifest.dart, empaquetado en la app,
/// así que funciona sin internet.
class VocabularyRepository {
  static Future<List<VocabCategory>> load() async => kVocabulary;
}
