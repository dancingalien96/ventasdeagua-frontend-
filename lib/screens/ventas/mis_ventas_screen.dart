import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/venta.dart';
import '../../models/cierre_dia.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import 'nueva_venta_screen.dart';
import 'cierre_dia_screen.dart';

class MisVentasScreen extends StatefulWidget {
  final bool sinAppBar;
  const MisVentasScreen({super.key, this.sinAppBar = false});

  @override
  State<MisVentasScreen> createState() => _MisVentasScreenState();
}

class _MisVentasScreenState extends State<MisVentasScreen> {
  List<Venta> _ventas = [];
  List<CierreDia> _cierres = [];
  bool _cargando = true;
  late final StreamSubscription<String> _socketSub;

  @override
  void initState() {
    super.initState();
    _cargar();
    _socketSub = SocketService.eventos.listen((tipo) {
      if ((tipo == 'ventas' || tipo == 'cierres') && mounted) {
        _cargar();
      }
    });
  }

  @override
  void dispose() {
    _socketSub.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final results = await Future.wait([
        ApiService.get('/ventas/mis-ventas'),
        ApiService.get('/cierres/mis-cierres'),
      ]);
      setState(() {
        _ventas = (results[0] as List).map((v) => Venta.fromJson(v)).toList();
        _cierres = (results[1] as List).map((c) => CierreDia.fromJson(c)).toList();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── Computed ────────────────────────────────────────────────────────────────

  String get _hoy => DateTime.now().toIso8601String().split('T')[0];

  List<Venta> get _ventasHoy {
    final h = DateTime.now();
    return _ventas
        .where((v) => v.fecha.year == h.year && v.fecha.month == h.month && v.fecha.day == h.day)
        .toList();
  }

  CierreDia? get _cierreHoy {
    try { return _cierres.firstWhere((c) => c.fecha == _hoy); } catch (_) { return null; }
  }

  double get _totalHoy => _ventasHoy.fold(0, (s, v) => s + v.total);
  double get _deudaHoy => _ventasHoy.fold(0, (s, v) => s + v.deuda);
  double get _depositarHoy => _ventasHoy.fold(0, (s, v) => s + v.montoPagado);

  List<String> get _diasSinCerrar {
    final cerradas = _cierres.map((c) => c.fecha).toSet();
    return _ventas
        .map((v) => v.fecha.toIso8601String().split('T')[0])
        .where((f) => f.compareTo(_hoy) < 0)
        .toSet()
        .difference(cerradas)
        .toList()
      ..sort();
  }

  Map<String, List<Venta>> get _historial {
    final mapa = <String, List<Venta>>{};
    for (final v in _ventas) {
      final f = v.fecha.toIso8601String().split('T')[0];
      if (f != _hoy) mapa.putIfAbsent(f, () => []).add(v);
    }
    return mapa;
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _agregarVenta() async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => NuevaVentaScreen(ventasHoy: _ventasHoy)));
    if (ok == true) _cargar();
  }

  Future<void> _editarVenta(Venta v) async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => NuevaVentaScreen(ventaEditar: v)));
    if (ok == true) _cargar();
  }

  Future<void> _eliminarVenta(Venta venta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar venta'),
        content: const Text('¿Seguro que quieres eliminar esta venta?'),
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
    if (ok != true) return;
    await ApiService.delete('/ventas/${venta.id}');
    if (mounted) _cargar();
  }

  Future<void> _cerrarDia() async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const CierreDiaScreen()));
    if (ok == true) _cargar();
  }

  Future<void> _cerrarDiaAtrasado(String fecha) async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => CierreDiaScreen(fecha: fecha)));
    if (ok == true) _cargar();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es', symbol: 'Q');

    return Scaffold(
      appBar: widget.sinAppBar
          ? null
          : AppBar(title: const Text('Mi Jornada')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Alertas días sin cerrar ──────────────────────────────
                  ..._diasSinCerrar.map((fecha) => _BannerSinCerrar(
                        fecha: fecha,
                        onCerrar: () => _cerrarDiaAtrasado(fecha),
                      )),

                  // ── Tarjeta jornada de hoy ───────────────────────────────
                  _TarjetaJornada(
                    ventasHoy: _ventasHoy,
                    cierreHoy: _cierreHoy,
                    totalHoy: _totalHoy,
                    deudaHoy: _deudaHoy,
                    depositarHoy: _depositarHoy,
                    fmt: fmt,
                    onAgregar: _agregarVenta,
                    onCerrarDia: _cerrarDia,
                    onEditar: _editarVenta,
                    onEliminar: _eliminarVenta,
                  ),

                  // ── Historial días anteriores ────────────────────────────
                  if (_historial.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SeccionHistorial(
                      historial: _historial,
                      cierres: _cierres,
                      fmt: fmt,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Banner día sin cerrar ────────────────────────────────────────────────────

class _BannerSinCerrar extends StatelessWidget {
  final String fecha;
  final VoidCallback onCerrar;
  const _BannerSinCerrar({required this.fecha, required this.onCerrar});

  @override
  Widget build(BuildContext context) {
    final fechaFmt = DateFormat('dd/MM/yyyy').format(DateTime.parse(fecha));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text('No cerraste el $fechaFmt',
              style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        TextButton(
          onPressed: onCerrar,
          style: TextButton.styleFrom(
              foregroundColor: Colors.orange.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 10)),
          child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

// ── Tarjeta principal de jornada ─────────────────────────────────────────────

class _TarjetaJornada extends StatelessWidget {
  final List<Venta> ventasHoy;
  final CierreDia? cierreHoy;
  final double totalHoy;
  final double deudaHoy;
  final double depositarHoy;
  final NumberFormat fmt;
  final VoidCallback onAgregar;
  final VoidCallback onCerrarDia;
  final Future<void> Function(Venta) onEditar;
  final Future<void> Function(Venta) onEliminar;

  const _TarjetaJornada({
    required this.ventasHoy,
    required this.cierreHoy,
    required this.totalHoy,
    required this.deudaHoy,
    required this.depositarHoy,
    required this.fmt,
    required this.onAgregar,
    required this.onCerrarDia,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final fechaStr = DateFormat("EEEE dd 'de' MMMM", 'es').format(hoy);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── Header con totales ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fechaStr.substring(0, 1).toUpperCase() + fechaStr.substring(1),
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            if (ventasHoy.isEmpty)
              const Text('Sin ventas aún',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))
            else ...[
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total vendido', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  Text(fmt.format(totalHoy),
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ])),
                if (deudaHoy > 0)
                  Flexible(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Deudas: -${fmt.format(deudaHoy)}',
                          style: TextStyle(color: Colors.red.shade200, fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end),
                      const SizedBox(height: 2),
                      Text('A depositar: ${fmt.format(depositarHoy)}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end),
                    ]),
                  ),
              ]),
              const SizedBox(height: 4),
              Text('${ventasHoy.length} venta(s) registrada(s)',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ]),
        ),

        // ── Cuerpo: ventas + acciones ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Lista de ventas de hoy
            if (ventasHoy.isNotEmpty) ...[
              ...ventasHoy.map((v) => _ItemVenta(
                    venta: v,
                    fmt: fmt,
                    diaCerrado: cierreHoy?.aprobado == true,
                    onEditar: () => onEditar(v),
                    onEliminar: () => onEliminar(v),
                  )),
              const SizedBox(height: 4),
            ] else ...[
              const SizedBox(height: 16),
              Center(
                child: Column(children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('Registra tus ventas del día',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // Botón agregar venta — solo si el cierre no fue aprobado
            if (cierreHoy?.aprobado != true)
              OutlinedButton.icon(
                onPressed: onAgregar,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar venta'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

            // Estado del cierre / botón cerrar
            if (cierreHoy != null) ...[
              const SizedBox(height: 10),
              _EstadoCierre(cierre: cierreHoy!),
            ] else if (ventasHoy.isNotEmpty) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: onCerrarDia,
                icon: const Icon(Icons.lock_clock, size: 18),
                label: Text(
                  'Cerrar día — depositar ${fmt.format(depositarHoy)}',
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Item venta dentro de la tarjeta ─────────────────────────────────────────

class _ItemVenta extends StatefulWidget {
  final Venta venta;
  final NumberFormat fmt;
  final bool diaCerrado;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _ItemVenta({
    required this.venta,
    required this.fmt,
    required this.diaCerrado,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  State<_ItemVenta> createState() => _ItemVentaState();
}

class _ItemVentaState extends State<_ItemVenta> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.venta;
    final fmt = widget.fmt;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Fila principal (siempre visible)
        InkWell(
          onTap: () => setState(() => _expandido = !_expandido),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: v.deuda > 0 ? Colors.red.shade100 : Colors.blue.shade100,
                child: Text(
                  (v.clienteNombre ?? 'C')[0].toUpperCase(),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: v.deuda > 0 ? Colors.red.shade700 : Colors.blue.shade700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.clienteNombre ?? 'Venta casual',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  v.items.map((i) => '${i.cantidad}x ${i.productoNombre}').join(', '),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                if (v.deuda > 0)
                  Text('Debe: ${fmt.format(v.deuda)}',
                      style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.w500)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmt.format(v.total),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: v.deuda > 0 ? Colors.grey.shade500 : Colors.black87,
                        decoration: v.deuda > 0 ? TextDecoration.lineThrough : null)),
                if (v.deuda > 0)
                  Text(fmt.format(v.montoPagado),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
              ]),
              const SizedBox(width: 4),
              Icon(_expandido ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey, size: 18),
            ]),
          ),
        ),

        // Detalle expandible
        if (_expandido) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...v.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(children: [
                      Text('${item.cantidad}x ${item.productoNombre}',
                          style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      Text(fmt.format(item.subtotal),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ]),
                  )),
              if (v.itemsDeuda.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...v.itemsDeuda.map((d) => Row(children: [
                      Icon(Icons.warning_amber_rounded, size: 13, color: Colors.red.shade600),
                      const SizedBox(width: 4),
                      Text('${d.cantidad}x ${d.productoNombre} (deuda)',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade600)),
                    ])),
              ],
              if (v.nota != null && v.nota!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Nota: ${v.nota}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.orange.shade700, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 8),
              if (!widget.diaCerrado)
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton.icon(
                    onPressed: widget.onEditar,
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Editar', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                  TextButton.icon(
                    onPressed: widget.onEliminar,
                    icon: const Icon(Icons.delete_outline, size: 14),
                    label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ]),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── Estado del cierre dentro de la tarjeta ───────────────────────────────────

class _EstadoCierre extends StatelessWidget {
  final CierreDia cierre;
  const _EstadoCierre({required this.cierre});

  @override
  Widget build(BuildContext context) {
    final color = cierre.aprobado ? Colors.green : cierre.rechazado ? Colors.red : Colors.orange;
    final icono = cierre.aprobado ? Icons.check_circle : cierre.rechazado ? Icons.cancel : Icons.hourglass_top;
    final texto = cierre.aprobado ? 'Día cerrado y aprobado' : cierre.rechazado ? 'Cierre rechazado' : 'Cierre enviado — pendiente de revisión';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(texto,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))),
        ]),
        if (cierre.rechazado && cierre.notaRechazo != null) ...[
          const SizedBox(height: 6),
          Text(cierre.notaRechazo!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
        ],
      ]),
    );
  }
}

