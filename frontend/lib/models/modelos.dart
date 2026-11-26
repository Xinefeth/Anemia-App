// Modelos de datos del frontend, alineados con el MER (USUARIO, NINO, VALORACION).

enum Riesgo { bajo, medio, alto }

Riesgo riesgoDesdeTexto(String s) {
  switch (s.toLowerCase()) {
    case 'alto':
      return Riesgo.alto;
    case 'medio':
      return Riesgo.medio;
    default:
      return Riesgo.bajo;
  }
}

extension RiesgoTexto on Riesgo {
  String get texto => const {
        Riesgo.bajo: 'Bajo',
        Riesgo.medio: 'Medio',
        Riesgo.alto: 'Alto',
      }[this]!;
}

class Usuario {
  final int id;
  final String nombre;
  final String rol; // médico | enfermero

  const Usuario({required this.id, required this.nombre, required this.rol});

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        rol: j['rol'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'rol': rol};
}

/// Las 5 variables del modelo + código y grupo (RF07). Todas son obligatorias:
/// no hay valores por defecto, para no enviar nunca un dato que el usuario no eligió.
/// El niño se identifica solo por un código, sin nombre (RNF06).
/// La hemoglobina NO es una entrada (el modelo no la usa: evita fuga de datos).
class DatosNino {
  final String codigo;
  final int edadMeses; // 6 a 59
  final String sexo; // F | M
  final double altitud; // msnm del establecimiento, 0 a 700
  final bool cred; // asiste a control CRED
  final bool suplementacion; // recibe suplementación con hierro
  final String grupo; // control | experimental

  const DatosNino({
    required this.codigo,
    required this.edadMeses,
    required this.sexo,
    required this.altitud,
    required this.cred,
    required this.suplementacion,
    required this.grupo,
  });

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'edad_meses': edadMeses,
        'sexo': sexo,
        'altitud': altitud,
        'cred': cred,
        'suplementacion': suplementacion,
        'grupo': grupo,
      };

  /// Tolerante con datos guardados antes (p. ej. caché con `hemoglobina`, que se ignora).
  factory DatosNino.fromJson(Map<String, dynamic> j) => DatosNino(
        codigo: j['codigo'] as String,
        edadMeses: (j['edad_meses'] as num).toInt(),
        sexo: (j['sexo'] ?? 'F') as String,
        altitud: ((j['altitud'] ?? 0) as num).toDouble(),
        cred: j['cred'] == true,
        suplementacion: j['suplementacion'] == true,
        grupo: (j['grupo'] ?? 'control') as String,
      );
}

/// Niño registrado (RF07-RF11). Se identifica por código, sin nombre (RNF06).
class Nino {
  final int id;
  final DatosNino datos;
  const Nino({required this.id, required this.datos});

  factory Nino.fromJson(Map<String, dynamic> j) =>
      Nino(id: j['id'] as int, datos: DatosNino.fromJson(j));
}

/// Usuario gestionado por el personal (RF03-RF06).
class UsuarioAdmin {
  final int id;
  final String nombre;
  final String usuario;
  final String rol; // médico | enfermero
  final bool activo;
  const UsuarioAdmin({
    required this.id,
    required this.nombre,
    required this.usuario,
    required this.rol,
    this.activo = true,
  });

  factory UsuarioAdmin.fromJson(Map<String, dynamic> j) => UsuarioAdmin(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        usuario: j['usuario'] as String,
        rol: j['rol'] as String,
        activo: j['activo'] != false,
      );
}

/// Respuesta de /api/predict (RF13).
/// [riesgo] es una ALERTA DE TAMIZAJE (no un diagnóstico). [probabilidades] son las
/// probabilidades CALIBRADAS de cada clase (a una prevalencia de ~2.8 %); con ellas no se
/// decide la clase: la clase es [riesgo]. Que riesgo sea "Alto" con P(Alto)=32 % es lo esperado.
class Prediccion {
  final Riesgo riesgo;
  final double probabilidad; // calibrada, de la clase [riesgo] (0..1)
  final Map<Riesgo, double> probabilidades; // Bajo, Medio y Alto (calibradas)
  final int tiempoMs;
  final String modelo; // nombre/versión del modelo que predijo
  final List<Factor> factores; // importancia GENERAL de las variables (no explica al niño)

  const Prediccion({
    required this.riesgo,
    required this.probabilidad,
    this.probabilidades = const {},
    required this.tiempoMs,
    this.modelo = '',
    this.factores = const [],
  });

