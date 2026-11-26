// Cola local de valoraciones pendientes (RNF09): SQLite real (sqflite_common_ffi) y reintentos.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anemia_ml_app/models/modelos.dart';
import 'package:anemia_ml_app/services/almacen_local.dart';
import 'package:anemia_ml_app/services/api.dart';
import 'package:anemia_ml_app/services/app_state.dart';
import 'package:anemia_ml_app/services/mock_api.dart';

const _d = DatosNino(
    codigo: 'N-1',
    edadMeses: 12,
    sexo: 'F',
    altitud: 137,
    cred: false,
    suplementacion: true,
    grupo: 'control');

PendienteEnvio _pen({Riesgo? r, String? codigo}) => PendienteEnvio(
    datos: codigo == null
        ? _d
        : DatosNino(
            codigo: codigo,
            edadMeses: 12,
            sexo: 'F',
            altitud: 137,
            cred: false,
            suplementacion: true,
            grupo: 'control'),
    fecha: DateTime(2026, 11, 12, 9, 30),
    riesgo: r,
    probabilidad: r == null ? null : 0.3158);

/// Contrato común: lo cumplen las tres implementaciones.
void _contrato(String nombre, Future<AlmacenPendientes> Function() crear) {
  group('$nombre cumple el contrato del almacén', () {
    test('agregar, listar en orden y conservar todos los campos', () async {
      final a = await crear();
      final x = await a.agregar(_pen(codigo: 'A'));
      final y = await a.agregar(_pen(r: Riesgo.alto, codigo: 'B'));
      expect(x.idLocal, isNotNull);
      expect(y.idLocal, isNot(x.idLocal));
      final l = await a.todos();
      expect(l.map((e) => e.datos.codigo), ['A', 'B']);
      expect(l[0].riesgo, isNull); // evaluada sin conexión: sin predicción
      expect(l[1].riesgo, Riesgo.alto);
      expect(l[1].probabilidad, 0.3158);
      expect(l[1].datos.toJson(), _pen(codigo: 'B').datos.toJson()); // los 7 campos intactos
      expect(l[1].fecha, DateTime(2026, 11, 12, 9, 30));
      expect(l[1].error, isNull);
      await a.cerrar();
    });

    test('marcar y limpiar el error de un pendiente rechazado (no se pierde)', () async {
      final a = await crear();
      final x = await a.agregar(_pen(codigo: 'A'));
      await a.marcarError(x.idLocal!, 'edad_meses debe estar entre 6 y 59 meses');
      expect((await a.todos()).single.error, contains('entre 6 y 59'));
      await a.marcarError(x.idLocal!, null);
      expect((await a.todos()).single.error, isNull);
      await a.cerrar();
    });

    test('eliminar solo quita el indicado', () async {
      final a = await crear();
      final x = await a.agregar(_pen(codigo: 'A'));
      await a.agregar(_pen(codigo: 'B'));
      await a.eliminar(x.idLocal!);
      expect((await a.todos()).map((e) => e.datos.codigo), ['B']);
      await a.cerrar();
    });
  });
}

