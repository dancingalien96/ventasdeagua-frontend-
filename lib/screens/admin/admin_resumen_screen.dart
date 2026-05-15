import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/cierre_dia.dart';
import '../../models/cliente.dart';
import '../../models/venta.dart';
import '../../services/api_service.dart';
import 'admin_historial_cierres_screen.dart';

class AdminResumenScreen extends StatefulWidget {
  const AdminResumenScreen({super.key});

  @override
  State<AdminResumenScreen> createState() => _AdminResumenScreenState();
}

class _AdminResumenScreenState extends State<AdminResumenScreen> {
  List<Venta> _ventas = [];
  List<CierreDia> _cierresHoy = [];
  List<Cliente> _clientesConDeuda = [];
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
      final ventasData = await ApiService.get('/ventas');
      final cierresData = await ApiService.get('/cierres');
      final clientesData = await ApiService.get('/clientes');
      if (!mounted) return;
      final hoy = DateTime.now().toIso8601String().split('T')[0];
      setState(() {
        _ventas = (ventasData as List).map((v) => Venta.fromJson(v)).toList();
        _cierresHoy = (cierresData as List)
            .map((c) => CierreDia.fromJson(c))
            .where((c) => c.fecha == hoy)
            .toList();
        _clientesConDeuda = (clientesData as List)
            .map((c) => Cliente.fromJson(c))
            .where((c) => c.tieneDeuda)
            .toList()
          ..sort((a, b) => b.deudaTotal.compareTo(a.deudaTotal));
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _aprobar(CierreDia cierre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aprobar depósito'),
        content: Text('¿Confirmas que el depósito de ${cierre.repartidorNombre} es correcto?'),
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
      _cargar();
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
      _cargar();
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
            child: Text('Comprobante de ${cierre.repartidorNombre}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es', symbol: 'Q');
    final hoy = DateTime.now();
    final ventasHoy = _ventas.where((v) =>
        v.fecha.day == hoy.day && v.fecha.month == hoy.month && v.fecha.year == hoy.year).toList();
    final totalHoy = ventasHoy.fold<double>(0, (s, v) => s + v.total);
    final totalGeneral = _ventas.fold<double>(0, (s, v) => s + v.total);
    final pendientes = _cierresHoy.where((c) => c.pendiente).length;
    final sinCierre = _cierresHoy.isEmpty && ventasHoy.isNotEmpty;
    final totalDeuda = _clientesConDeuda.fold<double>(0, (s, c) => s + c.deudaTotal);

    return RefreshIndicator(
      onRefresh: _cargar,
      child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Hoy, ${DateFormat('dd MMMM yyyy', 'es').format(hoy)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _TarjetaStat(
                    titulo: 'Ventas hoy',
                    valor: fmt.format(totalHoy),
                    icono: Icons.today,
                    color: Colors.blue,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _TarjetaStat(
                    titulo: 'Total acumulado',
                    valor: fmt.format(totalGeneral),
                    icono: Icons.account_balance_wallet_outlined,
                    color: Colors.green,
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _TarjetaStat(
                    titulo: 'Cierres hoy',
                    valor: '${_cierresHoy.length}',
                    icono: Icons.assignment_turned_in_outlined,
                    color: _cierresHoy.isEmpty ? Colors.grey : Colors.blue,
                    subtitulo: 'enviados',
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _TarjetaStat(
                    titulo: 'Deudas clientes',
                    valor: fmt.format(totalDeuda),
                    icono: Icons.pending_actions_outlined,
                    color: totalDeuda > 0 ? Colors.red : Colors.grey,
                    subtitulo: '${_clientesConDeuda.length} cliente${_clientesConDeuda.length != 1 ? 's' : ''} con deuda',
                  )),
                ]),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cierres del día',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminHistorialCierresScreen()),
                      ),
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Ver historial'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_cierresHoy.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        Icon(
                          sinCierre ? Icons.pending_outlined : Icons.inbox_outlined,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sinCierre
                              ? 'Hay ventas registradas pero ningún repartidor ha cerrado el día'
                              : 'Sin cierres registrados hoy',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ]),
                    ),
                  )
                else
                  ..._cierresHoy.map((cierre) => _TarjetaCierreHoy(
                        cierre: cierre,
                        fmt: fmt,
                        onVerComprobante: () => _verComprobante(cierre),
                        onAprobar: cierre.pendiente ? () => _aprobar(cierre) : null,
                        onRechazar: cierre.pendiente ? () => _rechazar(cierre) : null,
                      )),
              ],
            ),
    );
  }
}

class _TarjetaCierreHoy extends StatelessWidget {
  final CierreDia cierre;
  final NumberFormat fmt;
  final VoidCallback onVerComprobante;
  final VoidCallback? onAprobar;
  final VoidCallback? onRechazar;

  const _TarjetaCierreHoy({
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

    final estadoColor = cierre.aprobado
        ? Colors.green
        : cierre.rechazado
            ? Colors.red
            : Colors.orange;
    final estadoTexto = cierre.aprobado
        ? 'Aprobado'
        : cierre.rechazado
            ? 'Rechazado'
            : 'Pendiente';
    final estadoIcono = cierre.aprobado
        ? Icons.check_circle
        : cierre.rechazado
            ? Icons.cancel
            : Icons.hourglass_top;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: estadoColor.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                (cierre.repartidorNombre ?? '?')[0].toUpperCase(),
                style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(cierre.repartidorNombre ?? 'Repartidor',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            Row(children: [
              Icon(estadoIcono, color: estadoColor, size: 16),
              const SizedBox(width: 4),
              Text(estadoTexto,
                  style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          ]),
          const SizedBox(height: 12),
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
        Text(valor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color ?? Colors.black87)),
      ]);
}

class _TarjetaStat extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;
  final String? subtitulo;

  const _TarjetaStat({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icono, color: color, size: 22),
        const SizedBox(height: 8),
        Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(subtitulo ?? titulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ]),
    );
  }
}
