// Detalle de una valoración (HU07, RF18) y eliminación (RF19).
import 'package:flutter/material.dart';
import '../models/modelos.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

class DetalleScreen extends StatefulWidget {
  final int id;
  final Valoracion? inicial; // permite mostrar el dato en caché sin conexión
  const DetalleScreen({super.key, required this.id, this.inicial});

  @override
  State<DetalleScreen> createState() => _DetalleScreenState();
}

class _DetalleScreenState extends State<DetalleScreen> {
  Valoracion? _v;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _v = widget.inicial;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final v = await AppScope.of(context).api.detalle(widget.id);
      if (mounted) setState(() { _v = v; _error = null; });
    } catch (e) {
      if (mounted && _v == null) setState(() => _error = e);
    }
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar valoración'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Eliminar', style: TextStyle(color: Paleta.alto))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final app = AppScope.of(context);
    final nav = Navigator.of(context);
    final msg = ScaffoldMessenger.of(context);
    try {
      await app.api.eliminar(widget.id);
      app.invalidar();
      nav.pop();
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text(mensajeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (v != null)
            IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: _eliminar),
        ],
      ),
      body: v == null
          ? (_error != null
              ? EstadoError(_error!, _cargar)
              : const Center(child: CircularProgressIndicator()))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    RiesgoBadge(v.riesgo),
                    const SizedBox(height: 10),
                    Text('Probabilidad estimada ${fmtPct(v.probabilidad)}',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Paleta.riesgo(v.riesgo))),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              const AvisoApoyo(),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(children: [
                    _fila('Niño', v.datos.codigo),
                    _fila('Fecha', fmtFecha(v.fecha)),
                    _fila('Edad', '${v.datos.edadMeses} meses'),
                    _fila('Sexo', v.datos.sexo == 'F' ? 'Femenino' : 'Masculino'),
                    _fila('Altitud', '${v.datos.altitud.toStringAsFixed(0)} msnm'),
                    _fila('Control CRED', v.datos.cred ? 'Sí' : 'No'),
                    _fila('Suplementación', v.datos.suplementacion ? 'Sí' : 'No'),
                    _fila('Grupo', v.datos.grupo == 'control' ? 'Control' : 'Experimental', ultima: true),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              const Text('El riesgo es una alerta de tamizaje, no un diagnóstico.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Paleta.suave, fontSize: 12)),
            ]),
    );
  }

  Widget _fila(String k, String v, {bool ultima = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            border: ultima ? null : const Border(bottom: BorderSide(color: Paleta.borde))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: Paleta.suave)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}
