import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/cliente.dart';
import '../../models/producto.dart';
import '../../models/venta.dart';
import '../../services/api_service.dart';

class AdminClientesScreen extends StatefulWidget {
  const AdminClientesScreen({super.key});

  @override
  State<AdminClientesScreen> createState() => _AdminClientesScreenState();
}

class _AdminClientesScreenState extends State<AdminClientesScreen>
    with SingleTickerProviderStateMixin {
  List<Cliente> _clientes = [];
  List<Producto> _productos = [];
  bool _cargando = true;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
    _cargarDatos();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final results = await Future.wait([
        ApiService.get('/clientes'),
        ApiService.get('/productos'),
      ]);
      if (!mounted) return;
      setState(() {
        _clientes = (results[0] as List).map((e) => Cliente.fromJson(e)).toList();
        _productos = (results[1] as List).map((e) => Producto.fromJson(e)).toList();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarFormCliente({Cliente? cliente}) {
    final nombreCtrl = TextEditingController(text: cliente?.nombre ?? '');
    final dirCtrl = TextEditingController(text: cliente?.direccion ?? '');
    final telCtrl = TextEditingController(text: cliente?.telefono ?? '');
    final preciosCtrl = <String, TextEditingController>{
      for (var p in _productos)
        p.id: TextEditingController(
          text: cliente?.precioParaProducto(p.id)?.toString() ?? '',
        )
    };
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cliente == null ? 'Nuevo cliente' : 'Editar cliente',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del negocio')),
                const SizedBox(height: 10),
                TextField(controller: dirCtrl,
                    decoration: const InputDecoration(labelText: 'Dirección')),
                const SizedBox(height: 10),
                TextField(controller: telCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono')),
                const SizedBox(height: 16),
                const Text('Precios especiales',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._productos.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: preciosCtrl[p.id],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: p.nombre,
                          hintText: 'Precio base: Q${p.precioBase}',
                          prefixText: 'Q ',
                        ),
                      ),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final preciosEspeciales = _productos
                          .where((p) => preciosCtrl[p.id]!.text.isNotEmpty)
                          .map((p) => {
                                'producto_id': p.id,
                                'precio': double.parse(preciosCtrl[p.id]!.text)
                              })
                          .toList();
                      final body = {
                        'nombre': nombreCtrl.text,
                        'direccion': dirCtrl.text,
                        'telefono': telCtrl.text,
                        'precios_especiales': preciosEspeciales,
                      };
                      if (cliente == null) {
                        await ApiService.post('/clientes', body);
                      } else {
                        await ApiService.put('/clientes/${cliente.id}', body);
                      }
                      if (mounted) Navigator.pop(context);
                      _cargarDatos();
                    },
                    child: const Text('Guardar'),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
        ),
      ),
    );
  }

  Future<void> _verDetalleDeuda(Cliente cliente) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final data = await ApiService.get('/ventas?cliente_id=${cliente.id}');
      if (!mounted) return;
      Navigator.pop(context);
      final ventas = (data as List)
          .map((v) => Venta.fromJson(v))
          .where((v) => v.tieneDeuda || v.itemsDeuda.isNotEmpty)
          .toList();
      _mostrarDeudaSheet(cliente, ventas);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _mostrarDeudaSheet(Cliente cliente, List<Venta> ventas) {
    final fmt = NumberFormat.currency(locale: 'es', symbol: 'Q');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.35,
        expand: false,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cliente.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Deuda total: ${fmt.format(cliente.deudaTotal)}',
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
              ])),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _registrarPago(cliente);
                },
                icon: const Icon(Icons.payments_outlined, size: 16),
                label: const Text('Cobrar'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Ventas con deuda pendiente',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Expanded(
              child: ventas.isEmpty
                  ? const Center(
                      child: Text('Sin ventas con deuda registradas',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: ctrl,
                      itemCount: ventas.length,
                      itemBuilder: (_, i) =>
                          _TarjetaVentaDeuda(venta: ventas[i], fmt: fmt),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _registrarPago(Cliente cliente) async {
    final fmt = NumberFormat.currency(locale: 'es', symbol: 'Q');
    final montoCtrl = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Cobrar deuda — ${cliente.nombre}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Deuda actual:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(fmt.format(cliente.deudaTotal),
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Monto que pagó', prefixText: 'Q '),
            autofocus: true,
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Registrar pago'),
          ),
        ],
      ),
    );
    if (confirmar != true || montoCtrl.text.isEmpty) return;
    await ApiService.post('/ventas/pagar-deuda', {
      'cliente_id': cliente.id,
      'monto': double.parse(montoCtrl.text),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Pago registrado'), backgroundColor: Colors.green));
      _cargarDatos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es', symbol: 'Q');
    final deudores = _clientes.where((c) => c.tieneDeuda).toList();

    return Scaffold(
      body: Column(children: [
        // TabBar pegado arriba del body
        Material(
          color: Theme.of(context).colorScheme.primary,
          child: TabBar(
            controller: _tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              const Tab(text: 'Clientes'),
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Deudas'),
                  if (deudores.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${deudores.length}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        ),

        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tab,
                  children: [
                    // ── Tab 1: Clientes ──────────────────────────────────
                    _clientes.isEmpty
                        ? Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                Icon(Icons.store_outlined,
                                    size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                const Text('Sin clientes registrados',
                                    style: TextStyle(color: Colors.grey)),
                              ]))
                        : RefreshIndicator(
                            onRefresh: _cargarDatos,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _clientes.length,
                              itemBuilder: (_, i) {
                                final c = _clientes[i];
                                return _TarjetaClienteSimple(
                                  cliente: c,
                                  onEditar: () => _mostrarFormCliente(cliente: c),
                                );
                              },
                            ),
                          ),

                    // ── Tab 2: Deudas ────────────────────────────────────
                    deudores.isEmpty
                        ? Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                Icon(Icons.check_circle_outline,
                                    size: 64, color: Colors.green.shade200),
                                const SizedBox(height: 12),
                                const Text('Sin deudas pendientes',
                                    style: TextStyle(color: Colors.grey)),
                              ]))
                        : RefreshIndicator(
                            onRefresh: _cargarDatos,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: deudores.length + 1,
                              itemBuilder: (_, i) {
                                if (i == 0) {
                                  // Resumen total deuda
                                  final totalDeuda = deudores.fold<double>(
                                      0, (s, c) => s + c.deudaTotal);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(children: [
                                      Icon(Icons.warning_amber_rounded,
                                          color: Colors.red.shade400, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${deudores.length} cliente(s) con deuda pendiente',
                                          style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w600)),
                                      ),
                                      Text(fmt.format(totalDeuda),
                                          style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15)),
                                    ]),
                                  );
                                }
                                final c = deudores[i - 1];
                                return _TarjetaDeudor(
                                  cliente: c,
                                  fmt: fmt,
                                  onCobrar: () => _registrarPago(c),
                                  onTap: () => _verDetalleDeuda(c),
                                );
                              },
                            ),
                          ),
                  ],
                ),
        ),
      ]),
      // FAB solo en tab Clientes
      floatingActionButton: _tab.index == 0
          ? FloatingActionButton(
              onPressed: () => _mostrarFormCliente(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ── Tarjeta Tab Clientes ──────────────────────────────────────────────────────

class _TarjetaClienteSimple extends StatelessWidget {
  final Cliente cliente;
  final VoidCallback onEditar;

  const _TarjetaClienteSimple({required this.cliente, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    final tienePreciosEspeciales = cliente.preciosEspeciales.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Text(cliente.nombre[0].toUpperCase(),
                style: TextStyle(
                    color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cliente.nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (cliente.direccion != null && cliente.direccion!.isNotEmpty)
                Text(cliente.direccion!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              if (cliente.telefono != null && cliente.telefono!.isNotEmpty)
                Text(cliente.telefono!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              if (tienePreciosEspeciales) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.sell_outlined, size: 12, color: Colors.blue.shade400),
                  const SizedBox(width: 4),
                  Text(
                    '${cliente.preciosEspeciales.length} precio(s) especial(es)',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
                  ),
                ]),
              ],
            ]),
          ),
          IconButton(
              icon: const Icon(Icons.edit_outlined), onPressed: onEditar),
        ]),
      ),
    );
  }
}

