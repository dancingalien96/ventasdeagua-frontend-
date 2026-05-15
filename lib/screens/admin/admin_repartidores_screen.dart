import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/cierre_dia.dart';
import '../../services/api_service.dart';

class _RepartidorData {
  final String id;
  final String nombre;
  final String email;
  final double totalVentas;
  final int numVentas;
  final int totalCierres;
  final int cierresPendientes;

  _RepartidorData({
    required this.id,
    required this.nombre,
    required this.email,
    required this.totalVentas,
    required this.numVentas,
    required this.totalCierres,
    required this.cierresPendientes,
  });

  factory _RepartidorData.fromJson(Map<String, dynamic> json) {
    final s = json['stats'] as Map<String, dynamic>? ?? {};
    return _RepartidorData(
      id: json['_id'],
      nombre: json['nombre'],
      email: json['email'],
      totalVentas: (s['total_ventas'] as num? ?? 0).toDouble(),
      numVentas: (s['num_ventas'] as num? ?? 0).toInt(),
      totalCierres: (s['total_cierres'] as num? ?? 0).toInt(),
      cierresPendientes: (s['cierres_pendientes'] as num? ?? 0).toInt(),
    );
  }
}

// ── Pantalla principal: lista de repartidores ─────────────────────────────────

class AdminRepartidoresScreen extends StatefulWidget {
  const AdminRepartidoresScreen({super.key});

  @override
  State<AdminRepartidoresScreen> createState() => _AdminRepartidoresScreenState();
}

class _AdminRepartidoresScreenState extends State<AdminRepartidoresScreen> {
  List<_RepartidorData> _repartidores = [];
  List<CierreDia> _cierres = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final rData = await ApiService.get('/auth/repartidores');
      final cData = await ApiService.get('/cierres');
      if (!mounted) return;
      setState(() {
        _repartidores = (rData as List).map((r) => _RepartidorData.fromJson(r)).toList();
        _cierres = (cData as List).map((c) => CierreDia.fromJson(c)).toList();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarFormNuevo() {
    final nombreCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => SingleChildScrollView(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20, right: 20, top: 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nuevo repartidor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre completo')),
            const SizedBox(height: 10),
            TextField(controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo electrónico')),
            const SizedBox(height: 10),
            TextField(controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña inicial')),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: guardando ? null : () async {
                  if (nombreCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
                  setModal(() => guardando = true);
                  try {
                    await ApiService.post('/auth/repartidores', {
                      'nombre': nombreCtrl.text,
                      'email': emailCtrl.text,
                      'password': passCtrl.text,
                    });
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Repartidor creado'), backgroundColor: Colors.green));
                      _cargar();
                    }
                  } catch (_) {
                    setModal(() => guardando = false);
                  }
                },
                child: guardando
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Crear repartidor'),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Future<void> _eliminar(_RepartidorData r) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar repartidor'),
        content: Text('¿Eliminar la cuenta de ${r.nombre}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await ApiService.delete('/auth/repartidores/${r.id}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repartidor eliminado'), backgroundColor: Colors.green));
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es', symbol: 'Q');

    Widget body = _cargando
        ? const Center(child: CircularProgressIndicator())
        : _repartidores.isEmpty
            ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('Sin repartidores registrados', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _mostrarFormNuevo,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar repartidor'),
                  ),
                ]),
              )
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _repartidores.length,
                  itemBuilder: (_, i) {
                    final r = _repartidores[i];
                    final cierresRepartidor = _cierres.where((c) =>
                        c.repartidorNombre == r.nombre).toList();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _RepartidorDetallScreen(
                              repartidor: r,
                              cierres: cierresRepartidor,
                              onCierreActualizado: _cargar,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: r.cierresPendientes > 0
                                  ? Colors.orange.shade100
                                  : Colors.blue.shade100,
                              child: Text(r.nombre[0].toUpperCase(),
                                  style: TextStyle(
                                    color: r.cierresPendientes > 0
                                        ? Colors.orange.shade700
                                        : Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  )),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(r.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(r.email,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _Chip(
                                      label: fmt.format(r.totalVentas),
                                      icon: Icons.payments_outlined,
                                      color: Colors.green,
                                    ),
                                    _Chip(
                                      label: '${r.totalCierres} cierres',
                                      icon: Icons.assignment_turned_in_outlined,
                                      color: Colors.blue,
                                    ),
                                    if (r.cierresPendientes > 0)
                                      _Chip(
                                        label: '${r.cierresPendientes} pendiente(s)',
                                        icon: Icons.hourglass_top,
                                        color: Colors.orange,
                                      ),
                                  ],
                                ),
                              ]),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'eliminar') _eliminar(r);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'eliminar',
                                  child: Row(children: [
                                    Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    SizedBox(width: 8),
                                    Text('Eliminar', style: TextStyle(color: Colors.red)),
                                  ]),
                                ),
                              ],
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              );

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: _mostrarFormNuevo,
        child: const Icon(Icons.person_add_outlined),
      ),
    );
  }
}

// ── Pantalla de detalle: historial de cierres del repartidor ──────────────────

class _RepartidorDetallScreen extends StatefulWidget {
  final _RepartidorData repartidor;
  final List<CierreDia> cierres;
  final VoidCallback onCierreActualizado;

  const _RepartidorDetallScreen({
    required this.repartidor,
    required this.cierres,
    required this.onCierreActualizado,
  });

