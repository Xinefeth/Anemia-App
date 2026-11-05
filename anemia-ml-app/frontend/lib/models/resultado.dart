/// Respuesta de POST /api/predict.
class Resultado {
  final String riesgo; // Bajo | Medio | Alto
  final double probabilidad; // 0..1
  final String modelo;
  final int tiempoMs;

  const Resultado({
    required this.riesgo,
    required this.probabilidad,
    required this.modelo,
    required this.tiempoMs,
  });

  factory Resultado.fromJson(Map<String, dynamic> j) => Resultado(
        riesgo: j['riesgo'] as String,
        probabilidad: (j['probabilidad'] as num).toDouble(),
        modelo: j['modelo'] as String,
        tiempoMs: (j['tiempo_ms'] as num).toInt(),
      );

  int get porcentaje => (probabilidad * 100).round();

  /// Mensaje orientativo (la app apoya, no diagnostica).
  String get recomendacion => switch (riesgo) {
        'Alto' => 'Se recomienda evaluación clínica inmediata',
        'Medio' => 'Se recomienda seguimiento y control clínico',
        _ => 'Sin indicios de riesgo elevado; continuar controles de rutina',
      };

  /// "1.2 s" o "85 ms".
  String get tiempoTexto =>
      tiempoMs >= 1000 ? '${(tiempoMs / 1000).toStringAsFixed(1)} s' : '$tiempoMs ms';
}
