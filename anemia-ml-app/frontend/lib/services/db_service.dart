import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/valoracion.dart';

/// Valoración que no se pudo enviar por falta de conexión.
class Pendiente {
  final int id;
  final Map<String, dynamic> cuerpo;
  final String? error;
  const Pendiente(this.id, this.cuerpo, this.error);

  String get codigo => cuerpo['codigo'] as String;
}

/// Base de datos local (SQLite): cola de valoraciones pendientes y copia del historial.
class DbService {
  DbService._();
  static final instancia = DbService._();

  Database? _db;

  Future<Database> get _base async => _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'anemia_local.db'),
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE pendientes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario_id INTEGER NOT NULL,
            cuerpo TEXT NOT NULL,
            creado TEXT NOT NULL,
            error TEXT)''');
          await db.execute('''CREATE TABLE historial_cache (
            id_valoracion INTEGER PRIMARY KEY,
            cuerpo TEXT NOT NULL)''');
        },
      );

  // ----- Cola de pendientes (HU04: no perder datos sin conexión) -----

  Future<void> guardarPendiente(int usuarioId, Map<String, dynamic> cuerpo) async {
    final db = await _base;
    await db.insert('pendientes', {
      'usuario_id': usuarioId,
      'cuerpo': jsonEncode(cuerpo),
      'creado': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Pendiente>> pendientes(int usuarioId) async {
    final db = await _base;
    final filas = await db.query('pendientes',
        where: 'usuario_id = ?', whereArgs: [usuarioId], orderBy: 'id');
    return [
      for (final f in filas)
        Pendiente(f['id'] as int, jsonDecode(f['cuerpo'] as String) as Map<String, dynamic>,
            f['error'] as String?)
    ];
  }

  Future<void> marcarError(int id, String error) async {
    final db = await _base;
    await db.update('pendientes', {'error': error}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> borrarPendiente(int id) async {
    final db = await _base;
    await db.delete('pendientes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> descartarConError(int usuarioId) async {
    final db = await _base;
    await db.delete('pendientes',
        where: 'usuario_id = ? AND error IS NOT NULL', whereArgs: [usuarioId]);
  }

  // ----- Copia local del historial (consulta sin conexión) -----

  Future<void> reemplazarCache(List<Valoracion> lista) async {
    final db = await _base;
    await db.transaction((t) async {
      await t.delete('historial_cache');
      for (final v in lista) {
        await t.insert('historial_cache',
            {'id_valoracion': v.id, 'cuerpo': jsonEncode(v.toJson())});
      }
    });
  }

  Future<List<Valoracion>> leerCache() async {
    final db = await _base;
    final filas = await db.query('historial_cache');
    final lista = [
      for (final f in filas)
        Valoracion.fromJson(jsonDecode(f['cuerpo'] as String) as Map<String, dynamic>)
    ];
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  Future<void> limpiarCache() async {
    final db = await _base;
    await db.delete('historial_cache');
  }
}
