// Pantalla 4: Resultado (HU05, HU06; RF14, RF15).
import 'package:flutter/material.dart';
import '../models/modelos.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

class ResultadoScreen extends StatefulWidget {
  final DatosNino datos;
  final Prediccion prediccion;
  const ResultadoScreen({super.key, required this.datos, required this.prediccion});

  @override
  State<ResultadoScreen> createState() => _ResultadoScreenState();
}

class _ResultadoScreenState extends State<ResultadoScreen> {
  bool _guardando = false;
  bool _guardada = false;
  bool _enCola = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final ok = await AppScope.of(context)
        .guardarValoracion(widget.datos, widget.prediccion);
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _guardada = true;
      _enCola = !ok;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Valoración guardada correctamente.'
          : 'Sin conexión: se guardó en el teléfono y se enviará sola al reconectar.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prediccion;
    final d = widget.datos;
    final c = Paleta.riesgo(p.riesgo);
    final icono = {
      Riesgo.bajo: Icons.check_circle,
      Riesgo.medio: Icons.warning_amber_rounded,
      Riesgo.alto: Icons.error,
    }[p.riesgo]!;

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icono, size: 72, color: c),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('Riesgo ${p.riesgo.texto.toLowerCase()}',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text('Probabilidad del ${fmtPct(p.probabilidad)}',
              style: const TextStyle(color: Paleta.suave, fontSize: 15)),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(children: [
              _Fila('Niño', d.codigo),
              _Fila('Edad', '${d.edadMeses} meses'),
              _Fila('Hemoglobina', '${d.hemoglobina.toStringAsFixed(1)} g/dL'),
              _Fila('Clasificación', p.riesgo.texto),
              _Fila('Probabilidad', fmtPct(p.probabilidad)),
              _Fila('Modelo / tiempo', '${p.tiempoMs} ms', ultima: true),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Resultado de apoyo: no reemplaza el diagnóstico clínico.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Paleta.suave, fontSize: 12),
        ),
        if (_enCola) ...[
          const SizedBox(height: 12),
          const AvisoSinConexion('Pendiente de envío al servidor.'),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: (_guardando || _guardada) ? null : _guardar,
              child: _guardando
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(_guardada ? 'Guardada' : 'Guardar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Nueva'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _Fila extends StatelessWidget {
  final String k, v;
  final bool ultima;
  const _Fila(this.k, this.v, {this.ultima = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            border: ultima ? null : const Border(bottom: BorderSide(color: Paleta.borde))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: Paleta.suave)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}
