import 'package:flutter/material.dart';

import '../models/valoracion.dart';
import '../theme/app_theme.dart';

/// Etiqueta de color con el nivel de riesgo.
class BadgeRiesgo extends StatelessWidget {
  final String riesgo;
  const BadgeRiesgo(this.riesgo, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: fondoRiesgo(riesgo), borderRadius: BorderRadius.circular(10)),
        child: Text(riesgo,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colorRiesgo(riesgo))),
      );
}

/// Fila de lista: avatar, código del niño, detalle y nivel de riesgo.
class ItemValoracion extends StatelessWidget {
  final Valoracion valoracion;
  final String subtitulo;
  final VoidCallback? onTap;
  const ItemValoracion({super.key, required this.valoracion, required this.subtitulo, this.onTap});

  @override
  Widget build(BuildContext context) {
    final v = valoracion;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.sombra,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: fondoRiesgo(v.riesgo), borderRadius: BorderRadius.circular(12)),
                  child: Icon(v.esNina ? Icons.girl : Icons.boy, color: colorRiesgo(v.riesgo), size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Niño #${v.codigo}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 1),
                      Text(subtitulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                BadgeRiesgo(v.riesgo),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
