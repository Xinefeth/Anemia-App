// Pantalla 2: Dashboard (RF22).
import 'package:flutter/material.dart';
import '../models/modelos.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'detalle_screen.dart';
import 'ninos_screen.dart';
import 'usuarios_screen.dart';
import 'shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Dashboard? _d;
  Object? _error;
  bool _desdeCache = false;
  int _version = -1;

  Future<void> _cargar() async {
    final app = AppScope.of(context);
    try {
      final d = await app.api.dashboard();
      await app.cachearDashboard(d);
      if (mounted) setState(() { _d = d; _error = null; _desdeCache = false; });
    } catch (e) {
      final c = app.dashboardEnCache();
      if (mounted) setState(() { _d = c ?? _d; _error = c == null && _d == null ? e : null; _desdeCache = c != null; });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final v = AppScope.of(context).version;
    if (v != _version) {
      _version = v;
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final u = app.usuario;
    final d = _d;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hola, ${u?.nombre ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          Text(u?.rol ?? '', style: const TextStyle(fontSize: 13, color: Paleta.suave)),
        ]),
        actions: [
          PopupMenuButton<String>(
            icon: const CircleAvatar(
                backgroundColor: Paleta.primario,
                child: Icon(Icons.person, color: Colors.white)),
            onSelected: (v) {
              if (v == 'ninos') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NinosScreen()));
              } else if (v == 'usuarios') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UsuariosScreen()));
              } else {
                app.logout();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'ninos', child: Text('Niños')),
              // Los enfermeros no gestionan usuarios (el servidor responde 403).
              if (u?.rol != 'enfermero')
                const PopupMenuItem(value: 'usuarios', child: Text('Usuarios')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'salir', child: Text('Cerrar sesión')),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _error != null && d == null
          ? EstadoError(_error!, _cargar)
          : d == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    if (_desdeCache)
                      const AvisoSinConexion('Sin conexión: se muestra la última copia guardada.'),
                    Row(children: [
                      _Stat('Total', '${d.total}', Paleta.primario),
                      const SizedBox(width: 10),
                      _Stat('Riesgo alto', '${d.alto}', Paleta.alto),
                      const SizedBox(width: 10),
                      _Stat('Riesgo medio', '${d.medio}', Paleta.medio),
                    ]),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => context.findAncestorStateOfType<ShellState>()?.irA(1),
                      icon: const Icon(Icons.add),
                      label: const Text('Nueva valoración'),
                    ),
                    const Titulo('Resumen reciente'),
                    _Barras(d.ultimosDias),
                    const Titulo('Valoraciones recientes'),
                    if (d.recientes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Aún no hay valoraciones.', style: TextStyle(color: Paleta.suave)),
                      ),
                    for (final v in d.recientes) ...[
                      ValoracionTile(v,
                          onTap: v.id == null
                              ? null
                              : () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => DetalleScreen(id: v.id!)))),
                      const SizedBox(height: 8),
                    ],
                  ]),
                ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String etiqueta, valor;
  final Color color;
  const _Stat(this.etiqueta, this.valor, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(children: [
              Text(valor,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 2),
              Text(etiqueta, style: const TextStyle(fontSize: 12, color: Paleta.suave)),
            ]),
          ),
        ),
      );
}

class _Barras extends StatelessWidget {
  final List<int> valores;
  const _Barras(this.valores);

  @override
  Widget build(BuildContext context) {
    final max = valores.fold<int>(1, (a, b) => b > a ? b : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < valores.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${valores[i]}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Container(
                        height: 4 + 80 * valores[i] / max,
                        decoration: BoxDecoration(
                            color: Paleta.primario.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