  /// Probabilidad calibrada de la clase devuelta.
  double get probRiesgo => probabilidades[riesgo] ?? probabilidad;

  factory Prediccion.fromJson(Map<String, dynamic> j, {int tiempoMs = 0}) =>
      Prediccion(
        riesgo: riesgoDesdeTexto(j['riesgo'] as String),
        probabilidad: (j['probabilidad'] as num).toDouble(),
        probabilidades: {
          if (j['probabilidades'] is Map)
            for (final e in (j['probabilidades'] as Map).entries)
              riesgoDesdeTexto(e.key as String): (e.value as num).toDouble(),
        },
        tiempoMs: (j['tiempo_ms'] as num?)?.toInt() ?? tiempoMs,
        modelo: (j['modelo'] ?? '') as String,
        factores: ((j['factores_influyentes'] ?? []) as List)
            .map((e) => Factor.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Variable que influyó en la predicción y su peso relativo.
class Factor {
  final String factor;
  final double peso;
  const Factor(this.factor, this.peso);

  factory Factor.fromJson(Map<String, dynamic> j) =>
      Factor(j['factor'] as String, (j['peso'] as num).toDouble());
}

/// Valoración registrada en el servidor (RF15).
class Valoracion {
  final int? id;
  final DatosNino datos;
  final Riesgo riesgo;
  final double probabilidad;
  final DateTime fecha;
  final bool pendiente;

  const Valoracion({
    this.id,
    required this.datos,
    required this.riesgo,
    required this.probabilidad,
    required this.fecha,
    this.pendiente = false,
  });

  factory Valoracion.fromJson(Map<String, dynamic> j) => Valoracion(
        id: j['id'] as int?,
        datos: DatosNino.fromJson(j),
        riesgo: riesgoDesdeTexto(j['riesgo'] as String),
        probabilidad: (j['probabilidad'] as num).toDouble(),
        fecha: DateTime.parse(j['fecha'] as String),
        pendiente: j['pendiente'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        ...datos.toJson(),
        'riesgo': riesgo.texto,
        'probabilidad': probabilidad,
        'fecha': fecha.toIso8601String(),
        'pendiente': pendiente,
      };
}

class Dashboard {
  final int total;
  final int alto;
  final int medio;
  final int bajo;
  final double hbPromedio;
  final List<int> ultimosDias; // valoraciones por día (resumen)
  final List<Valoracion> recientes;

  const Dashboard({
    required this.total,
    required this.alto,
    required this.medio,
    required this.bajo,
    required this.hbPromedio,
    required this.ultimosDias,
    required this.recientes,
  });

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        total: j['total'] as int,
        alto: j['alto'] as int,
        medio: j['medio'] as int,
        bajo: j['bajo'] as int,
        hbPromedio: ((j['hb_promedio'] ?? 0) as num).toDouble(),
        ultimosDias: ((j['ultimos_dias'] ?? []) as List).cast<int>(),
        recientes: ((j['recientes'] ?? []) as List)
            .map((e) => Valoracion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'total': total,
        'alto': alto,
        'medio': medio,
        'bajo': bajo,
        'hb_promedio': hbPromedio,
        'ultimos_dias': ultimosDias,
        'recientes': recientes.map((v) => v.toJson()).toList(),
      };
}

/// Indicador comparado entre grupo control y experimental (PC, TR, TT).
class Indicador {
  final double control;
  final double experimental;
  const Indicador(this.control, this.experimental);

  factory Indicador.fromJson(Map<String, dynamic> j) => Indicador(
        (j['control'] as num).toDouble(),
        (j['experimental'] as num).toDouble(),
      );
}

/// Conteo por grupo (tamaños de muestra del reporte).
class Conteo {
  final int control;
  final int experimental;
  const Conteo(this.control, this.experimental);

  static Conteo? desde(dynamic j) => j is Map
      ? Conteo((j['control'] as num).toInt(), (j['experimental'] as num).toInt())
      : null;

  int de(bool experimental_) => experimental_ ? experimental : control;
}

/// Cómo mostrar un indicador de un grupo: valor o "Sin datos", y su muestra.
class InfoGrupo {
  final bool sinDatos;
  final String? nota; // p. ej. "n=12"
  const InfoGrupo({required this.sinDatos, this.nota});
}

class Reporte {
  final DateTime desde;
  final DateTime hasta;
  final int total;
  final Indicador pc; // % de clasificaciones correctas
  final Indicador tr; // tiempo de respuesta (segundos)
  final Indicador tt; // tasa de tamizaje (%)
  // Tamaños de muestra; opcionales (servidores antiguos no los envían).
  final Conteo? nValoraciones;
  final Conteo? nPc;
  final Conteo? nTtValorados;
  final Conteo? nTtRegistrados;

  const Reporte({
    required this.desde,
    required this.hasta,
    required this.total,
    required this.pc,
    required this.tr,
    required this.tt,
    this.nValoraciones,
    this.nPc,
    this.nTtValorados,
    this.nTtRegistrados,
  });

  /// PC: "Sin datos" si no hubo clasificaciones evaluables; si no, el % con n.
  InfoGrupo infoPc(bool exp) {
    final n = nPc?.de(exp);
    if (n == null) return const InfoGrupo(sinDatos: false);
    return InfoGrupo(sinDatos: n == 0, nota: n == 0 ? null : 'n=$n');
  }

  /// TR: "Sin datos" si el grupo no tiene valoraciones.
  InfoGrupo infoTr(bool exp) {
    final n = nValoraciones?.de(exp);
    if (n == null) return const InfoGrupo(sinDatos: false);
    return InfoGrupo(sinDatos: n == 0, nota: n == 0 ? null : 'n=$n');
  }

  /// TT: "Sin datos" si no hay registros; si no, el % con n=valorados/registrados.
  InfoGrupo infoTt(bool exp) {
    final reg = nTtRegistrados?.de(exp);
    if (reg == null) return const InfoGrupo(sinDatos: false);
    final val = nTtValorados?.de(exp);
    return InfoGrupo(
        sinDatos: reg == 0, nota: reg == 0 ? null : 'n=${val ?? '?'}/$reg');
  }

  factory Reporte.fromJson(Map<String, dynamic> j) => Reporte(
        desde: DateTime.parse(j['desde'] as String),
        hasta: DateTime.parse(j['hasta'] as String),
        total: j['total'] as int,
        pc: Indicador.fromJson(j['pc'] as Map<String, dynamic>),
        tr: Indicador.fromJson(j['tr'] as Map<String, dynamic>),
        tt: Indicador.fromJson(j['tt'] as Map<String, dynamic>),
        nValoraciones: Conteo.desde(j['n_valoraciones']),
        nPc: Conteo.desde(j['n_pc']),
        nTtValorados: Conteo.desde(j['n_tt_valorados']),
        nTtRegistrados: Conteo.desde(j['n_tt_registrados']),
      );
}

/// Valoración guardada en el teléfono mientras no hay conexión (cola SQLite, RNF09).
/// Si la predicción ya se había obtenido se guardan [riesgo] y [probabilidad]; si no
/// (se evaluó sin conexión) quedan nulos y el servidor calcula el riesgo al recibirla.
/// [error] se llena si el servidor rechazó los datos: se conservan para no perderlos.
class PendienteEnvio {
  final int? idLocal;
  final DatosNino datos;
  final DateTime fecha;
  final Riesgo? riesgo;
  final double? probabilidad;
  final String? error;

  const PendienteEnvio({
    this.idLocal,
    required this.datos,
    required this.fecha,
    this.riesgo,
    this.probabilidad,
    this.error,
  });

  PendienteEnvio conId(int id) => PendienteEnvio(
      idLocal: id, datos: datos, fecha: fecha, riesgo: riesgo, probabilidad: probabilidad, error: error);

  PendienteEnvio conError(String? e) => PendienteEnvio(
      idLocal: idLocal, datos: datos, fecha: fecha, riesgo: riesgo, probabilidad: probabilidad, error: e);

  Map<String, dynamic> toJson() => {
        'id_local': idLocal,
        'datos': datos.toJson(),
        'fecha': fecha.toIso8601String(),
        'riesgo': riesgo?.texto,
        'probabilidad': probabilidad,
        'error': error,
      };

  factory PendienteEnvio.fromJson(Map<String, dynamic> j) => PendienteEnvio(
        idLocal: j['id_local'] as int?,
        datos: DatosNino.fromJson(j['datos'] as Map<String, dynamic>),
        fecha: DateTime.parse(j['fecha'] as String),
        riesgo: j['riesgo'] == null ? null : riesgoDesdeTexto(j['riesgo'] as String),
        probabilidad: (j['probabilidad'] as num?)?.toDouble(),
        error: j['error'] as String?,
      );
}
