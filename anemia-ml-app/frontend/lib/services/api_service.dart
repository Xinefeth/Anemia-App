import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/nino.dart';
import '../models/resultado.dart';
import '../models/resumen.dart';
import '../models/usuario.dart';
import '../models/valoracion.dart';

/// Error de la API con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  final String mensaje;
  final int? status;

  /// true si no hubo respuesta (sin internet, servidor caído, tiempo agotado).
  final bool sinConexion;

  const ApiException(this.mensaje, {this.status, this.sinConexion = false});

  @override
  String toString() => mensaje;
}

/// Cliente HTTP del backend FastAPI.
///
/// La URL se define al compilar:  flutter run --dart-define=API_URL=https://mi-servidor
/// En el emulador Android, 10.0.2.2 apunta al localhost de la computadora.
class ApiService {
  ApiService._();
  static final instancia = ApiService._();

  static const baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');
  static const _timeout = Duration(seconds: 15);

  http.Client cliente = http.Client();
  String? token;

  /// Se invoca cuando el servidor rechaza el token (sesión vencida).
  void Function()? onSesionVencida;

  Future<dynamic> _enviar(
    String metodo,
    String ruta, {
    Map<String, String>? query,
    Object? cuerpo,
    bool autenticado = true,
  }) async {
    final uri = Uri.parse(baseUrl).replace(path: ruta, queryParameters: query);
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (autenticado && token != null) 'Authorization': 'Bearer $token',
    };
    final http.Response r;
    try {
      final req = http.Request(metodo, uri)..headers.addAll(headers);
      if (cuerpo != null) req.body = jsonEncode(cuerpo);
      r = await http.Response.fromStream(await cliente.send(req).timeout(_timeout));
    } on TimeoutException {
      throw const ApiException('El servidor tardó demasiado en responder', sinConexion: true);
    } on SocketException {
      throw const ApiException('No hay conexión con el servidor', sinConexion: true);
    } on http.ClientException {
      throw const ApiException('No hay conexión con el servidor', sinConexion: true);
    }

    dynamic datos;
    try {
      datos = r.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      datos = null;
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return datos;

    if (r.statusCode == 401 && autenticado) {
      onSesionVencida?.call();
      throw const ApiException('Su sesión venció. Inicie sesión nuevamente.', status: 401);
    }
    throw ApiException(_mensajeDeError(r.statusCode, datos), status: r.statusCode);
  }

  /// Traduce el cuerpo de error de FastAPI ("detail") a un texto legible.
  static String _mensajeDeError(int status, dynamic datos) {
    if (status >= 500) return 'Error del servidor ($status). Intente más tarde.';
    final d = datos is Map ? datos['detail'] : null;
    if (d is String) return d;
    if (d is List && d.isNotEmpty) {
      final e = d.first;
      if (e is Map) {
        final campo = (e['loc'] is List && (e['loc'] as List).isNotEmpty)
            ? (e['loc'] as List).last.toString()
            : '';
        return campo.isEmpty ? '${e['msg']}' : '$campo: ${e['msg']}';
      }
    }
    return 'No se pudo completar la operación ($status)';
  }

  // ---------- Endpoints ----------

  /// Devuelve (token, usuario).
  Future<(String, Usuario)> login(String usuario, String contrasena) async {
    final d = await _enviar('POST', '/api/auth/login',
        cuerpo: {'usuario': usuario, 'contrasena': contrasena}, autenticado: false);
    return (d['access_token'] as String, Usuario.fromJson(d['usuario'] as Map<String, dynamic>));
  }

  Future<Usuario> me() async =>
      Usuario.fromJson(await _enviar('GET', '/api/auth/me') as Map<String, dynamic>);

  Future<Resultado> predecir(DatosNino datos) async => Resultado.fromJson(
      await _enviar('POST', '/api/predict', cuerpo: datos.toPredictJson()) as Map<String, dynamic>);

  /// Guarda una valoración. [cuerpo] es el JSON de [DatosNino.toValoracionJson].
  Future<Valoracion> guardarValoracion(Map<String, dynamic> cuerpo) async => Valoracion.fromJson(
      await _enviar('POST', '/api/valoracion', cuerpo: cuerpo) as Map<String, dynamic>);

  Future<List<Valoracion>> historial({String? nivel, String? busqueda}) async {
    final d = await _enviar('GET', '/api/historial', query: {
      'limit': '200',
      if (nivel != null) 'nivel': nivel,
      if (busqueda != null && busqueda.trim().isNotEmpty) 'q': busqueda.trim(),
    });
    return [for (final v in d as List) Valoracion.fromJson(v as Map<String, dynamic>)];
  }

  Future<Resumen> dashboard() async =>
      Resumen.fromJson(await _enviar('GET', '/api/dashboard') as Map<String, dynamic>);

  static String _fecha(DateTime f) => f.toIso8601String().substring(0, 10);

  Future<Reporte> reporte(DateTime inicio, DateTime fin) async => Reporte.fromJson(await _enviar(
          'GET', '/api/reporte',
          query: {'inicio': _fecha(inicio), 'fin': _fecha(fin)}) as Map<String, dynamic>);

  /// Calcula el reporte y además lo registra en el servidor (para exportar).
  Future<Reporte> generarReporte(DateTime inicio, DateTime fin) async => Reporte.fromJson(
      await _enviar('POST', '/api/reporte', query: {'inicio': _fecha(inicio), 'fin': _fecha(fin)})
          as Map<String, dynamic>);
}
