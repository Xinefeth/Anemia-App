// Prueba REAL contra el backend levantado (uvicorn). Se omite si no se indica la URL:
//   flutter test test/integracion_backend_test.dart --dart-define=API_URL=http://127.0.0.1:8766
// Usa el MISMO cliente (HttpApi) y los mismos modelos que la app, no una copia.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:anemia_ml_app/config.dart';
import 'package:anemia_ml_app/models/modelos.dart';
import 'package:anemia_ml_app/services/api.dart';

const _url = String.fromEnvironment('API_URL');

DatosNino _nino({String codigo = 'FE-REAL-1', int edad = 12, double altitud = 137, bool cred = false, bool supl = false}) =>
    DatosNino(
        codigo: codigo,
        edadMeses: edad,
        sexo: 'F',
        altitud: altitud,
        cred: cred,
        suplementacion: supl,
        grupo: 'experimental');

void main() {
  HttpOverrides.global = null; // permite red real dentro de flutter test
  final sinUrl = _url.isEmpty ? 'indica --dart-define=API_URL=http://127.0.0.1:8766' : null;
  late HttpApi api;
  var token = '';

  setUpAll(() async {
    if (_url.isEmpty) return; // sin backend: las pruebas se omiten
    api = HttpApi(token: () => token, alExpirar: () {});
    final r = await api.login('demo', 'demo');
    token = r.token;
    print('LOGIN OK -> usuario=${r.usuario.nombre} rol=${r.usuario.rol}  (API: ${Config.apiUrl})');
  });

  test('1) CASO VÁLIDO: predicción con probabilidades por clase', () async {
    final p = await api.predecir(_nino());
    print('  entrada : ${jsonEncode(_nino().toJson())}');
    print('  respuesta parseada: riesgo=${p.riesgo.texto} P(clase)=${p.probRiesgo} '
        'probabilidades=${p.probabilidades.map((k, v) => MapEntry(k.texto, v))} modelo="${p.modelo}" tiempo=${p.tiempoMs} ms');
    print('  factores: ${p.factores.map((f) => '${f.factor}=${f.peso}').join(' | ')}');
    expect(Riesgo.values, contains(p.riesgo));
    expect(p.probabilidades.keys.toSet(), {Riesgo.bajo, Riesgo.medio, Riesgo.alto});
    expect(p.probabilidades.values.reduce((a, b) => a + b), closeTo(1.0, 2e-4));
    expect(p.probRiesgo, p.probabilidad);
    expect(p.modelo, isNot(contains('SINTETICO')));
    expect(p.factores, isNotEmpty);
  }, skip: sinUrl);

  test('2) INVÁLIDO: edad 5 meses -> 422 fuera_de_dominio_modelo', () async {
    final e = await api.predecir(_nino(edad: 5)).then<Object?>((_) => null, onError: (e) => e);
    print('  ErrorApi(codigo=${(e as ErrorApi).codigo}, tipo=${e.tipo}) mensaje mostrado al usuario:\n    "${e.mensaje}"');
    expect(e, isA<ErrorApi>());
    expect(e.codigo, 422);
    expect(e.fueraDeDominio, isTrue);
    expect(e.mensaje, contains('entre 6 y 59 meses'));
  }, skip: sinUrl);

  test('3) INVÁLIDO: altitud 3400 msnm -> 422 fuera_de_dominio_modelo', () async {
    final e = await api.predecir(_nino(altitud: 3400)).then<Object?>((_) => null, onError: (e) => e);
    print('  ErrorApi(codigo=${(e as ErrorApi).codigo}, tipo=${e.tipo}) mensaje mostrado al usuario:\n    "${e.mensaje}"');
    expect(e.codigo, 422);
    expect(e.fueraDeDominio, isTrue);
    expect(e.mensaje, contains('entre 0 y 700 msnm'));
    expect(e.mensaje, contains('Trujillo'));
  }, skip: sinUrl);

  test('4) INVÁLIDO: campo faltante (sin "cred") -> 422 "missing"', () async {
    // DatosNino no permite omitir campos (es obligatorio por tipo), así que se envía el JSON a mano.
    final cuerpo = _nino().toJson()..remove('cred');
    final r = await http.post(Uri.parse('${Config.apiUrl}/api/predict'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode(cuerpo));
    final detail = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['detail'] as List;
    print('  HTTP ${r.statusCode}  cuerpo crudo: ${utf8.decode(r.bodyBytes)}');
    print('  mensaje mostrado al usuario: "${mensajeDeValidacion(detail)}"');
    expect(r.statusCode, 422);
    expect(detail.first['type'], 'missing');
    expect(mensajeDeValidacion(detail), 'Falta el dato: control CRED.');
  }, skip: sinUrl);

  test('5) GUARDAR: valoración -> servidor recalcula riesgo; luego listar y eliminar', () async {
    final v = await api.guardar(_nino(codigo: 'FE-REAL-2', cred: true, supl: true), DateTime.now());
    print('  guardada id=${v.id} codigo=${v.datos.codigo} riesgo=${v.riesgo.texto} probabilidad=${v.probabilidad}');
    expect(v.id, isNotNull);
    final lista = await api.listar(const Filtro(busqueda: 'FE-REAL-2'));
    expect(lista.map((x) => x.id), contains(v.id));
    await api.eliminar(v.id!);
    expect((await api.listar(const Filtro(busqueda: 'FE-REAL-2'))), isEmpty);
    print('  listar/eliminar OK');
  }, skip: sinUrl);

  test('6) GUARDAR fuera de dominio -> 422 también al sincronizar', () async {
    final e = await api.guardar(_nino(codigo: 'FE-REAL-3', edad: 4), DateTime.now()).then<Object?>((_) => null, onError: (e) => e);
    print('  guardar con edad 4 -> ${(e as ErrorApi).codigo} "${e.mensaje}"');
    expect(e.fueraDeDominio, isTrue);
  }, skip: sinUrl);
}
