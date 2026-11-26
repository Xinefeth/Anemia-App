// Contrato con el backend (docs/API_CONTRATO.md): modelos, errores 422, HTTPS y validaciones.
// Los JSON de ejemplo son respuestas REALES del backend con el modelo calibrado.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:anemia_ml_app/config.dart';
import 'package:anemia_ml_app/models/modelos.dart';
import 'package:anemia_ml_app/services/api.dart';
import 'package:anemia_ml_app/widgets/validadores.dart';

const _datos = DatosNino(
    codigo: 'N-1',
    edadMeses: 12,
    sexo: 'F',
    altitud: 137,
    cred: false,
    suplementacion: false,
    grupo: 'experimental');

const _msgEdad =
    'edad_meses debe estar entre 6 y 59 meses: el modelo se entrenó con niños de 6 a 59 meses y no es válido fuera de ese rango';
const _msgAltitud =
    'altitud debe estar entre 0 y 700 msnm: el modelo solo es válido para establecimientos de Trujillo (entrenado con altitudes de 10 a 659 msnm)';

String _cuerpo422Dominio(String campo, String msg, Object input, Map<String, int> ctx) => jsonEncode({
      'detail': [
        {'type': 'fuera_de_dominio_modelo', 'loc': ['body', campo], 'msg': msg, 'input': input, 'ctx': ctx}
      ]
    });

http.Response _resp(int codigo, String cuerpo) => http.Response.bytes(utf8.encode(cuerpo), codigo,
    headers: {'content-type': 'application/json; charset=utf-8'});

Future<T> _con<T>(http.Response Function(http.Request) h, Future<T> Function() f) =>
    http.runWithClient(f, () => MockClient((r) async => h(r)));

