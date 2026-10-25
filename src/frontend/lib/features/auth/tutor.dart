class Tutor {
  const Tutor({this.id, required this.nombre, required this.correo});

  final String? id;
  final String nombre;
  final String correo;

  factory Tutor.fromJson(Map<String, dynamic> json) {
    final inner = json['tutor'] ?? json['user'] ?? json['usuario'];
    final data = inner is Map<String, dynamic> ? inner : json;
    return Tutor(
      id: data['id']?.toString(),
      nombre: (data['nombre'] ?? data['name'] ?? '').toString(),
      correo: (data['correo'] ?? data['email'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'correo': correo,
      };
}
