// Pantalla 5: Historial (HU07, HU08; RF16, RF17).
import 'package:flutter/material.dart';
import '../models/modelos.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'detalle_screen.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});
  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final _buscar = TextEditingController();
  Riesgo? _riesgo;
  List<Valoracion>? _lista;
  Object? _error;
  bool _desdeCache = false;
  int _version = -1;

  Future<void> _cargar() async {
    final app = AppScope.of(context);
    final filtro = Filtro(riesgo: _riesgo, busqueda: _buscar.text.trim());
    try {
      final l = await app.api.listar(filtro);
      // Solo se cachea la lista completa (sin filtros) para uso sin conexión.
      if (_riesgo == null && filtro.busqueda.isEmpty) await app.cachearHistorial(l);
      if (mounted) setState(() { _lista = l; _error = null; _desdeCache = false; });
    } catch (e) {
      if (e is SesionExpirada) return;
      // Sin conexión: se filtra localmente la última copia guardada.
      final c = app.historialEnCache().where((v) {
        if (_riesgo != null && v.riesgo != _riesgo) return false;
        final q = filtro.busqueda.toLowerCase();
        return q.isEmpty ||
            v.datos.codigo.toLowerCase().contains(q) ||
            v.fecha.toIso8601String().startsWith(q);
      }).toList();
      final hayCopia = app.historialEnCache().isNotEmpty;
      if (mounted) {
        setState(() {
          _lista = hayCopia ? c : null;
          _error = hayCopia ? null : e;
          _desdeCache = hayCopia;
        });
      }
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
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  Widget _chip(String t, Riesgo? r) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(t),
          selected: _riesgo == r,
          selectedColor: r == null ? Paleta.primario : Paleta.riesgo(r),
          labelStyle: TextStyle(color: _riesgo == r ? Colors.white : Paleta.tinta),
          showCheckmark: false,
          onSelected: (_) {
            setState(() => _riesgo = r);
            _cargar();
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pendientes = app.pendientes
        .where((v) =>
            (_riesgo == null || v.riesgo == _riesgo) &&
            (_buscar.text.isEmpty ||
                v.datos.codigo.toLowerCase().contains(_buscar.text.toLowerCase())))
        .toList();
    final l = _lista;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: TextField(
            controller: _buscar,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _cargar(),
            decoration: InputDecoration(
              hintText: 'Código del niño o fecha (aaaa-mm-dd)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _buscar.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _buscar.clear();
                        _cargar();
                      }),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            _chip('Todos', null),
            _chip('Alto', Riesgo.alto),
            _chip('Medio', Riesgo.medio),
            _chip('Bajo', Riesgo.bajo),
          ]),
        ),
        Expanded(
          child: _error != null && l == null
              ? EstadoError(_error!, _cargar)
              : l == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                        if (_desdeCache)
                          const AvisoSinConexion('Sin conexión: se muestra la última copia guardada.'),
                        if (l.isEmpty && pendientes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No hay valoraciones que coincidan.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Paleta.suave)),
                          ),
                        for (final v in [...pendientes, ...l]) ...[
                          ValoracionTile(v,
                              onTap: v.id == null
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => DetalleScreen(id: v.id!, inicial: v)))),
                          const SizedBox(height: 8),
                        ],
                      ]),
                    ),
        ),
      ]),
    );
  }
}
