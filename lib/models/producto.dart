class Producto {
  final String id;
  final String nombre;
  final double precioBase;

  Producto({required this.id, required this.nombre, required this.precioBase});

  factory Producto.fromJson(Map<String, dynamic> json) => Producto(
        id: json['_id'],
        nombre: json['nombre'],
        precioBase: (json['precio_base'] as num).toDouble(),
      );
}
