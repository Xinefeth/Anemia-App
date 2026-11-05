/// Valoración guardada en el servidor (fila del historial).
class Valoracion {
  final int id;
  final String codigo;
  final int edadMeses;
  final String sexo;
  final double hemoglobina;
  final int altitud;
  final String riesgo;
  final double probabilidad;
  final String fecha; // ISO, hora de Perú: 2026-11-05T09:12:00
  final String grupo;
  final int tiempoMs;
  final String registradoPor;

  const Valoracion({
    required this.id,
    required this.codigo,
    required this.edadMeses,
    required this.sexo,
    required this.hemoglobina,
    required this.altitud,
    required this.riesgo,
    required this.probabilidad,
    required this.fecha,
    required this.grupo,
    required this.tiempoMs,
    required this.registradoPor,
  });

  factory Valoracion.fromJson(Map<String, dynamic> j) => Valoracion(
        id: j['id_valoracion'] as int,
        codigo: j['codigo'] as String,
        edadMeses: j['edad_meses'] as int,
        sexo: j['sexo'] as String,
        hemoglobina: (j['hemoglobina'] as num).toDouble(),
        altitud: j['altitud'] as int,
        riesgo: j['riesgo'] as String,
        probabilidad: (j['probabilidad'] as num).toDouble(),
        fecha: j['fecha'] as String,
        grupo: j['grupo'] as String,
        tiempoMs: (j['tiempo_ms'] as num).toInt(),
        registradoPor: j['registrado_por'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id_valoracion': id,
        'codigo': codigo,
        'edad_meses': edadMeses,
        'sexo': sexo,
        'hemoglobina': hemoglobina,
        'altitud': altitud,
        'riesgo': riesgo,
        'probabilidad': probabilidad,
        'fecha': fecha,
        'grupo': grupo,
        'tiempo_ms': tiempoMs,
        'registrado_por': registradoPor,
      };

  bool get esNina => sexo == 'F';
  DateTime get fechaHora => DateTime.parse(fecha);
}
