import 'package:flutter/material.dart';

import '../models/valoracion.dart';
import '../theme/app_theme.dart';
import '../utils.dart';
import '../widgets/anillo_riesgo.dart';
import '../widgets/header_gradiente.dart';
import '../widgets/tarjeta.dart';

/// Detalle de una valoración guardada (se abre desde Historial o Inicio).
class DetalleScreen extends StatelessWidget {
  final Valoracion valoracion;
  const DetalleScreen({super.key, required this.valoracion});

  @override
  Widget build(BuildContext context) {
    final v = valoracion;
    final filas = <(String, String)>[
      ('Fecha', fechaCorta(v.fechaHora)),
      ('Edad', '${v.edadMeses} meses'),
      ('Sexo', sexoTexto(v.sexo)),
      ('Hemoglobina', '${v.hemoglobina} g/dL'),
      ('Altitud', '${v.altitud} msnm'),
      ('Probabilidad', '${(v.probabilidad * 100).toStringAsFixed(1)}%'),
      ('Grupo', v.grupo == 'control' ? 'Control' : 'Experimental'),
      ('Tiempo de valoración', v.tiempoMs >= 1000 ? '${(v.tiempoMs / 1000).toStringAsFixed(1)} s' : '${v.tiempoMs} ms'),
      ('Registrado por', v.registradoPor),
    ];
    return Scaffold(
      body: Column(
        children: [
          HeaderGradiente(
              titulo: 'Niño #${v.codigo}',
              subtitulo: 'Detalle de la valoración',
              onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: AnilloRiesgo(
                      porcentaje: (v.probabilidad * 100).round(), riesgo: v.riesgo, tamano: 150),
                )),
                Tarjeta(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(children: [
                    for (var i = 0; i < filas.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                            border: i == filas.length - 1
                                ? null
                                : const Border(bottom: BorderSide(color: AppColors.border))),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(filas[i].$1, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                          Flexible(
                            child: Text(filas[i].$2,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                          ),
                        ]),
                      ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