void main() {
  group('Prediccion.fromJson (respuesta real de /api/predict)', () {
    final j = jsonDecode('''
{"riesgo":"Alto","probabilidad":0.3158,"probabilidades":{"Bajo":0.6767,"Medio":0.0075,"Alto":0.3158},
 "modelo":"Random Forest - Modelo B (sin hemoglobina)","tiempo_ms":36,
 "factores_influyentes":[{"factor":"No asiste a control CRED","peso":0.302},
   {"factor":"Edad del niño (12 meses)","peso":0.299},{"factor":"Altitud de residencia (300 msnm)","peso":0.182}]}''')
        as Map<String, dynamic>;

    test('lee riesgo, probabilidades por clase y factores', () {
      final p = Prediccion.fromJson(j);
      expect(p.riesgo, Riesgo.alto);
      expect(p.probabilidad, 0.3158);
      expect(p.probabilidades[Riesgo.bajo], 0.6767);
      expect(p.probabilidades[Riesgo.medio], 0.0075);
      expect(p.probabilidades[Riesgo.alto], 0.3158);
      expect(p.probRiesgo, 0.3158);
      expect(p.probabilidades.values.reduce((a, b) => a + b), closeTo(1.0, 2e-4));
      expect(p.factores.length, 3);
      expect(p.modelo, isNot(contains('SINTETICO')));
    });

    test('riesgo "Alto" con P(Alto)=32 % mientras P(Bajo)=68 % es un resultado válido (no se decide por la mayor)', () {
      final p = Prediccion.fromJson(j);
      expect(p.riesgo, Riesgo.alto);
      expect(p.probabilidades[Riesgo.bajo]! > p.probabilidades[Riesgo.alto]!, isTrue);
    });

    test('tolera un servidor sin "probabilidades" (usa la probabilidad de la clase)', () {
      final p = Prediccion.fromJson({...j}..remove('probabilidades'));
      expect(p.probabilidades, isEmpty);
      expect(p.probRiesgo, 0.3158);
    });
  });

  test('DatosNino.toJson envía exactamente los 7 campos del contrato y NUNCA hemoglobina', () {
    final m = _datos.toJson();
    expect(m.keys.toSet(),
        {'codigo', 'edad_meses', 'sexo', 'altitud', 'cred', 'suplementacion', 'grupo'});
    expect(m['edad_meses'], isA<int>());
    expect(m['cred'], isA<bool>());
    expect(m.containsKey('hemoglobina'), isFalse);
  });

  test('DatosNino.fromJson ignora la hemoglobina de datos antiguos', () {
    final d = DatosNino.fromJson({
      'codigo': 'X',
      'edad_meses': 30,
      'sexo': 'M',
      'altitud': 34,
      'cred': true,
      'suplementacion': false,
      'grupo': 'control',
      'hemoglobina': 11.2,
    });
    expect(d.toJson().containsKey('hemoglobina'), isFalse);
  });

  group('mensajeDeValidacion (422 reales del backend)', () {
    test('fuera_de_dominio_modelo: el msg se muestra TAL CUAL (edad 5)', () {
      final d = jsonDecode(_cuerpo422Dominio('edad_meses', _msgEdad, 5, {'min': 6, 'max': 59}))['detail'] as List;
      expect(mensajeDeValidacion(d), _msgEdad);
    });

    test('fuera_de_dominio_modelo: el msg se muestra TAL CUAL (altitud 3400)', () {
      final d = jsonDecode(_cuerpo422Dominio('altitud', _msgAltitud, 3400, {'min': 0, 'max': 700}))['detail'] as List;
      expect(mensajeDeValidacion(d), _msgAltitud);
    });

    test('campo faltante: mensaje claro en español (no el "Field required" en inglés)', () {
      final d = jsonDecode(
              '{"detail":[{"type":"missing","loc":["body","cred"],"msg":"Field required","input":{"edad_meses":36}}]}')['detail']
          as List;
      expect(mensajeDeValidacion(d), 'Falta el dato: control CRED.');
    });

    test('otros 422: no se muestra texto en inglés', () {
      final d = jsonDecode(
              '{"detail":[{"type":"literal_error","loc":["body","sexo"],"msg":"Input should be \'M\' or \'F\'","input":"X"}]}')['detail']
          as List;
      expect(mensajeDeValidacion(d), 'El dato "sexo" no es válido.');
    });

    test('varios errores se muestran todos', () {
      final d = [
        {'type': 'missing', 'loc': ['body', 'altitud']},
        {'type': 'missing', 'loc': ['body', 'suplementacion']},
      ];
      expect(mensajeDeValidacion(d), 'Falta el dato: altitud (msnm).\nFalta el dato: suplementación con hierro.');
    });
  });

  group('HttpApi: manejo de errores', () {
    HttpApi api({void Function()? alExpirar}) =>
        HttpApi(token: () => 'tok', alExpirar: alExpirar ?? () {});

    test('422 fuera de dominio -> ErrorApi con el mensaje íntegro y fueraDeDominio', () async {
      http.Request? vista;
      final e = await _con<Object?>(
        (r) {
          vista = r;
          return _resp(422, _cuerpo422Dominio('edad_meses', _msgEdad, 5, {'min': 6, 'max': 59}));
        },
        () async {
          try {
            await api().predecir(_datos);
          } catch (e) {
            return e;
          }
          return null;
        },
      );
      expect(e, isA<ErrorApi>());
      final err = e as ErrorApi;
      expect(err.codigo, 422);
      expect(err.fueraDeDominio, isTrue);
      expect(err.mensaje, _msgEdad);
      expect(vista!.url.path, '/api/predict');
      expect(vista!.headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(vista!.body).containsKey('hemoglobina'), isFalse);
    });

    test('422 por campo faltante -> ErrorApi con mensaje en español', () async {
      final e = await _con<Object?>(
        (r) => _resp(422, '{"detail":[{"type":"missing","loc":["body","cred"],"msg":"Field required","input":{}}]}'),
        () async {
          try {
            await api().predecir(_datos);
          } catch (e) {
            return e;
          }
          return null;
        },
      );
      expect((e as ErrorApi).mensaje, 'Falta el dato: control CRED.');
      expect(e.fueraDeDominio, isFalse);
    });

    test('401 -> SesionExpirada y se avisa para volver al login', () async {
      var expiro = false;
      final e = await _con<Object?>(
        (r) => _resp(401, '{"detail":"No autenticado"}'),
        () async {
          try {
            await api(alExpirar: () => expiro = true).predecir(_datos);
          } catch (e) {
            return e;
          }
          return null;
        },
      );
      expect(e, isA<SesionExpirada>());
      expect(expiro, isTrue);
    });

    test('5xx o sin red -> SinConexion (se puede reintentar)', () async {
      final e = await _con<Object?>(
        (r) => _resp(503, '{"detail":"Modelo no disponible"}'),
        () async {
          try {
            await api().predecir(_datos);
          } catch (e) {
            return e;
          }
          return null;
        },
      );
      expect(e, isA<SinConexion>());
    });

    test('guardar envía los datos + fecha (sin la predicción: el servidor recalcula)', () async {
      http.Request? vista;
      final v = await _con<Valoracion>(
        (r) {
          vista = r;
          return _resp(
              201,
              jsonEncode({
                'id': 7,
                'codigo': 'N-1',
                'edad_meses': 12,
                'sexo': 'F',
                'hemoglobina': null,
                'altitud': 137.0,
                'cred': false,
                'suplementacion': false,
                'grupo': 'experimental',
                'riesgo': 'Alto',
                'probabilidad': 0.3158,
                'fecha': '2026-11-12T10:00:00',
                'pendiente': false,
              }));
        },
        () => api().guardar(_datos, DateTime(2026, 11, 12, 10)),
      );
      final enviado = jsonDecode(vista!.body) as Map<String, dynamic>;
      expect(vista!.url.path, '/api/valoraciones');
      expect(enviado.keys.toSet(), {..._datos.toJson().keys, 'fecha'});
      expect(v.id, 7);
      expect(v.riesgo, Riesgo.alto);
      expect(v.probabilidad, 0.3158);
    });
  });

  group('HTTPS: los datos de menores no viajan por HTTP en producción', () {
    test('https siempre se acepta', () {
      expect(Config.validarUrl('https://anemia-api.onrender.com', release: true), isNotEmpty);
      expect(Config.validarUrl('https://anemia-api.onrender.com', release: false), isNotEmpty);
    });

    test('http solo en desarrollo y solo hacia la propia máquina', () {
      for (final u in ['http://localhost:8000', 'http://127.0.0.1:8000', 'http://10.0.2.2:8000']) {
        expect(Config.validarUrl(u, release: false), u);
        expect(() => Config.validarUrl(u, release: true), throwsA(isA<UrlInsegura>()), reason: 'release: $u');
      }
    });

    test('http hacia un servidor remoto se rechaza incluso en desarrollo', () {
      expect(() => Config.validarUrl('http://anemia-api.onrender.com', release: false), throwsA(isA<UrlInsegura>()));
      expect(() => Config.validarUrl('http://192.168.1.20:8000', release: false), throwsA(isA<UrlInsegura>()));
    });

    test('URL inválida o sin esquema se rechaza', () {
      expect(() => Config.validarUrl('anemia-api.onrender.com', release: false), throwsA(isA<UrlInsegura>()));
      expect(() => Config.validarUrl('', release: false), throwsA(isA<UrlInsegura>()));
    });
  });

  group('Validaciones del cliente = rangos de la API', () {
    test('edad: entero de 6 a 59', () {
      for (final ok in ['6', '7', '24', '59']) {
        expect(vEdad(ok), isNull, reason: ok);
      }
      for (final mal in ['0', '5', '60', '100', '-1']) {
        expect(vEdad(mal), contains('entre 6 y 59 meses'), reason: mal);
      }
      expect(vEdad('18.5'), contains('entero'));
      expect(vEdad(''), isNotNull);
      expect(vEdad(null), isNotNull);
    });

    test('altitud: 0 a 700 msnm (solo Trujillo)', () {
      for (final ok in ['0', '34', '659', '700', '34,5', '700.0']) {
        expect(vAltitud(ok), isNull, reason: ok);
      }
      for (final mal in ['701', '1500', '3400', '5500', '-1']) {
        final m = vAltitud(mal);
        expect(m, contains('entre 0 y 700 msnm'), reason: mal);
        expect(m, contains('Trujillo'), reason: mal);
      }
      expect(vAltitud('abc'), isNotNull);
      expect(vAltitud(''), isNotNull);
    });

    test('código anónimo', () {
      expect(vCodigo('N-100'), isNull);
      expect(vCodigo('Juan Pérez'), isNotNull); // espacios/tildes: parece un nombre
      expect(vCodigo(''), isNotNull);
    });
  });
}
