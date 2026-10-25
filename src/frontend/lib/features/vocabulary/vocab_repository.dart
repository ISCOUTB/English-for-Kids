import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'vocab_models.dart';

/// Lee el vocabulario empaquetado dentro de la app (funciona sin internet).
class VocabularyRepository {
  static const String manifestPath = 'assets/vocabulary/vocabulary.json';

  static List<VocabCategory>? _cache;

  static Future<List<VocabCategory>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(manifestPath);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = ((data['categories'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(VocabCategory.fromJson)
        .where((c) => c.words.isNotEmpty)
        .toList();

    _cache = list;
    return list;
  }
}
