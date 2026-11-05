import 'valoracion.dart';

/// Datos del Dashboard (GET /api/dashboard).
class Resumen {
  final int total;
  final int enRiesgo;
  final double? precision; // 0..1
  final String precisionOrigen;
  final List<({String mes, int total})> meses; // mes = "AAAA-MM"
  final List<Valoracion> recientes;

  const Resumen({
    required this.total,
    required this.enRiesgo,
    required this.precision,
    required this.precisionOrigen,
    required this.meses,
    required this.recientes,
  });

  factory Resumen.fromJson(Map<String, dynamic> j) => Resumen(
        total: j['total'] as int,
        enRiesgo: j['en_riesgo'] as int,
        precision: (j['precision'] as num?)?.toDouble(),
        precisionOrigen: j['precision_origen'] as String,
        meses: [
          for (final m in j['meses'] as List)
            (mes: m['mes'] as String, total: m['total'] as int)
        ],
        recientes: [
          for (final v in j['recientes'] as List) Valoracion.fromJson(v as Map<String, dynamic>)
        ],
      );
}

/// Indicadores de un grupo en un reporte.
class IndicadoresGrupo {
  final int total;
  final double? pc; // % clasificaciones correctas
  final double? trSegundos;
  final double? tt; // niños tamizados por día
  final Map<String, int> distribucion;

  const IndicadoresGrupo({
    required this.total,
    required this.pc,
    required this.trSegundos,
    required this.tt,
    required this.distribucion,
  });

  factory IndicadoresGrupo.fromJson(Map<String, dynamic> j) => IndicadoresGrupo(
        total: j['total'] as int,
        pc: (j['pc'] as num?)?.toDouble(),
        trSegundos: (j['tr_segundos'] as num?)?.toDouble(),
        tt: (j['tt'] as num?)?.toDouble(),
        distribucion: (j['distribucion'] as Map)
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );
}

/// Reporte por rango de fechas (GET/POST /api/reporte).
class Reporte {
  final int? idReporte;
  final String inicio;
  final String fin;
  final int total;
  final IndicadoresGrupo control;
  final IndicadoresGrupo experimental;

  const Reporte({
    required this.idReporte,
    required this.inicio,
    required this.fin,
    required this.total,
    required this.control,
    required this.experimental,
  });

  factory Reporte.fromJson(Map<String, dynamic> j) => Reporte(
        idReporte: j['id_reporte'] as int?,
        inicio: j['inicio'] as String,
        fin: j['fin'] as String,
        total: j['total'] as int,
        control: IndicadoresGrupo.fromJson(j['control'] as Map<String, dynamic>),
        experimental: IndicadoresGrupo.fromJson(j['experimental'] as Map<String, dynamic>),
      );
}
