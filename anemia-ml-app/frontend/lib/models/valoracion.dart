// Modelo del resultado de la valoración.
class Valoracion {
  final String riesgo;
  final double probabilidad;

  Valoracion({required this.riesgo, required this.probabilidad});

  factory Valoracion.fromJson(Map<String, dynamic> json) => Valoracion(
        riesgo: json['riesgo'],
        probabilidad: (json['probabilidad'] as num).toDouble(),
      );
}
