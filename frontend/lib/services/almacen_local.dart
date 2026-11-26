// Almacén local de valoraciones pendientes de envío (RNF09: sin conexión no se pierden datos).
// En el teléfono se guardan en SQLite (sqflite). En web (donde sqflite no existe) y como
// respaldo si SQLite no se puede abrir se usa shared_preferences. Las pruebas usan memoria.
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/modelos.dart';

abstract class AlmacenPendientes {
  /// Todos los pendientes, del más antiguo al más reciente.
  Future<List<PendienteEnvio>> todos();

  /// Guarda y devuelve el pendiente con su [PendienteEnvio.idLocal].
  Future<PendienteEnvio> agregar(PendienteEnvio p);

  /// Marca (o limpia, con null) el error de un pendiente que el servidor rechazó.
  Future<void> marcarError(int idLocal, String? error);

  Future<void> eliminar(int idLocal);

  Future<void> cerrar() async {}

  /// Descripción para diagnóstico ("sqlite", "preferencias", "memoria").
  String get tipo;
}

/// Solo para pruebas: no sobrevive al cierre de la app.
class MemoriaAlmacen implements AlmacenPendientes {
  final List<PendienteEnvio> _l = [];
  int _sig = 1;

  @override
  String get tipo => 'memoria';

  @override
  Future<List<PendienteEnvio>> todos() async => List.of(_l);

  @override
  Future<PendienteEnvio> agregar(PendienteEnvio pen) async {
    final n = pen.conId(_sig++);
    _l.add(n);
    return n;
  }

  @override
  Future<void> marcarError(int idLocal, String? error) async {
    final i = _l.indexWhere((e) => e.idLocal == idLocal);
    if (i >= 0) _l[i] = _l[i].conError(error);
  }

  @override
  Future<void> eliminar(int idLocal) async => _l.removeWhere((e) => e.idLocal == idLocal);

  @override
  Future<void> cerrar() async {}
}

/// Respaldo (web): lista JSON en shared_preferences.
class PrefsAlmacen implements AlmacenPendientes {
  static const _clave = 'pendientes_v2';
  final SharedPreferences _prefs;
  PrefsAlmacen(this._prefs);

  @override
  String get tipo => 'preferencias';

  List<PendienteEnvio> _leer() {
    final s = _prefs.getString(_clave);
    if (s == null) return [];
    return (jsonDecode(s) as List)
        .map((e) => PendienteEnvio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _escribir(List<PendienteEnvio> l) =>
      _prefs.setString(_clave, jsonEncode(l.map((e) => e.toJson()).toList()));

  @override
  Future<List<PendienteEnvio>> todos() async => _leer();

  @override
  Future<PendienteEnvio> agregar(PendienteEnvio pen) async {
    final l = _leer();
    final id = l.fold<int>(0, (m, e) => (e.idLocal ?? 0) > m ? e.idLocal! : m) + 1;
    final n = pen.conId(id);
    await _escribir([...l, n]);
    return n;
  }

  @override
  Future<void> marcarError(int idLocal, String? error) async {
    await _escribir(
        _leer().map((e) => e.idLocal == idLocal ? e.conError(error) : e).toList());
  }

  @override
  Future<void> eliminar(int idLocal) async =>
      _escribir(_leer().where((e) => e.idLocal != idLocal).toList());

  @override
  Future<void> cerrar() async {}
}

/// Cola en SQLite. Tabla `pendientes`: una fila por valoración sin enviar.
class SqliteAlmacen implements AlmacenPendientes {
  static const nombreArchivo = 'anemia_pendientes.db';
  final Database _db;
  SqliteAlmacen._(this._db);

  /// Abre (o crea) la base con la [fabrica] dada en [ruta]. Permite probar con sqflite_common_ffi.
  static Future<SqliteAlmacen> abrirEn(DatabaseFactory fabrica, String ruta) async {
    final db = await fabrica.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE pendientes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            datos TEXT NOT NULL,
            fecha TEXT NOT NULL,
            riesgo TEXT,
            probabilidad REAL,
            error TEXT
          )'''),
      ),
    );
    return SqliteAlmacen._(db);
  }

  /// Base en la carpeta de datos de la app (privada, no accesible por otras apps).
  static Future<SqliteAlmacen> abrir() async =>
      abrirEn(databaseFactory, p.join(await getDatabasesPath(), nombreArchivo));

  @override
  String get tipo => 'sqlite';

  PendienteEnvio _desdeFila(Map<String, Object?> f) => PendienteEnvio(
        idLocal: f['id'] as int,
        datos: DatosNino.fromJson(jsonDecode(f['datos'] as String) as Map<String, dynamic>),
        fecha: DateTime.parse(f['fecha'] as String),
        riesgo: f['riesgo'] == null ? null : riesgoDesdeTexto(f['riesgo'] as String),
        probabilidad: (f['probabilidad'] as num?)?.toDouble(),
        error: f['error'] as String?,
      );

  @override
  Future<List<PendienteEnvio>> todos() async =>
      (await _db.query('pendientes', orderBy: 'id ASC')).map(_desdeFila).toList();

  @override
  Future<PendienteEnvio> agregar(PendienteEnvio pen) async {
    final id = await _db.insert('pendientes', {
      'datos': jsonEncode(pen.datos.toJson()),
      'fecha': pen.fecha.toIso8601String(),
      'riesgo': pen.riesgo?.texto,
      'probabilidad': pen.probabilidad,
      'error': pen.error,
    });
    return pen.conId(id);
  }

  @override
  Future<void> marcarError(int idLocal, String? error) async {
    await _db.update('pendientes', {'error': error}, where: 'id = ?', whereArgs: [idLocal]);
  }

  @override
  Future<void> eliminar(int idLocal) async {
    await _db.delete('pendientes', where: 'id = ?', whereArgs: [idLocal]);
  }

  @override
  Future<void> cerrar() => _db.close();
}

/// SQLite en móvil; preferencias en web o si SQLite no se puede abrir; memoria como último recurso.
Future<AlmacenPendientes> crearAlmacenPorDefecto(SharedPreferences? prefs) async {
  if (!kIsWeb) {
    try {
      return await SqliteAlmacen.abrir();
    } catch (_) {
      // plataforma sin sqflite (p. ej. escritorio): se usa el respaldo
    }
  }
  return prefs != null ? PrefsAlmacen(prefs) : MemoriaAlmacen();
}
