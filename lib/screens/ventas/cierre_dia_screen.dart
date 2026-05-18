import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/venta.dart';
import '../../services/api_service.dart';

class CierreDiaScreen extends StatefulWidget {
  final String? fecha; // null = hoy, 'YYYY-MM-DD' = día atrasado
  const CierreDiaScreen({super.key, this.fecha});

  @override
  State<CierreDiaScreen> createState() => _CierreDiaScreenState();
}

class _CierreDiaScreenState extends State<CierreDiaScreen> {
  List<Venta> _ventas = [];
  double _totalVentas = 0;
  bool _cargando = true;
  bool _yaExisteCierre = false;
  bool _guardando = false;
  File? _imagenComprobante;

  String get _fecha => widget.fecha ?? DateTime.now().toIso8601String().split('T')[0];
  bool get _esAtrasado => widget.fecha != null && widget.fecha != DateTime.now().toIso8601String().split('T')[0];

  double get _totalDeuda => _ventas.fold(0, (s, v) => s + v.deuda);
  double get _totalDepositar => _ventas.fold(0, (s, v) => s + v.montoPagado);

  @override
  void initState() {
    super.initState();
    _cargarVentasDelDia();
  }

  Future<void> _cargarVentasDelDia() async {
    setState(() => _cargando = true);
    try {
      final path = _esAtrasado ? '/cierres/ventas-del-dia?fecha=$_fecha' : '/cierres/ventas-del-dia';
      final data = await ApiService.get(path);
      if (data['cierreExistente'] == true) {
        setState(() { _yaExisteCierre = true; _cargando = false; });
        return;
      }
      final ventas = (data['ventas'] as List).map((v) => Venta.fromJson(v)).toList();
      setState(() {
        _ventas = ventas;
        _totalVentas = (data['total'] as num).toDouble();
        _cargando = false;
      });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _seleccionarFoto() async {
    final picker = ImagePicker();
    final imagen = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (imagen != null) setState(() => _imagenComprobante = File(imagen.path));
  }

  Future<void> _seleccionarDeGaleria() async {
    final picker = ImagePicker();
    final imagen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (imagen != null) setState(() => _imagenComprobante = File(imagen.path));
  }

  Future<void> _enviarCierre() async {
    if (_imagenComprobante == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el comprobante de depósito'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _guardando = true);
    try {
      final bytes = await _imagenComprobante!.readAsBytes();
      final base64Img = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await ApiService.post('/cierres', {
        'ventas_ids': _ventas.map((v) => v.id).toList(),
        'total_ventas': _totalVentas,
        'monto_depositado': _totalDepositar,
        'comprobante': base64Img,
        if (_esAtrasado) 'fecha': _fecha,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cierre enviado al administrador'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar cierre'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es', symbol: 'Q');
    final fechaFmt = DateFormat('dd/MM/yyyy').format(DateTime.parse(_fecha));

    return Scaffold(
      appBar: AppBar(
        title: Text(_esAtrasado ? 'Cerrar día — $fechaFmt' : 'Cerrar Día'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Información',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Cerrar Día'),
                content: const Text(
                  'El monto a depositar se calcula automáticamente: total vendido menos lo que quedaron debiendo los clientes. Solo toma foto del comprobante y envíalo.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _yaExisteCierre
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.check_circle, size: 72, color: Colors.green),
                    const SizedBox(height: 16),
                    Text(
                      _esAtrasado ? 'Cierre de $fechaFmt ya enviado' : 'Ya enviaste tu cierre de hoy',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('El administrador está revisando tu comprobante.',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ]),
                )
              : _ventas.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.inbox_outlined, size: 72, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _esAtrasado ? 'Sin ventas para ese día' : 'No tienes ventas registradas hoy',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          _esAtrasado
                              ? 'No hay ventas registradas para el $fechaFmt.'
                              : 'Registra tus ventas antes de cerrar el día.',
                          style: TextStyle(color: Colors.grey.shade600)),
                      ]),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        // Tarjeta resumen con desglose
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade800, Colors.blue.shade600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              _esAtrasado ? 'Resumen del $fechaFmt' : 'Resumen del día',
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(child: _FilaResumen(
                                label: 'Total vendido',
                                valor: fmt.format(_totalVentas),
                                color: Colors.white,
                              )),
                              if (_totalDeuda > 0)
                                Expanded(child: _FilaResumen(
                                  label: 'Deudas clientes',
                                  valor: '- ${fmt.format(_totalDeuda)}',
                                  color: Colors.red.shade200,
                                )),
                            ]),
                            if (_totalDeuda > 0) ...[
                              const SizedBox(height: 12),
                              const Divider(color: Colors.white24),
                              const SizedBox(height: 12),
                            ] else
                              const SizedBox(height: 12),
                            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('A depositar', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(fmt.format(_totalDepositar),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis),
                                ]),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('${_ventas.length} venta(s)',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ),
                            ]),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // Lista de ventas
                        Text(
                          _esAtrasado ? 'Ventas del día' : 'Ventas de hoy',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ..._ventas.map((v) {
                          final tieneDeuda = v.deuda > 0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: tieneDeuda ? BorderSide(color: Colors.red.shade200) : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(
                                    v.clienteNombre ?? 'Venta casual',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text(
                                    v.items.map((i) => '${i.productoNombre} x${i.cantidad}').join(', '),
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (tieneDeuda)
                                    Text(
                                      'Debe: ${fmt.format(v.deuda)}',
                                      style: TextStyle(fontSize: 12, color: Colors.red.shade600, fontWeight: FontWeight.w500)),
                                ])),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(fmt.format(v.total),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: tieneDeuda ? Colors.grey.shade500 : Colors.black87,
                                          decoration: tieneDeuda ? TextDecoration.lineThrough : null)),
                                  if (tieneDeuda)
                                    Text(fmt.format(v.montoPagado),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                                ]),
                              ]),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),

                        // Comprobante
                        const Text('Comprobante de depósito',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        if (_imagenComprobante != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_imagenComprobante!, height: 220, width: double.infinity, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _seleccionarFoto,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Cambiar foto'),
                          ),
                        ] else ...[
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _seleccionarFoto,
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Cámara'),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _seleccionarDeGaleria,
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Galería'),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                              ),
                            ),
                          ]),
                        ],
                        const SizedBox(height: 32),

                        // Botón enviar
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _guardando ? null : _enviarCierre,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _guardando
                                ? const SizedBox(height: 20, width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(
                                    'Depositar ${fmt.format(_totalDepositar)} y cerrar día',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ]),
                    ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;
  const _FilaResumen({required this.label, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 2),
        Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ]);
}
