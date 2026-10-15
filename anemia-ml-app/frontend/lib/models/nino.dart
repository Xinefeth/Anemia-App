// Modelo de datos del niño.
class Nino {
  final int edadMeses;
  final double hemoglobina;

  Nino({required this.edadMeses, required this.hemoglobina});

  Map<String, dynamic> toJson() => {
        'edad_meses': edadMeses,
        'hemoglobina': hemoglobina,
      };
}
