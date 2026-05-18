import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/producto.dart';
import '../../models/cliente.dart';
import '../../models/venta.dart';
import '../../services/api_service.dart';

class NuevaVentaScreen extends StatefulWidget {
  final Venta? ventaEditar;
  final List<Venta> ventasHoy;
  final bool redirectedFromExisting;
  const NuevaVentaScreen({
    super.key,
    this.ventaEditar,
    this.ventasHoy = const [],
    this.redirectedFromExisting = false,
  });

  @override
  State<NuevaVentaScreen> createState() => _NuevaVentaScreenState();
}

class _NuevaVentaScreenState extends State<NuevaVentaScreen> {
  List<Producto> _productos = [];
  List<Cliente> _clientes = [];
  final List<ItemVenta> _items = [];
  bool _cargando = true;
  bool _guardando = false;

  Cliente? _clienteVenta;
  bool _quedoDebiendo = false;
  ItemVenta? _productoDeuda;
  int _cantidadDeuda = 1;
  final _notaCtrl = TextEditingController();

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  bool get _esEdicion => widget.ventaEditar != null;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    if (widget.redirectedFromExisting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Este cliente ya tiene una venta hoy — editándola'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ));
        }
      });
    }
  }

  Future<void> _cargarDatos() async {
    try {
      final productos = await ApiService.get('/productos');
      final clientes = await ApiService.get('/clientes');
      if (!mounted) return;
      final listaClientes = (clientes as List).map((c) => Cliente.fromJson(c)).toList();
      setState(() {
        _productos = (productos as List).map((p) => Producto.fromJson(p)).toList();
        _clientes = listaClientes;
        _cargando = false;
        if (_esEdicion) {
          _items.addAll(widget.ventaEditar!.items);
          _notaCtrl.text = widget.ventaEditar!.nota ?? '';
          _clienteVenta = listaClientes.where(
              (c) => c.id == widget.ventaEditar!.clienteId).firstOrNull;
          if (widget.ventaEditar!.itemsDeuda.isNotEmpty) {
            final itemDeuda = widget.ventaEditar!.itemsDeuda.first;
            _productoDeuda = _items.where(
                (i) => i.productoNombre == itemDeuda.productoNombre).firstOrNull;
            _cantidadDeuda = itemDeuda.cantidad;
            _quedoDebiendo = true;
          } else if (widget.ventaEditar!.deuda > 0) {
            _quedoDebiendo = true;
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _agregarItem() {
    showDialog(
      context: context,
      builder: (_) => _DialogAgregarItem(
        productos: _productos,
        clienteVenta: _clienteVenta,
        onAgregar: (item) => setState(() => _items.add(item)),
      ),
    );
  }

  double get _total => _items.fold(0, (s, i) => s + i.subtotal);

  double get _deuda {
    if (!_quedoDebiendo || _productoDeuda == null) return 0;
    return (_cantidadDeuda * _productoDeuda!.precioUnitario).clamp(0, _total);
  }

  Future<void> _guardarVenta() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agrega al menos un producto'), backgroundColor: Colors.orange));
      return;
    }
    if (_quedoDebiendo && _clienteVenta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona un cliente para registrar la deuda'), backgroundColor: Colors.orange));
      return;
    }
    if (_quedoDebiendo && _productoDeuda == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona el producto que quedó debiendo'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _guardando = true);
    try {
      final montoPagado = _quedoDebiendo && _productoDeuda != null
          ? _total - _deuda
          : _total;

      final body = {
        'items': _items.map((i) => i.toJson()).toList(),
        'monto_pagado': montoPagado,
        if (_clienteVenta != null) 'cliente_id': _clienteVenta!.id,
        if (_notaCtrl.text.trim().isNotEmpty) 'nota': _notaCtrl.text.trim(),
        'items_deuda': (_quedoDebiendo && _productoDeuda != null) ? [
          {
            'producto_nombre': _productoDeuda!.productoNombre,
            'cantidad': _cantidadDeuda,
            'precio_unitario': _productoDeuda!.precioUnitario,
            'subtotal': _cantidadDeuda * _productoDeuda!.precioUnitario,
          }
        ] : [],
      };

      if (_esEdicion) {
        await ApiService.put('/ventas/${widget.ventaEditar!.id}', body);
      } else {
        await ApiService.post('/ventas', body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_esEdicion ? 'Venta actualizada' : 'Venta registrada'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al guardar'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es', symbol: 'Q');

    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Venta' : 'Nueva Venta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Información',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(_esEdicion ? 'Editar Venta' : 'Nueva Venta'),
                content: Text(_esEdicion
                    ? 'Modifica los productos, cantidades o el estado de pago de esta venta. Solo puedes editar ventas del día actual que no hayan sido incluidas en un cierre.'
                    : 'Selecciona el cliente, agrega los productos y la cantidad. Si el cliente no pagó el total, activa "¿Quedó debiendo?". Si ya hay una venta para ese cliente hoy, los productos se agregan automáticamente a ese registro.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: _guardando ? null : _guardarVenta,
            child: _guardando
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Guardar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [

                      // ── Selector de cliente ──────────────────────────────
                      if (_esEdicion && _clienteVenta != null)
                        // En edición: solo mostrar el cliente, no cambiarlo
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(children: [
                            Icon(Icons.store_outlined, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 10),
                            Text(_clienteVenta!.nombre,
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800, fontSize: 15)),
                          ]),
                        )
                      else
                        DropdownButtonFormField<Cliente>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Cliente',
                            hintText: 'Seleccionar (o dejar vacío para venta casual)',
                            prefixIcon: Icon(Icons.store_outlined),
                          ),
                          initialValue: _clienteVenta,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Venta casual (sin cliente)')),
                            ..._clientes.map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Row(children: [
                                    Flexible(
                                      child: Text(c.nombre,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    if (c.tieneDeuda) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.warning_amber_rounded,
                                          size: 14, color: Colors.orange.shade700),
                                    ],
                                  ]),
                                )),
                          ],
                          onChanged: (c) {
                            if (c != null && widget.ventasHoy.isNotEmpty) {
                              final existente = widget.ventasHoy
                                  .where((v) => v.clienteId == c.id)
                                  .firstOrNull;
                              if (existente != null) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NuevaVentaScreen(
                                      ventaEditar: existente,
                                      redirectedFromExisting: true,
                                    ),
                                  ),
                                );
                                return;
                              }
                            }
                            setState(() {
                              _clienteVenta = c;
                              if (c == null) {
                                _quedoDebiendo = false;
                                _productoDeuda = null;
                                _cantidadDeuda = 1;
                              }
                            });
                          },
                        ),

                      const SizedBox(height: 16),

                      // ── Lista de items ───────────────────────────────────
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('Sin productos aún',
                              style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ..._items.asMap().entries.map((entry) {
                          final i = entry.key;
                          final item = entry.value;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(item.productoNombre),
                              subtitle: Text('x${item.cantidad}'),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(fmt.format(item.subtotal),
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => setState(() {
                                    final removed = _items[i];
                                    _items.removeAt(i);
                                    if (_productoDeuda == removed) {
                                      _productoDeuda = null;
                                      _cantidadDeuda = 1;
                                    }
                                  }),
                                ),
                              ]),
                            ),
                          );
                        }),

                      if (_items.isNotEmpty) ...[
                        const Divider(height: 24),

                        // ── Nota opcional ────────────────────────────────
                        TextField(
                          controller: _notaCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Nota (opcional)',
                            hintText: 'Ej: quedaron debiendo 5 bolsas...',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Sección de deuda (solo si hay cliente) ───────
                        if (_clienteVenta != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _quedoDebiendo
                                  ? Colors.orange.shade50
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _quedoDebiendo
                                    ? Colors.orange.shade200
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('¿Quedó debiendo?',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 15)),
                                  Switch(
                                    value: _quedoDebiendo,
                                    activeThumbColor: Colors.orange,
                                    onChanged: (val) => setState(() {
                                      _quedoDebiendo = val;
                                      if (!val) {
                                        _productoDeuda = null;
                                        _cantidadDeuda = 1;
                                      }
                                    }),
                                  ),
                                ],
                              ),
                              if (_quedoDebiendo) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.person_outline,
                                        size: 16, color: Colors.orange.shade800),
                                    const SizedBox(width: 8),
                                    Text(_clienteVenta!.nombre,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade800)),
                                  ]),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<ItemVenta>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Producto que quedó debiendo',
                                    prefixIcon: Icon(Icons.inventory_2_outlined),
                                  ),
                                  initialValue: _productoDeuda,
                                  items: _items.map((item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item.productoNombre,
                                        overflow: TextOverflow.ellipsis),
                                  )).toList(),
                                  onChanged: (item) => setState(() {
                                    _productoDeuda = item;
                                    if (item != null && _cantidadDeuda > item.cantidad) {
                                      _cantidadDeuda = item.cantidad;
                                    }
                                  }),
                                ),
                                if (_productoDeuda != null) ...[
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    const Text('Cantidad que debió:',
                                        style: TextStyle(fontWeight: FontWeight.w500)),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: _cantidadDeuda > 1
                                          ? () => setState(() => _cantidadDeuda--)
                                          : null,
                                    ),
                                    Text('$_cantidadDeuda',
                                        style: const TextStyle(
                                            fontSize: 18, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: _cantidadDeuda < _productoDeuda!.cantidad
                                          ? () => setState(() => _cantidadDeuda++)
                                          : null,
                                    ),
                                  ]),
                                ],
                                if (_deuda > 0) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Row(children: [
                                            Icon(Icons.warning_amber_rounded,
                                                color: Colors.red, size: 18),
                                            SizedBox(width: 6),
                                            Text('Queda debiendo:',
                                                style: TextStyle(color: Colors.red)),
                                          ]),
                                          Text(fmt.format(_deuda),
                                              style: const TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                        ]),
                                  ),
                                ],
                              ],
                            ]),
                          ),
                      ],
                    ],
                  ),
                ),

                // ── Barra inferior ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Total: ${fmt.format(_total)}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                          if (_quedoDebiendo && _deuda > 0)
                            Text('Paga ahora: ${fmt.format(_total - _deuda)}',
                                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                                overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _agregarItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Dialog para agregar item ──────────────────────────────────────────────────

class _DialogAgregarItem extends StatefulWidget {
  final List<Producto> productos;
  final Cliente? clienteVenta;
  final Function(ItemVenta) onAgregar;

  const _DialogAgregarItem({
    required this.productos,
    required this.clienteVenta,
    required this.onAgregar,
  });

  @override
  State<_DialogAgregarItem> createState() => _DialogAgregarItemState();
}

class _DialogAgregarItemState extends State<_DialogAgregarItem> {
  Producto? _producto;
  int _cantidad = 1;
  double _precio = 0;

  void _onProductoChanged(Producto? p) {
    setState(() {
      _producto = p;
      _precio = widget.clienteVenta?.precioParaProducto(p?.id ?? '') ?? p?.precioBase ?? 0;
    });
  }

  void _agregar() {
    if (_producto == null) return;
    widget.onAgregar(ItemVenta(
      productoId: _producto!.id,
      productoNombre: _producto!.nombre,
      cantidad: _cantidad,
      precioUnitario: _precio,
      subtotal: _precio * _cantidad,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es', symbol: 'Q');
    return AlertDialog(
      title: const Text('Agregar producto'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<Producto>(
            decoration: const InputDecoration(labelText: 'Producto'),
            items: widget.productos
                .map((p) => DropdownMenuItem(value: p, child: Text(p.nombre)))
                .toList(),
            onChanged: _onProductoChanged,
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Cantidad:'),
            const SizedBox(width: 12),
            IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () =>
                    setState(() { if (_cantidad > 1) _cantidad--; })),
            Text('$_cantidad',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _cantidad++)),
          ]),
          const SizedBox(height: 8),
          Text('Precio: ${fmt.format(_precio)} · Total: ${fmt.format(_precio * _cantidad)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: _producto != null ? _agregar : null,
            child: const Text('Agregar')),
      ],
    );
  }
}