// ── Sección historial días anteriores ────────────────────────────────────────

class _SeccionHistorial extends StatefulWidget {
  final Map<String, List<Venta>> historial;
  final List<CierreDia> cierres;
  final NumberFormat fmt;

  const _SeccionHistorial({
    required this.historial,
    required this.cierres,
    required this.fmt,
  });

  @override
  State<_SeccionHistorial> createState() => _SeccionHistorialState();
}

class _SeccionHistorialState extends State<_SeccionHistorial> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final fechas = widget.historial.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: () => setState(() => _expandido = !_expandido),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(children: [
            Icon(_expandido ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 6),
            Text('Días anteriores (${fechas.length})',
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ]),
        ),
      ),
      if (_expandido)
        ...fechas.map((fecha) {
          final ventas = widget.historial[fecha]!;
          final cierre = widget.cierres.where((c) => c.fecha == fecha).firstOrNull;
          final dt = DateTime.parse(fecha);
          final fechaFmt = DateFormat("dd 'de' MMMM", 'es').format(dt);
          final total = ventas.fold<double>(0, (s, v) => s + v.total);

          return Card(
            margin: const EdgeInsets.only(top: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(fechaFmt,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('${ventas.length} venta(s) · ${widget.fmt.format(total)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              trailing: cierre != null
                  ? Icon(
                      cierre.aprobado ? Icons.check_circle : cierre.rechazado ? Icons.cancel : Icons.hourglass_top,
                      color: cierre.aprobado ? Colors.green : cierre.rechazado ? Colors.red : Colors.orange,
                      size: 20)
                  : Icon(Icons.warning_amber_rounded, color: Colors.orange.shade400, size: 20),
              children: ventas
                  .map((v) => ListTile(
                        dense: true,
                        title: Text(v.clienteNombre ?? 'Venta casual',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          v.items.map((i) => '${i.cantidad}x ${i.productoNombre}').join(', '),
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(widget.fmt.format(v.total),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ))
                  .toList(),
            ),
          );
        }),
    ]);
  }
}
