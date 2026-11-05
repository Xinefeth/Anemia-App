import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Anillo circular con el porcentaje y el nivel de riesgo, coloreado por nivel.
class AnilloRiesgo extends StatelessWidget {
  final int porcentaje; // 0..100
  final String riesgo;
  final double tamano;

  const AnilloRiesgo({super.key, required this.porcentaje, required this.riesgo, this.tamano = 170});

  @override
  Widget build(BuildContext context) {
    final color = colorRiesgo(riesgo);
    return Semantics(
      label: 'Riesgo ${riesgo.toLowerCase()}, $porcentaje por ciento',
      child: SizedBox(
        width: tamano,
        height: tamano,
        child: CustomPaint(
          painter: _AnilloPainter(porcentaje / 100, color, fondoRiesgo(riesgo)),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$porcentaje%',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: color)),
                Text('RIESGO ${riesgo.toUpperCase()}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnilloPainter extends CustomPainter {
  final double progreso;
  final Color color;
  final Color fondo;
  _AnilloPainter(this.progreso, this.color, this.fondo);

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 20.0;
    final rect = Offset.zero & size;
    final arco = rect.deflate(grosor / 2);
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arco, 0, 2 * math.pi, false, pincel..color = fondo);
    canvas.drawArc(arco, -math.pi / 2, 2 * math.pi * progreso.clamp(0.0, 1.0), false, pincel..color = color);
  }

  @override
  bool shouldRepaint(_AnilloPainter o) =>
      o.progreso != progreso || o.color != color || o.fondo != fondo;
}
