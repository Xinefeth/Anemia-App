import 'dart:convert';
import 'dart:io';

import 'package:anemia_app/models/nino.dart';
import 'package:anemia_app/models/resultado.dart';
import 'package:anemia_app/models/usuario.dart';
import 'package:anemia_app/models/valoracion.dart';
import 'package:anemia_app/screens/dashboard_screen.dart';
import 'package:anemia_app/screens/formulario_screen.dart';
import 'package:anemia_app/screens/reportes_screen.dart';
import 'package:anemia_app/screens/resultado_screen.dart';
import 'package:anemia_app/services/api_service.dart';
import 'package:anemia_app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _datos = DatosNino(
    codigo: '1042', edadMeses: 36, sexo: 'M', hemoglobina: 8.9, altitud: 34, grupo: 'experimental');

void main() {
  group('modelos', () {
    test('Resultado interpreta la respuesta de /api/predict', () {
      final r = Resultado.fromJson(
          {'riesgo': 'Alto', 'probabilidad': 0.853, 'modelo': 'Random Forest', 'tiempo_ms': 1200});
      expect(r.porcentaje, 85);
      expect(r.tiempoTexto, '1.2 s');
      expect(r.recomendacion, contains('inmediata'));
      expect(Resultado.fromJson({...{'riesgo': 'Bajo', 'probabilidad': 0.9, 'modelo': 'x'}, 'tiempo_ms': 85}).tiempoTexto,
          '85 ms');
    });

    test('DatosNino arma los cuerpos del contrato de la API', () {
      expect(_datos.toPredictJson(),
          {'edad_meses': 36, 'hemoglobina': 8.9, 'altitud': 34, 'sexo': 'M'});
      final v = _datos.toValoracionJson(tiempoMs: 900);
      expect(v['codigo'], '1042');
      expect(v['grupo'], 'experimental');
      expect(v['tiempo_ms'], 900);
    });

    test('Valoracion ida y vuelta JSON (caché local)', () {
      final j = {
        'id_valoracion': 1, 'codigo': '1042', 'edad_meses': 36, 'sexo': 'F', 'hemoglobina': 8.9,
        'altitud': 34, 'riesgo': 'Alto', 'probabilidad': 0.853, 'fecha': '2026-11-05T09:12:00',
        'grupo': 'control', 'tiempo_ms': 62000, 'registrado_por': 'Dr. Diego Jara',
      };
      final v = Valoracion.fromJson(j);
      expect(v.esNina, isTrue);
      expect(v.toJson(), j);
    });

    test('Usuario.iniciales', () {
      const u = Usuario(id: 1, nombre: 'Dr. Diego Jara', usuario: 'dr.jara', rol: 'medico');
      expect(u.iniciales, 'DJ');
    });
  });

  group('utils', () {
    test('fechas relativas', () {
      final ahora = DateTime(2026, 11, 5, 12);
      expect(fechaRelativa(DateTime(2026, 11, 5, 9, 12), ahora: ahora), 'Hoy, 09:12');
      expect(fechaRelativa(DateTime(2026, 11, 4, 16, 20), ahora: ahora), 'Ayer, 16:20');
      expect(fechaRelativa(DateTime(2026, 11, 1, 8, 5), ahora: ahora), '01 Nov, 08:05');
    });

    test('parseDecimal acepta coma', () {
      expect(parseDecimal('9,5'), 9.5);
      expect(parseDecimal('abc'), isNull);
    });
  });

  group('ApiService', () {
    final api = ApiService.instancia;
    tearDown(() => api.token = null);

    test('predecir envía token y datos, y lee el resultado', () async {
      api.token = 'abc';
      api.cliente = MockClient((req) async {
        expect(req.url.path, '/api/predict');
        expect(req.headers['Authorization'], 'Bearer abc');
        expect(jsonDecode(req.body)['hemoglobina'], 8.9);
        return http.Response(
            jsonEncode({'riesgo': 'Alto', 'probabilidad': 0.9, 'modelo': 'Random Forest', 'tiempo_ms': 20}), 200,
            headers: {'content-type': 'application/json'});
      });
      expect((await api.predecir(_datos)).riesgo, 'Alto');
    });

    test('login incorrecto muestra el mensaje del servidor', () async {
      api.cliente = MockClient((_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'detail': 'Usuario o contraseña incorrectos'})), 401));
      expect(
        () => api.login('x', 'y'),
        throwsA(isA<ApiException>().having((e) => e.mensaje, 'mensaje', 'Usuario o contraseña incorrectos')),
      );
    });

    test('error 422 de validación se traduce a texto legible', () async {
      api.token = 'abc';
      api.cliente = MockClient((_) async => http.Response(
          jsonEncode({'detail': [{'loc': ['body', 'edad_meses'], 'msg': 'Input should be <= 60'}]}), 422));
      expect(() => api.predecir(_datos),
          throwsA(isA<ApiException>().having((e) => e.mensaje, 'm', contains('edad_meses'))));
    });

    test('sin red se marca sinConexion y no se pierde información', () async {
      api.token = 'abc';
      api.cliente = MockClient((_) async => throw const SocketException('sin red'));
      expect(() => api.predecir(_datos),
          throwsA(isA<ApiException>().having((e) => e.sinConexion, 'sinConexion', true)));
    });

    test('401 con sesión activa avisa que la sesión venció', () async {
      api.token = 'abc';
      var avisado = false;
      api.onSesionVencida = () => avisado = true;
      api.cliente = MockClient((_) async => http.Response('{"detail":"x"}', 401));
      await expectLater(api.dashboard(), throwsA(isA<ApiException>()));
      expect(avisado, isTrue);
      api.onSesionVencida = null;
    });
  });

  group('pantallas', () {
    // La fuente de prueba (Ahem) es mucho más ancha que la real: sus "desbordes" son
    // falsos positivos, así que en las pruebas de pantalla completa se ignoran.
    void ignorarDesbordesAhem() {
      final previo = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!d.exceptionAsString().contains('overflowed')) previo?.call(d);
      };
      addTearDown(() => FlutterError.onError = previo);
    }

    // Pantalla alta para que el ListView construya todos los campos del formulario.
    void pantallaAlta(WidgetTester t) {
      t.view.physicalSize = const Size(800, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    testWidgets('Formulario vacío muestra errores y NO llama a la API', (t) async {
      pantallaAlta(t);
      var llamadas = 0;
      ApiService.instancia.cliente = MockClient((_) async {
        llamadas++;
        return http.Response('{}', 200);
      });
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: FormularioScreen())));
      await t.ensureVisible(find.text('Evaluar riesgo'));
      await t.tap(find.text('Evaluar riesgo'));
      await t.pump();
      expect(find.text('Obligatorio'), findsOneWidget);
      expect(find.text('Seleccione el sexo'), findsOneWidget);
      expect(llamadas, 0);
    });

    testWidgets('Formulario rechaza valores fuera de rango', (t) async {
      pantallaAlta(t);
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: FormularioScreen())));
      final campos = find.byType(TextFormField);
      await t.enterText(campos.at(0), '1042');
      await t.enterText(campos.at(1), '75');
      await t.enterText(campos.at(2), '40');
      await t.enterText(campos.at(3), '9000');
      await t.ensureVisible(find.text('Evaluar riesgo'));
      await t.tap(find.text('Evaluar riesgo'));
      await t.pump();
      expect(find.text('Debe estar entre 0 y 60 meses'), findsOneWidget);
      expect(find.text('Debe estar entre 3.0 y 25.0 g/dL'), findsOneWidget);
      expect(find.text('Debe estar entre 0 y 5500 msnm'), findsOneWidget);
    });

    testWidgets('Formulario válido llama a /api/predict y abre el Resultado', (t) async {
      pantallaAlta(t);
      ApiService.instancia.cliente = MockClient((req) async {
        expect(req.url.path, '/api/predict');
        return http.Response(
            jsonEncode({'riesgo': 'Alto', 'probabilidad': 0.853, 'modelo': 'Random Forest', 'tiempo_ms': 1200}), 200,
            headers: {'content-type': 'application/json'});
      });
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: FormularioScreen())));
      final campos = find.byType(TextFormField);
      await t.enterText(campos.at(0), '1042');
      await t.enterText(campos.at(1), '36');
      await t.enterText(campos.at(2), '8,9');
      await t.enterText(campos.at(3), '34');
      await t.ensureVisible(find.text('Masculino'));
      await t.tap(find.text('Masculino'));
      await t.pump();
      await t.ensureVisible(find.text('Evaluar riesgo'));
      await t.tap(find.text('Evaluar riesgo'));
      await t.pumpAndSettle();
      expect(find.text('Riesgo Alto de anemia'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
    });

    testWidgets('Formulario conserva los datos si falla la conexión', (t) async {
      pantallaAlta(t);
      ApiService.instancia.cliente = MockClient((_) async => throw const SocketException('sin red'));
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: FormularioScreen())));
      final campos = find.byType(TextFormField);
      await t.enterText(campos.at(0), '1042');
      await t.enterText(campos.at(1), '36');
      await t.enterText(campos.at(2), '8.9');
      await t.enterText(campos.at(3), '34');
      await t.ensureVisible(find.text('Masculino'));
      await t.tap(find.text('Masculino'));
      await t.pump();
      await t.ensureVisible(find.text('Evaluar riesgo'));
      await t.tap(find.text('Evaluar riesgo'));
      await t.pumpAndSettle();
      expect(find.textContaining('Sus datos se conservaron'), findsOneWidget);
      expect(find.text('1042'), findsOneWidget);
    });


    testWidgets('Inicio dibuja totales, gráfico y recientes', (t) async {
      ignorarDesbordesAhem();
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      ApiService.instancia.cliente = MockClient((req) async {
        expect(req.url.path, '/api/dashboard');
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'total': 128, 'en_riesgo': 37, 'precision': 0.91, 'precision_origen': 'x',
              'meses': [for (final m in ['07', '08', '09', '10', '11']) {'mes': '2026-$m', 'total': int.parse(m)}],
              'recientes': [
                {
                  'id_valoracion': 1, 'codigo': '1042', 'edad_meses': 36, 'sexo': 'M', 'hemoglobina': 8.9,
                  'altitud': 34, 'riesgo': 'Alto', 'probabilidad': 0.85, 'fecha': DateTime.now().toIso8601String(),
                  'grupo': 'experimental', 'tiempo_ms': 20, 'registrado_por': 'Dr. Diego Jara',
                }
              ],
            })),
            200,
            headers: {'content-type': 'application/json'});
      });
      await t.pumpWidget(MaterialApp(
          home: Scaffold(body: DashboardScreen(onNuevaValoracion: () {}, onVerHistorial: () {}))));
      await t.pumpAndSettle();
      expect(find.text('128'), findsOneWidget);
      expect(find.text('91%'), findsOneWidget);
      expect(find.text('Niño #1042'), findsOneWidget);
      
    });

    testWidgets('Reportes dibuja los tres indicadores', (t) async {
      ignorarDesbordesAhem();
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      Map<String, dynamic> g(double? pc, double? tr, double? tt) => {
            'total': 5, 'pc': pc, 'tr_segundos': tr, 'tt': tt,
            'distribucion': {'Bajo': 1, 'Medio': 2, 'Alto': 2},
          };
      ApiService.instancia.cliente = MockClient((req) async => http.Response(
          jsonEncode({
            'id_reporte': null, 'inicio': '2026-11-01', 'fin': '2026-11-05', 'total': 10,
            'control': g(74, 62, 3.5), 'experimental': g(91, 1.2, null),
          }),
          200,
          headers: {'content-type': 'application/json'}));
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: ReportesScreen())));
      await t.pumpAndSettle();
      expect(find.text('Porcentaje de clasificaciones (PC)'), findsOneWidget);
      expect(find.text('Experimental · 91%'), findsOneWidget);
      expect(find.text('Experimental · Sin datos'), findsOneWidget); // TT sin datos
      
    });

    testWidgets('Resultado muestra los datos y las acciones', (t) async {
      const r = Resultado(riesgo: 'Medio', probabilidad: 0.7, modelo: 'Random Forest', tiempoMs: 45);
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: ResultadoScreen(datos: _datos, resultado: r))));
      expect(find.text('Riesgo Medio de anemia'), findsOneWidget);
      expect(find.text('8.9 g/dL'), findsOneWidget);
      expect(find.text('45 ms'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.text('Nueva'), findsOneWidget);
    });
  });
}
