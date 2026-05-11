class PrecioEspecial {
  final String productoId;
  final double precio;

  PrecioEspecial({required this.productoId, required this.precio});

  factory PrecioEspecial.fromJson(Map<String, dynamic> json) => PrecioEspecial(
        productoId: json['producto_id'] is Map ? json['producto_id']['_id'] : json['producto_id'],
        precio: (json['precio'] as num).toDouble(),
      );
}

class Cliente {
  final String id;
  final String nombre;
  final String? direccion;
  final String? telefono;
  final List<PrecioEspecial> preciosEspeciales;
  final double deudaTotal;

  Cliente({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    required this.preciosEspeciales,
    this.deudaTotal = 0,
  });

  bool get tieneDeuda => deudaTotal > 0;

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        id: json['_id'],
        nombre: json['nombre'],
        direccion: json['direccion'],
        telefono: json['telefono'],
        preciosEspeciales: (json['precios_especiales'] as List?)
                ?.map((p) => PrecioEspecial.fromJson(p))
                .toList() ??
            [],
        deudaTotal: (json['deuda_total'] as num? ?? 0).toDouble(),
      );

  double? precioParaProducto(String productoId) {
    try {
      return preciosEspeciales.firstWhere((p) => p.productoId == productoId).precio;
    } catch (_) {
      return null;
    }
  }
}