  @override
  State<_RepartidorDetallScreen> createState() => _RepartidorDetallScreenState();
}

class _RepartidorDetallScreenState extends State<_RepartidorDetallScreen> {
  late List<CierreDia> _cierres;

  @override
  void initState() {
    super.initState();
    _cierres = List.from(widget.cierres);
  }

  Future<void> _aprobar(CierreDia cierre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aprobar depósito'),
        content: Text('¿Confirmas que el depósito del ${cierre.fecha} es correcto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await ApiService.put('/cierres/${cierre.id}/aprobar', {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Depósito aprobado'), backgroundColor: Colors.green));
      widget.onCierreActualizado();
      Navigator.pop(context);
    }
  }

  Future<void> _rechazar(CierreDia cierre) async {
    final notaCtrl = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rechazar depósito'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Indica el motivo del rechazo:'),
          const SizedBox(height: 12),
          TextField(
            controller: notaCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Ej: El monto no coincide...'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirmar != true || notaCtrl.text.isEmpty) return;
    await ApiService.put('/cierres/${cierre.id}/rechazar', {'nota': notaCtrl.text});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Depósito rechazado'), backgroundColor: Colors.red));
      widget.onCierreActualizado();
      Navigator.pop(context);
    }
  }

  void _verComprobante(CierreDia cierre) {
    final bytes = base64Decode(cierre.comprobante.split(',').last);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Comprobante ${cierre.fecha}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es', symbol: 'Q');
    final pendientes = _cierres.where((c) => c.pendiente).toList();
    final resueltos = _cierres.where((c) => !c.pendiente).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.repartidor.nombre),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Información',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Historial de cierres'),
                content: const Text(
                  'Muestra todos los cierres del día enviados por este repartidor. Los pendientes aún no han sido aprobados o rechazados. Puedes ver el comprobante de cada cierre y tomar acción desde aquí.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _cierres.isEmpty
          ? Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('Sin cierres registrados', style: TextStyle(color: Colors.grey)),
              ]),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (pendientes.isNotEmpty) ...[
                  _Seccion(titulo: 'Pendientes de revisión', color: Colors.orange),
                  ...pendientes.map((c) => _TarjetaCierre(
                        cierre: c, fmt: fmt,
                        onAprobar: () => _aprobar(c),
                        onRechazar: () => _rechazar(c),
                        onVerComprobante: () => _verComprobante(c),
                      )),
                  const SizedBox(height: 8),
                ],
                if (resueltos.isNotEmpty) ...[
                  _Seccion(titulo: 'Historial', color: Colors.grey),
                  ...resueltos.map((c) => _TarjetaCierre(
                        cierre: c, fmt: fmt,
                        onVerComprobante: () => _verComprobante(c),
                      )),
                ],
              ],
            ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Chip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final Color color;
  const _Seccion({required this.titulo, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Row(children: [
          Container(width: 4, height: 18,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        ]),
      );
}

class _TarjetaCierre extends StatelessWidget {
  final CierreDia cierre;
  final NumberFormat fmt;
  final VoidCallback? onAprobar;
  final VoidCallback? onRechazar;
  final VoidCallback onVerComprobante;

  const _TarjetaCierre({
    required this.cierre,
    required this.fmt,
    required this.onVerComprobante,
    this.onAprobar,
    this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    final diferencia = cierre.montoDepositado - cierre.totalVentas;
    final coincide = diferencia.abs() < 0.01;

    Color estadoColor = cierre.aprobado ? Colors.green : cierre.rechazado ? Colors.red : Colors.orange;
    IconData estadoIcono = cierre.aprobado ? Icons.check_circle : cierre.rechazado ? Icons.cancel : Icons.hourglass_top;
    String estadoTexto = cierre.aprobado ? 'Aprobado' : cierre.rechazado ? 'Rechazado' : 'Pendiente';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: estadoColor.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(cierre.fecha,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Row(children: [
              Icon(estadoIcono, color: estadoColor, size: 16),
              const SizedBox(width: 4),
              Text(estadoTexto,
                  style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          ]),
          const Divider(height: 16),
          Row(children: [
            Expanded(child: _FilaMonto(label: 'Total ventas', valor: fmt.format(cierre.totalVentas))),
            Expanded(child: _FilaMonto(label: 'Depositado', valor: fmt.format(cierre.montoDepositado))),
            Expanded(child: _FilaMonto(
              label: 'Diferencia',
              valor: fmt.format(diferencia.abs()),
              color: coincide ? Colors.green : Colors.red,
            )),
          ]),
          if (cierre.rechazado && cierre.notaRechazo != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(cierre.notaRechazo!,
                    style: const TextStyle(color: Colors.red, fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
              onPressed: onVerComprobante,
              icon: const Icon(Icons.image_outlined, size: 16),
              label: const Text('Ver comprobante'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            ),
            if (cierre.pendiente) ...[
              const Spacer(),
              TextButton(
                onPressed: onRechazar,
                child: const Text('Rechazar', style: TextStyle(color: Colors.red)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onAprobar,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                child: const Text('Aprobar'),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _FilaMonto extends StatelessWidget {
  final String label;
  final String valor;
  final Color? color;
  const _FilaMonto({required this.label, required this.valor, this.color});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(valor,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color ?? Colors.black87)),
      ]);
}
