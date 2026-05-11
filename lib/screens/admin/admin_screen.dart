import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/venta.dart';
import '../../services/api_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Venta> _ventas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarVentas();
  }

  Future<void> _cargarVentas() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final data = await ApiService.get('/ventas');
      if (!mounted) return;
      setState(() => _ventas = (data as List).map((v) => Venta.fromJson(v)).toList());
    } catch (_) {} finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _verificar(Venta venta) async {
    await ApiService.put('/ventas/${venta.id}/verificar', {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venta verificada'), backgroundColor: Colors.green));
      _cargarVentas();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es', symbol: 'Q');
    final dateFmt = DateFormat('dd/MM/yyyy');
    final totalGeneral = _ventas.fold<double>(0, (s, v) => s + v.total);
    final pendientes = _ventas.where((v) => v.estado == 'pendiente' && v.comprobante != null).length;
    final deudaTotal = _ventas.fold<double>(0, (s, v) => s + v.deuda);
    final ventasConDeuda = _ventas.where((v) => v.deuda > 0).length;

    return Scaffold(
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Stat(label: 'Total ventas', valor: fmt.format(totalGeneral)),
                          _Stat(label: 'Pendientes', valor: '$pendientes', color: pendientes > 0 ? Colors.orange : Colors.green),
                          _Stat(label: 'Registros', valor: '${_ventas.length}'),
                        ],
                      ),
                      if (deudaTotal > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.red.shade700, size: 18),
                                const SizedBox(width: 8),
                                Text('Deuda pendiente ($ventasConDeuda venta${ventasConDeuda != 1 ? 's' : ''})',
                                    style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w500)),
                              ]),
                              Text(fmt.format(deudaTotal),
                                  style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargarVentas,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _ventas.length,
                      itemBuilder: (_, i) {
                        final venta = _ventas[i];
                        final verificado = venta.estado == 'verificado';
                        final tieneComprobante = venta.comprobante != null;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ExpansionTile(
                            leading: Icon(
                              verificado ? Icons.check_circle : tieneComprobante ? Icons.hourglass_top : Icons.pending,
                              color: verificado ? Colors.green : tieneComprobante ? Colors.orange : Colors.grey,
                            ),
                            title: Row(children: [
                              Expanded(
                                child: Text('${venta.repartidorNombre ?? 'Repartidor'} · ${dateFmt.format(venta.fecha)}',
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (venta.deuda > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(fmt.format(venta.deuda),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red.shade800,
                                          fontWeight: FontWeight.bold)),
                                ),
                            ]),
                            subtitle: Text(
                              venta.clienteNombre != null
                                  ? '${venta.clienteNombre} · ${fmt.format(venta.total)}'
                                  : 'Total: ${fmt.format(venta.total)} · ${venta.estado}',
                            ),
                            children: [
                              ...venta.items.map((item) => ListTile(
                                    dense: true,
                                    title: Text(item.productoNombre),
                                    subtitle: Text(item.clienteNombre != null ? 'Cliente: ${item.clienteNombre}' : 'Casual'),
                                    trailing: Text('x${item.cantidad} · ${fmt.format(item.subtotal)}'),
                                  )),
                              if (venta.itemsDeuda.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          size: 15, color: Colors.red.shade700),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Debe: ${venta.itemsDeuda.map((i) => '${i.cantidad}x ${i.productoNombre}').join(', ')}',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (venta.nota != null && venta.nota!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.notes_outlined, size: 15, color: Colors.orange.shade700),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(venta.nota!,
                                            style: TextStyle(fontSize: 13, color: Colors.orange.shade800)),
                                      ),
                                    ],
                                  ),
                                ),
                              if (venta.montoDepositado != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Text('Depositado: ${fmt.format(venta.montoDepositado!)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              if (!verificado && tieneComprobante)
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _verificar(venta),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Verificar depósito'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String valor;
  final Color? color;

  const _Stat({required this.label, required this.valor, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color ?? Colors.blue.shade800)),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ]);
  }
}
