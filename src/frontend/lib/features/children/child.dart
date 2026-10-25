class Child {
  const Child({
    required this.id,
    required this.apodo,
    required this.rangoEdad,
    required this.avatar,
  });

  final int id;
  final String apodo;
  final String rangoEdad;
  final String avatar;

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: (json['id'] as num).toInt(),
      apodo: (json['apodo'] ?? '').toString(),
      rangoEdad: (json['rango_edad'] ?? '').toString(),
      avatar: (json['avatar'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'apodo': apodo,
        'rango_edad': rangoEdad,
        'avatar': avatar,
      };
}
