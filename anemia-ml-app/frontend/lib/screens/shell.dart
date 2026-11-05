// Contenedor con la barra de navegación inferior (Inicio, Nueva, Historial, Reportes).
import 'package:flutter/material.dart';
import '../widgets/comunes.dart';
import 'dashboard_screen.dart';
import 'formulario_screen.dart';
import 'historial_screen.dart';
import 'reportes_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;

  void irA(int i) => setState(() => _tab = i);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Al volver a la app se reintenta enviar lo que quedó pendiente.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) AppScope.of(context).sincronizar();
  }

  @override
  Widget build(BuildContext context) {
    final estado = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          if (estado.pendientes.isNotEmpty)
            Material(
              color: const Color(0xFFFFF4D6),
              child: InkWell(
                onTap: estado.sincronizar,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.sync, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            '${estado.pendientes.length} valoración(es) pendiente(s) de envío. Toca para reintentar.',
                            style: const TextStyle(fontSize: 13))),
                  ]),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(index: _tab, children: const [
              DashboardScreen(),
              FormularioScreen(),
              HistorialScreen(),
              ReportesScreen(),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: irA,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Valorar'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reportes'),
        ],
      ),
    );
  }
}
