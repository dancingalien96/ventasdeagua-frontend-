class ItemDeuda {
  final String productoNombre;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  ItemDeuda({
    required this.productoNombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory ItemDeuda.fromJson(Map<String, dynamic> json) => ItemDeuda(
        productoNombre: json['producto_nombre'] ?? '',
        cantidad: (json['cantidad'] as num? ?? 0).toInt(),
        precioUnitario: (json['precio_unitario'] as num? ?? 0).toDouble(),
        subtotal: (json['subtotal'] as num? ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'producto_nombre': productoNombre,
        'cantidad': cantidad,
        'precio_unitario': precioUnitario,
        'subtotal': subtotal,
      };
}

class ItemVenta {
  final String productoId;
  final String productoNombre;
  final String? clienteId;
  final String? clienteNombre;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  ItemVenta({
    required this.productoId,
    required this.productoNombre,
    this.clienteId,
    this.clienteNombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory ItemVenta.fromJson(Map<String, dynamic> json) => ItemVenta(
        productoId: json['producto_id'] is Map ? json['producto_id']['_id'] : json['producto_id'],
        productoNombre: json['producto_id'] is Map ? json['producto_id']['nombre'] : '',
        clienteId: json['cliente_id'] is Map ? json['cliente_id']['_id'] : json['cliente_id'],
        clienteNombre: json['cliente_id'] is Map ? json['cliente_id']['nombre'] : null,
        cantidad: json['cantidad'],
        precioUnitario: (json['precio_unitario'] as num).toDouble(),
        subtotal: (json['subtotal'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'producto_id': productoId,
        if (clienteId != null) 'cliente_id': clienteId,
        'cantidad': cantidad,
        'precio_unitario': precioUnitario,
        'subtotal': subtotal,
      };
}

class Venta {
  final String id;
  final String? repartidorNombre;
  final String? clienteId;
  final String? clienteNombre;
  final DateTime fecha;
  final List<ItemVenta> items;
  final double total;
  final double montoPagado;
  final double deuda;
  final String? clienteDeudorId;
  final double? montoDepositado;
  final String? comprobante;
  final String estado;
  final List<ItemDeuda> itemsDeuda;
  final String? nota;

  Venta({
    required this.id,
    this.repartidorNombre,
    this.clienteId,
    this.clienteNombre,
    required this.fecha,
    required this.items,
    required this.total,
    required this.montoPagado,
    required this.deuda,
    this.clienteDeudorId,
    this.montoDepositado,
    this.comprobante,
    required this.estado,
    this.itemsDeuda = const [],
    this.nota,
  });

  bool get tieneDeuda => deuda > 0;

  factory Venta.fromJson(Map<String, dynamic> json) => Venta(
        id: json['_id'],
        repartidorNombre: json['repartidor_id'] is Map ? json['repartidor_id']['nombre'] : null,
        clienteId: json['cliente_id'] is Map ? json['cliente_id']['_id'] : json['cliente_id'],
        clienteNombre: json['cliente_id'] is Map ? json['cliente_id']['nombre'] : null,
        fecha: DateTime.parse(json['fecha'] ?? json['createdAt']),
        items: (json['items'] as List).map((i) => ItemVenta.fromJson(i)).toList(),
        total: (json['total'] as num).toDouble(),
        montoPagado: (json['monto_pagado'] as num? ?? json['total'] as num).toDouble(),
        deuda: (json['deuda'] as num? ?? 0).toDouble(),
        clienteDeudorId: json['cliente_deudor_id'],
        montoDepositado: json['monto_depositado'] != null ? (json['monto_depositado'] as num).toDouble() : null,
        comprobante: json['comprobante'],
        estado: json['estado'],
        itemsDeuda: (json['items_deuda'] as List? ?? [])
            .map((i) => ItemDeuda.fromJson(i)).toList(),
        nota: json['nota'],
      );
}
