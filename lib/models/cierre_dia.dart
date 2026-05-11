class CierreDia {
  final String id;
  final String? repartidorNombre;
  final String fecha;
  final double totalVentas;
  final double montoDepositado;
  final String comprobante;
  final String estado;
  final String? notaRechazo;

  CierreDia({
    required this.id,
    this.repartidorNombre,
    required this.fecha,
    required this.totalVentas,
    required this.montoDepositado,
    required this.comprobante,
    required this.estado,
    this.notaRechazo,
  });

  factory CierreDia.fromJson(Map<String, dynamic> json) => CierreDia(
        id: json['_id'],
        repartidorNombre: json['repartidor_id'] is Map ? json['repartidor_id']['nombre'] : null,
        fecha: json['fecha'],
        totalVentas: (json['total_ventas'] as num).toDouble(),
        montoDepositado: (json['monto_depositado'] as num).toDouble(),
        comprobante: json['comprobante'],
        estado: json['estado'],
        notaRechazo: json['nota_rechazo'],
      );

  bool get aprobado => estado == 'aprobado';
  bool get rechazado => estado == 'rechazado';
  bool get pendiente => estado == 'pendiente';
}
