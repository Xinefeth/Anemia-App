// Pantalla 4: Resultado (HU05, HU06; RF14, RF15).
// "riesgo" es una ALERTA DE TAMIZAJE, no un diagnóstico. Se muestran las probabilidades
// calibradas de las 3 clases: riesgo "Alto" con P(Alto)=32 % es un resultado correcto.
import 'package:flutter/material.dart';
import '../models/modelos.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

/// Frase que explica el resultado con la probabilidad calibrada de la clase devuelta.
/// Alto = anemia moderada o severa; Medio = anemia leve; Bajo = sin anemia (dataset de Trujillo).
String textoAlerta(Prediccion p) {
  final pct = fmtPct(p.probRiesgo);
  switch (p.riesgo) {
    case Riesgo.alto:
      return 'Alerta de tamizaje: probabilidad estimada de anemia moderada o severa $pct';
    case Riesgo.medio:
      return 'Alerta de tamizaje: probabilidad estimada de anemia leve $pct';
    case Riesgo.bajo:
      return 'Sin alerta de tamizaje: probabilidad estimada de ausencia de anemia $pct';
  }
}

class ResultadoScreen extends StatefulWidget {
  final DatosNino datos;
  final Prediccion prediccion;
  const ResultadoScreen(
      {super.key, required this.datos, required this.prediccion});

  @override
  State<ResultadoScreen> createState() => _ResultadoScreenState();
}

class _ResultadoScreenState extends State<ResultadoScreen> {
  bool _guardando = false;
  bool _guardada = false;
  bool _enCola = false;
  String? _errorGuardar;

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _errorGuardar = null;
    });
    try {
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
    } catch (e) {
      // Por ejemplo un 422: se muestra el texto del servidor y se puede volver a intentar.
      if (mounted) {
        setState(() {
          _guardando = false;
          _errorGuardar = mensajeError(e);
        });
      }
    }
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
      appBar: AppBar(
          title: const Text('Resultado',
              style: TextStyle(fontWeight: FontWeight.w800))),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: (_guardando || _guardada) ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
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
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icono, size: 56, color: c),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('Riesgo ${p.riesgo.texto.toLowerCase()}',
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, color: c)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(textoAlerta(p),
              key: const Key('texto-alerta'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Paleta.tinta, fontSize: 15)),
        ),
        const SizedBox(height: 16),
        const AvisoApoyo(),
        if (_errorGuardar != null) ...[
          const SizedBox(height: 12),
          ErrorBanner(_errorGuardar!),
        ],
        if (_enCola) ...[
          const SizedBox(height: 12),
          const AvisoSinConexion('Pendiente de envío al servidor.'),
        ],
        if (p.probabilidades.isNotEmpty) ...[
          const Titulo('Probabilidad por clase'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                for (final r in [Riesgo.bajo, Riesgo.medio, Riesgo.alto])
                  _BarraClase(r, p.probabilidades[r] ?? 0, destacada: r == p.riesgo),
                const SizedBox(height: 6),
                const Text(
                  'Probabilidades calibradas con datos de Trujillo (anemia ≈ 2.8 %). '
                  'En poblaciones con mayor prevalencia pueden subestimar el riesgo.',
                  style: TextStyle(color: Paleta.suave, fontSize: 12),
                ),
              ]),
            ),
          ),
        ],
        const Titulo('Datos de la valoración'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(children: [
              _Fila('Niño', d.codigo),
              _Fila('Edad', '${d.edadMeses} meses'),
              _Fila('Sexo', d.sexo == 'F' ? 'Femenino' : 'Masculino'),
              _Fila('Altitud', '${d.altitud.toStringAsFixed(0)} msnm'),
              _Fila('Control CRED', d.cred ? 'Sí' : 'No'),
              _Fila('Suplementación', d.suplementacion ? 'Sí' : 'No'),
              _Fila('Grupo', d.grupo == 'control' ? 'Control' : 'Experimental'),
              _Fila('Modelo / tiempo',
                  '${p.modelo.isEmpty ? 'modelo' : p.modelo} · ${p.tiempoMs} ms',
                  ultima: true),
            ]),
          ),
        ),
        if (p.factores.isNotEmpty) ...[
          const Titulo('Factores generales del modelo'),
          const Text(
            'Importancia de cada variable en el modelo en general; no explica el caso de este niño.',
            style: TextStyle(color: Paleta.suave, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                for (final f in p.factores)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Expanded(
                          flex: 4,
                          child: Text(f.factor,
                              style: const TextStyle(fontSize: 13))),
                      Expanded(
                        flex: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (f.peso /
                                    p.factores
                                        .map((e) => e.peso)
                                        .reduce((a, b) => a > b ? a : b))
                                .clamp(0, 1),
                            minHeight: 10,
                            color: Paleta.primario,
                            backgroundColor: Paleta.borde,
                          ),
                        ),
                      ),
                      SizedBox(
                          width: 48,
                          child: Text(fmtPct(f.peso),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13))),
                    ]),
                  ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ]),
    );
  }
}

/// Barra horizontal con la probabilidad calibrada de una clase.
class _BarraClase extends StatelessWidget {
  final Riesgo riesgo;
  final double valor;
  final bool destacada;
  const _BarraClase(this.riesgo, this.valor, {required this.destacada});

  @override
  Widget build(BuildContext context) {
    final c = Paleta.riesgo(riesgo);
    return Padding(
      key: Key('barra-${riesgo.texto.toLowerCase()}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(
          width: 58,
          child: Text(riesgo.texto,
              style: TextStyle(
                  fontWeight: destacada ? FontWeight.w800 : FontWeight.w500,
                  color: destacada ? c : Paleta.tinta)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: valor.clamp(0, 1),
              minHeight: destacada ? 16 : 11,
              color: c,
              backgroundColor: c.withValues(alpha: 0.15),
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(fmtPct(valor),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontWeight: destacada ? FontWeight.w800 : FontWeight.w600,
                  fontSize: destacada ? 15 : 13)),
        ),
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
            border: ultima
                ? null
                : const Border(bottom: BorderSide(color: Paleta.borde))),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: Paleta.suave)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(v,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
