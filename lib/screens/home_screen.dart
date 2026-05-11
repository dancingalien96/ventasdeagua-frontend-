import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'admin/admin_resumen_screen.dart';
import 'admin/admin_repartidores_screen.dart';
import 'admin/admin_clientes_screen.dart';
import 'admin/admin_productos_screen.dart';
import 'ventas/mis_ventas_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final usuario = auth.usuario!;

    if (!usuario.esAdmin) return const _RepartidorHome();

    final tabs = [
      const AdminResumenScreen(),
      const AdminRepartidoresScreen(),
      const AdminClientesScreen(),
      const AdminProductosScreen(),
    ];

    final titles = ['Resumen', 'Repartidores', 'Clientes', 'Productos'];

    const infoTextos = [
      'Muestra las estadísticas del día: ventas totales, montos acumulados y los cierres enviados por los repartidores. Puedes aprobar o rechazar depósitos directamente desde aquí.',
      'Gestiona las cuentas de tus repartidores. Crea nuevos usuarios, consulta sus ventas acumuladas y revisa el historial completo de sus cierres del día.',
      'Administra tu lista de clientes. Agrega clientes nuevos, establece precios especiales por producto y registra cobros de deudas pendientes.',
      'Administra los productos que ofreces. Crea nuevos productos y edita su precio base.',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tabIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Información',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(titles[_tabIndex]),
                content: Text(infoTextos[_tabIndex]),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white),
            ),
            itemBuilder: (_) => <PopupMenuEntry>[
              PopupMenuItem(
                enabled: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(usuario.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text('Administrador',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                onTap: () => auth.logout(),
                child: const Row(children: [
                  Icon(Icons.logout, color: Colors.red, size: 20),
                  SizedBox(width: 10),
                  Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _tabIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Resumen'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Repartidores'),
          NavigationDestination(
              icon: Icon(Icons.store_outlined),
              selectedIcon: Icon(Icons.store),
              label: 'Clientes'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Productos'),
        ],
      ),
    );
  }
}

class _RepartidorHome extends StatelessWidget {
  const _RepartidorHome();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final usuario = auth.usuario!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Ventas'),
        actions: [
          PopupMenuButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white),
            ),
            itemBuilder: (_) => <PopupMenuEntry>[
              PopupMenuItem(
                enabled: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(usuario.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text('Repartidor',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                onTap: () => auth.logout(),
                child: const Row(children: [
                  Icon(Icons.logout, color: Colors.red, size: 20),
                  SizedBox(width: 10),
                  Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const MisVentasScreen(sinAppBar: true),
    );
  }
}
