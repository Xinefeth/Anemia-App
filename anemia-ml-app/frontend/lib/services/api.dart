// Contrato con el backend y cliente HTTP.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/modelos.dart';

/// Sin conexión o servidor inalcanzable (se puede reintentar).
class SinConexion implements Exception {
  @override
  String toString() => 'Sin conexión con el servidor';
}

/// Sesión vencida o inválida: hay que volver a iniciar sesión.
class SesionExpirada implements Exception {
  @override
  String toString() => 'La sesión expiró';
}

/// Error de negocio devuelto por el servidor (credenciales, validación...).
class ErrorApi implements Exception {
  final String mensaje;
  ErrorApi(this.mensaje);
  @override
  String toString() => mensaje;
}

class Filtro {
  final Riesgo? riesgo;
  final String busqueda; // código del niño o fecha (aaaa-mm-dd)
  const Filtro({this.riesgo, this.busqueda = ''});
}

abstract class Api {
  /// Devuelve token y usuario.
  Future<({String token, Usuario usuario})> login(String usuario, String clave);
  Future<Prediccion> predecir(DatosNino datos);
  Future<Valoracion> guardar(DatosNino datos, Prediccion p, DateTime fecha);
  Future<List<Valoracion>> listar(Filtro filtro);
  Future<Valoracion> detalle(int id);
  Future<void> eliminar(int id);
  Future<Dashboard> dashboard();
  Future<Reporte> reporte(DateTime desde, DateTime hasta);
}

/// Cliente real contra la API FastAPI. Todas las rutas, salvo /login,
/// envían el token en la cabecera Authorization (RNF07).
class HttpApi implements Api {
  final String Function() token;
  final void Function() alExpirar;
  HttpApi({required this.token, required this.alExpirar});

  Map<String, String> get _cab => {
        'Content-Type': 'application/json',
        if (token().isNotEmpty) 'Authorization': 'Bearer ${token()}',
      };

  Uri _u(String ruta, [Map<String, String>? q]) =>
      Uri.parse('${Config.apiUrl}$ruta').replace(queryParameters: q);

  Future<dynamic> _enviar(Future<http.Response> Function() f) async {
    final http.Response r;
    try {
      r = await f().timeout(Config.timeout);
    } on SocketException {
      throw SinConexion();
    } on TimeoutException {
      throw SinConexion();
    } on http.ClientException {
      throw SinConexion();
    }
    if (r.statusCode == 401) {
      alExpirar();
      throw SesionExpirada();
    }
    final cuerpo = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 200 && r.statusCode < 300) return cuerpo;
    if (r.statusCode >= 500) throw SinConexion();
    var msg = 'Error ${r.statusCode}';
    if (cuerpo is Map && cuerpo['detail'] != null) {
      final d = cuerpo['detail'];
      msg = d is String ? d : 'Datos inválidos';
    }
    throw ErrorApi(msg);
  }

  @override
  Future<({String token, Usuario usuario})> login(
      String usuario, String clave) async {
    final j = await _enviar(() => http.post(_u('/api/login'),
        headers: _cab,
        body: jsonEncode({'usuario': usuario, 'contrasena': clave})));
    return (
      token: j['token'] as String,
      usuario: Usuario.fromJson(j['usuario'] as Map<String, dynamic>)
    );
  }

  @override
  Future<Prediccion> predecir(DatosNino d) async {
    final sw = Stopwatch()..start();
    final j = await _enviar(() =>
        http.post(_u('/api/predict'), headers: _cab, body: jsonEncode(d.toJson())));
    return Prediccion.fromJson(j as Map<String, dynamic>,
        tiempoMs: sw.elapsedMilliseconds);
  }

  // El servidor recalcula el riesgo al guardar; el cliente solo envía datos.
  @override
  Future<Valoracion> guardar(DatosNino d, Prediccion p, DateTime fecha) async {
    final j = await _enviar(() => http.post(_u('/api/valoraciones'),
        headers: _cab,
        body: jsonEncode({...d.toJson(), 'fecha': fecha.toIso8601String()})));
    return Valoracion.fromJson(j as Map<String, dynamic>);
  }

  @override
  Future<List<Valoracion>> listar(Filtro f) async {
    final j = await _enviar(() => http.get(
        _u('/api/valoraciones', {
          if (f.riesgo != null) 'riesgo': f.riesgo!.texto,
          if (f.busqueda.isNotEmpty) 'q': f.busqueda,
        }),
        headers: _cab));
    return (j as List)
        .map((e) => Valoracion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Valoracion> detalle(int id) async {
    final j = await _enviar(
        () => http.get(_u('/api/valoraciones/$id'), headers: _cab));
    return Valoracion.fromJson(j as Map<String, dynamic>);
  }

  @override
  Future<void> eliminar(int id) async {
    await _enviar(
        () => http.delete(_u('/api/valoraciones/$id'), headers: _cab));
  }

  @override
  Future<Dashboard> dashboard() async {
    final j =
        await _enviar(() => http.get(_u('/api/dashboard'), headers: _cab));
    return Dashboard.fromJson(j as Map<String, dynamic>);
  }

  @override
  Future<Reporte> reporte(DateTime desde, DateTime hasta) async {
    String f(DateTime d) => d.toIso8601String().substring(0, 10);
    final j = await _enviar(() => http.get(
        _u('/api/reporte', {'desde': f(desde), 'hasta': f(hasta)}),
        headers: _cab));
    return Reporte.fromJson(j as Map<String, dynamic>);
  }
}
