import 'package:flutter/material.dart';

import '../widgets/bottom_nav.dart';
import 'dashboard_screen.dart';
import 'formulario_screen.dart';
import 'historial_screen.dart';
import 'reportes_screen.dart';

/// Contenedor con la barra inferior. La pestaña "Evaluar" tiene su propio
/// Navigator para que Formulario -> Resultado mantenga visible la barra.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;
  final _navEvaluar = GlobalKey<NavigatorState>();

  void _ir(int i) {
    if (i == _indice && i == 1) {
      _navEvaluar.currentState?.popUntil((r) => r.isFirst);
    }
    setState(() => _indice = i);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _indice == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navEvaluar.currentState;
        if (_indice == 1 && nav != null && nav.canPop()) {
          nav.pop();
        } else {
          setState(() => _indice = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _indice,
          children: [
            DashboardScreen(onNuevaValoracion: () => _ir(1), onVerHistorial: () => _ir(2)),
            Navigator(
              key: _navEvaluar,
              onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => const Scaffold(body: FormularioScreen())),
            ),
            const HistorialScreen(),
            const ReportesScreen(),
          ],
        ),
        bottomNavigationBar: BarraNavegacion(indice: _indice, onTap: _ir),
      ),
    );
  }
}
