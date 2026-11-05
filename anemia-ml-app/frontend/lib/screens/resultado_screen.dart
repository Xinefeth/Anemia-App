import 'package:flutter/material.dart';

import '../models/nino.dart';
import '../models/resultado.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import '../widgets/anillo_riesgo.dart';
import '../widgets/boton_principal.dart';
import '../widgets/header_gradiente.dart';
import '../widgets/tarjeta.dart';

/// Pantalla 4 · Resultado de la valoración (HU05, HU06).
/// Al volver con `true` el formulario se limpia para una nueva valoración.
class ResultadoScreen extends StatefulWidget {
  final DatosNino datos;
  final Resultado resultado;
  const ResultadoScreen({super.key, required this.datos, required this.resultado});

  @override
  State<ResultadoScreen> createState() => _ResultadoScreenState();
}

class _ResultadoScreenState extends State<ResultadoScreen> {
  bool _guardando = false;
  bool _guardado = false;

  Future<void> _guardar() async {
    final cuerpo = widget.datos.toValoracionJson(tiempoMs: widget.resultado.tiempoMs);
    setState(() => _guardando = true);
    String mensaje;
    try {
      await ApiService.instancia.guardarValoracion(cuerpo);
      mensaje = 'Valoración guardada';
      _guardado = true;
    } on ApiException catch (e) {
      if (e.sinConexion) {
        // HU04: sin conexión no se pierde el dato; se envía luego automáticamente.
        await DbService.instancia.guardarPendiente(AuthService.instancia.usuario!.id, cuerpo);
        mensaje = 'Sin conexión: guardada en el teléfono; se enviará al recuperar la conexión';
        _guardado = true;
      } else {
        mensaje = e.mensaje;
      }
    }
    if (!mounted) return;
    setState(() => _guardando = false);
    datosCambiaron.value++;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resultado;
    final d = widget.datos;
    final color = colorRiesgo(r.riesgo);
    return Column(
      children: [
        HeaderGradiente(
          titulo: 'Resultado',
          subtitulo: 'Niño #${d.codigo}',
          onBack: () => Navigator.of(context).pop(false),
          extraInferior: 8,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(children: [
                  AnilloRiesgo(porcentaje: r.porcentaje, riesgo: r.riesgo),
                  const SizedBox(height: 14),
                  Text('Riesgo ${r.riesgo} de anemia',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 4),
                  Text(r.recomendacion,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ]),
              ),
              Tarjeta(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  _Fila('Nivel de hemoglobina', '${d.hemoglobina} g/dL'),
                  _Fila('Clasificación', r.riesgo, color: color),
                  _Fila('Probabilidad', '${(r.probabilidad * 100).toStringAsFixed(1)}%'),
                  _Fila('Modelo', r.modelo),
                  _Fila('Tiempo de respuesta', r.tiempoTexto, ultima: true),
                ]),
              ),
              Row(children: [
                Expanded(
                  child: BotonPrincipal(
                    texto: _guardado ? 'Guardada' : 'Guardar',
                    icono: _guardado ? Icons.check : Icons.save_outlined,
                    secundario: true,
                    cargando: _guardando,
                    onPressed: _guardado ? null : _guardar,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BotonPrincipal(
                    texto: 'Nueva',
                    icono: Icons.add,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              const Text(
                  'Resultado de apoyo generado por un modelo de Machine Learning. No reemplaza el diagnóstico clínico.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  final String clave;
  final String valor;
  final Color? color;
  final bool ultima;
  const _Fila(this.clave, this.valor, {this.color, this.ultima = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
            border: ultima ? null : const Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(clave, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          Text(valor,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? AppColors.text)),
        ]),
      );
}
