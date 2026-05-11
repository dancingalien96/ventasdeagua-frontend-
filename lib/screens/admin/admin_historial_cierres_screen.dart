import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/cierre_dia.dart';
import '../../services/api_service.dart';

class AdminHistorialCierresScreen extends StatefulWidget {
  const AdminHistorialCierresScreen({super.key});

  @override
  State<AdminHistorialCierresScreen> createState() => _AdminHistorialCierresScreenState();
}

class _AdminHistorialCierresScreenState extends State<AdminHistorialCierresScreen> {
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
      final data = await ApiService.get('/cierres');
      if (!mounted) return;
      setState(() {
        _cierres = (data as List).map((c) => CierreDia.fromJson(c)).toList();
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

  Map<String, List<CierreDia>> _agruparPorFecha() {
    final Map<String, List<CierreDia>> grupos = {};
    for (final c in _cierres) {
      grupos.putIfAbsent(c.fecha, () => []).add(c);
    }
    return grupos;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es', symbol: 'Q');
    final grupos = _agruparPorFecha();
    final fechas = grupos.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de cierres')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _cierres.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('Sin cierres registrados', style: TextStyle(color: Colors.grey)),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: fechas.length,
                    itemBuilder: (_, i) {
                      final fecha = fechas[i];
                      final cierresDia = grupos[fecha]!;
                      final dt = DateTime.parse(fecha);
                      final esHoy = fecha == DateTime.now().toIso8601String().split('T')[0];
                      final pendientesDia = cierresDia.where((c) => c.pendiente).length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: 10, top: i == 0 ? 0 : 8),
                            child: Row(children: [
                              Container(
                                width: 4, height: 18,
                                decoration: BoxDecoration(
                                  color: esHoy ? Colors.blue : Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                esHoy
                                    ? 'Hoy — ${DateFormat('dd/MM/yyyy').format(dt)}'
                                    : DateFormat("EEEE dd 'de' MMMM yyyy", 'es').format(dt),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: esHoy ? Colors.blue.shade700 : Colors.grey.shade700,
                                ),
                              ),
                              if (pendientesDia > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$pendientesDia pendiente${pendientesDia > 1 ? 's' : ''}',
                                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ]),
                          ),
                          ...cierresDia.map((cierre) => _TarjetaCierre(
                                cierre: cierre,
                                fmt: fmt,
                                onVerComprobante: () => _verComprobante(cierre),
                                onAprobar: cierre.pendiente ? () => _aprobar(cierre) : null,
                                onRechazar: cierre.pendiente ? () => _rechazar(cierre) : null,
                              )),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}

class _TarjetaCierre extends StatelessWidget {
  final CierreDia cierre;
  final NumberFormat fmt;
  final VoidCallback onVerComprobante;
  final VoidCallback? onAprobar;
  final VoidCallback? onRechazar;

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
    final estadoColor = cierre.aprobado ? Colors.green : cierre.rechazado ? Colors.red : Colors.orange;
    final estadoTexto = cierre.aprobado ? 'Aprobado' : cierre.rechazado ? 'Rechazado' : 'Pendiente';
    final estadoIcono = cierre.aprobado ? Icons.check_circle : cierre.rechazado ? Icons.cancel : Icons.hourglass_top;

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
