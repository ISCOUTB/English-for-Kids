import '../../core/api_client.dart';
import 'child.dart';

class ChildrenService {
  ChildrenService(this._api);

  final ApiClient _api;

  Future<List<Child>> list() async {
    final data = await _api.get('/children');
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Child.fromJson)
          .toList();
    }
    throw ApiException('Respuesta inesperada del servidor.');
  }

  Future<Child> create({
    required String apodo,
    required String rangoEdad,
    required String avatar,
  }) async {
    final data = await _api.post(
      '/children',
      body: {'apodo': apodo, 'rango_edad': rangoEdad, 'avatar': avatar},
    );
    if (data is Map<String, dynamic>) return Child.fromJson(data);
    throw ApiException('Respuesta inesperada del servidor.');
  }

  Future<void> delete(int id) async {
    await _api.delete('/children/$id');
  }
}