// ── Tarjeta Tab Deudas ────────────────────────────────────────────────────────

class _TarjetaDeudor extends StatelessWidget {
  final Cliente cliente;
  final NumberFormat fmt;
  final VoidCallback onCobrar;
  final VoidCallback onTap;

  const _TarjetaDeudor({
    required this.cliente,
    required this.fmt,
    required this.onCobrar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: Colors.red.shade100,
              child: Text(cliente.nombre[0].toUpperCase(),
                  style: TextStyle(
                      color: Colors.red.shade700, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cliente.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (cliente.direccion != null && cliente.direccion!.isNotEmpty)
                  Text(cliente.direccion!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(fmt.format(cliente.deudaTotal),
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ]),
            ),
            TextButton.icon(
              onPressed: onCobrar,
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text('Cobrar'),
              style: TextButton.styleFrom(foregroundColor: Colors.green),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ]),
        ),
      ),
    );
  }
}

// ── Tarjeta ventas con deuda (bottom sheet) ───────────────────────────────────

class _TarjetaVentaDeuda extends StatelessWidget {
  final Venta venta;
  final NumberFormat fmt;

  const _TarjetaVentaDeuda({required this.venta, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final fechaStr = DateFormat('dd/MM/yyyy', 'es').format(venta.fecha);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(fechaStr,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold)),
          Text('Debe: ${fmt.format(venta.deuda)}',
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        if (venta.itemsDeuda.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...venta.itemsDeuda.map((item) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const Icon(Icons.arrow_right, size: 14, color: Colors.red),
                  Text('${item.cantidad}x ${item.productoNombre}',
                      style: const TextStyle(fontSize: 13)),
                  const Spacer(),
                  Text(fmt.format(item.subtotal),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ]),
              )),
        ],
        if (venta.nota != null && venta.nota!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Nota: ${venta.nota}',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}