void main() {
  sqfliteFfiInit();
  SharedPreferences.setMockInitialValues({});

  _contrato('MemoriaAlmacen', () async => MemoriaAlmacen());
  _contrato('PrefsAlmacen (web)', () async {
    SharedPreferences.setMockInitialValues({});
    return PrefsAlmacen(await SharedPreferences.getInstance());
  });
  _contrato('SqliteAlmacen (SQLite real)', () => SqliteAlmacen.abrirEn(databaseFactoryFfi, inMemoryDatabasePath));

  group('SQLite: los datos sobreviven al cierre de la app', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('anemia_sqlite_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('se guardan en un archivo y siguen ahí al reabrir la base', () async {
      final ruta = p.join(dir.path, SqliteAlmacen.nombreArchivo);
      final a = await SqliteAlmacen.abrirEn(databaseFactoryFfi, ruta);
      await a.agregar(_pen(r: Riesgo.medio, codigo: 'PERSISTE'));
      await a.cerrar();
      expect(File(ruta).existsSync(), isTrue);

      final b = await SqliteAlmacen.abrirEn(databaseFactoryFfi, ruta); // "la app se reinició"
      final l = await b.todos();
      expect(l.single.datos.codigo, 'PERSISTE');
      expect(l.single.riesgo, Riesgo.medio);
      expect(b.tipo, 'sqlite');
      await b.cerrar();
    });
  });

  group('AppState: cola, reintentos y migración', () {
    Future<(AppState, MockApi, AlmacenPendientes)> estado({Duration? cada}) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockApi();
      final alm = await SqliteAlmacen.abrirEn(databaseFactoryFfi, inMemoryDatabasePath);
      final e = AppState(apiPrueba: api, almacen: alm, reintentoCada: cada);
      await e.iniciar();
      await e.login('dra', 'demo');
      return (e, api, alm);
    }

    test('sin conexión: se guarda en SQLite, se reintenta solo y se envía al volver la red', () async {
      final (e, api, alm) = await estado(cada: const Duration(milliseconds: 80));
      api.caido = true;
      await e.guardarSinConexion(_d);
      expect((await alm.todos()).length, 1); // está en SQLite, no solo en memoria
      expect(e.porEnviar, 1);

      await Future<void>.delayed(const Duration(milliseconds: 250)); // reintentos fallidos: sigue ahí
      expect((await alm.todos()).length, 1);

      api.caido = false;
      await Future<void>.delayed(const Duration(milliseconds: 400)); // el siguiente reintento lo envía
      expect(e.pendientes, isEmpty);
      expect(await alm.todos(), isEmpty);
      expect((await api.listar(const Filtro())).first.datos.codigo, 'N-1');
      e.dispose();
    });

    test('guardarValoracion sin red conserva también la predicción obtenida', () async {
      final (e, api, alm) = await estado();
      final pr = await api.predecir(_d);
      api.caido = true;
      expect(await e.guardarValoracion(_d, pr), isFalse);
      final g = (await alm.todos()).single;
      expect(g.riesgo, pr.riesgo);
      expect(g.probabilidad, pr.probRiesgo);
      e.dispose();
    });

    test('un 422 al sincronizar NO descarta el dato y no bloquea a los demás', () async {
      final (e, api, alm) = await estado();
      await e.guardarSinConexion(_pen(codigo: 'MALO').datos);
      await e.guardarSinConexion(_pen(codigo: 'BUENO').datos);
      api.fallaAlGuardar = ErrorApi('altitud fuera de rango', codigo: 422, tipo: tipoFueraDeDominio);
      await e.sincronizar();
      expect((await alm.todos()).length, 2); // ninguno se perdió
      expect((await alm.todos()).every((x) => x.error != null), isTrue);
      expect(e.rechazados, 2);
      e.dispose();
    });

    test('migra la cola antigua de shared_preferences sin perder nada', () async {
      SharedPreferences.setMockInitialValues({
        'pendientes':
            '[{"id":null,"codigo":"VIEJA","edad_meses":18,"sexo":"M","hemoglobina":10.1,"altitud":34,"cred":true,"suplementacion":false,"grupo":"control","riesgo":"Medio","probabilidad":0.7,"fecha":"2026-11-01T08:00:00","pendiente":true}]'
      });
      final alm = MemoriaAlmacen();
      final e = AppState(apiPrueba: MockApi(), almacen: alm, reintentoCada: null);
      await e.iniciar();
      final l = await alm.todos();
      expect(l.single.datos.codigo, 'VIEJA');
      expect(l.single.riesgo, Riesgo.medio);
      expect(l.single.datos.toJson().containsKey('hemoglobina'), isFalse);
      expect((await SharedPreferences.getInstance()).getString('pendientes'), isNull);
      e.dispose();
    });
  });
}
