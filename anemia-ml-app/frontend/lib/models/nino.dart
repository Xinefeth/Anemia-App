/// Datos clínicos ingresados en el formulario. El código es anónimo (sin nombres ni DNI).
class DatosNino {
  final String codigo;
  final int edadMeses;
  final String sexo; // 'M' | 'F'
  final double hemoglobina;
  final int altitud;
  final String grupo; // 'control' | 'experimental'

  const DatosNino({
    required this.codigo,
    required this.edadMeses,
    required this.sexo,
    required this.hemoglobina,
    required this.altitud,
    required this.grupo,
  });

  /// Cuerpo de POST /api/predict.
  Map<String, dynamic> toPredictJson() => {
        'edad_meses': edadMeses,
        'hemoglobina': hemoglobina,
        'altitud': altitud,
        'sexo': sexo,
      };

  /// Cuerpo de POST /api/valoracion.
  Map<String, dynamic> toValoracionJson({int? tiempoMs}) => {
        ...toPredictJson(),
        'codigo': codigo,
        'grupo': grupo,
        if (tiempoMs != null) 'tiempo_ms': tiempoMs,
      };
}
