class Usuario {
  final String id;
  final String nombre;
  final String rol;

  Usuario({required this.id, required this.nombre, required this.rol});

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] ?? json['_id'],
        nombre: json['nombre'],
        rol: json['rol'],
      );

  bool get esAdmin => rol == 'admin';
}
