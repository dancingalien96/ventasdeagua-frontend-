import 'package:flutter/material.dart';
import '../../models/producto.dart';
import '../../services/api_service.dart';

class AdminProductosScreen extends StatefulWidget {
  const AdminProductosScreen({super.key});

  @override
  State<AdminProductosScreen> createState() => _AdminProductosScreenState();
}

class _AdminProductosScreenState extends State<AdminProductosScreen> {
  List<Producto> _productos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    setState(() => _cargando = true);
    try {
      final data = await ApiService.get('/productos');
      setState(() => _productos = (data as List).map((p) => Producto.fromJson(p)).toList());
    } catch (_) {} finally {
      setState(() => _cargando = false);
    }
  }

  void _mostrarFormProducto({Producto? producto}) {
    final nombreCtrl = TextEditingController(text: producto?.nombre ?? '');
    final precioCtrl = TextEditingController(text: producto?.precioBase.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(producto == null ? 'Nuevo producto' : 'Editar producto',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
          const SizedBox(height: 10),
          TextField(
            controller: precioCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Precio base', prefixText: 'Q '),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final body = {
                  'nombre': nombreCtrl.text,
                  'precio_base': double.parse(precioCtrl.text),
                };
                if (producto == null) {
                  await ApiService.post('/productos', body);
                } else {
                  await ApiService.put('/productos/${producto.id}', body);
                }
                if (mounted) Navigator.pop(context);
                _cargarProductos();
              },
              child: const Text('Guardar'),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  IconData _iconoProducto(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('garrafa') || n.contains('garrafon')) return Icons.water;
    if (n.contains('bolsa')) return Icons.shopping_bag_outlined;
    if (n.contains('hielo')) return Icons.ac_unit;
    if (n.contains('botella') || n.contains('botellita')) return Icons.liquor;
    return Icons.inventory_2_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _productos.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('Sin productos registrados', style: TextStyle(color: Colors.grey)),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _cargarProductos,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _productos.length,
                    itemBuilder: (_, i) {
                      final p = _productos[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade50,
                            child: Icon(_iconoProducto(p.nombre), color: Colors.blue.shade700),
                          ),
                          title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Precio base: Q${p.precioBase.toStringAsFixed(2)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _mostrarFormProducto(producto: p),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormProducto(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
