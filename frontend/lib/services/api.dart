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
  final int? codigo; // código HTTP, si lo hay (403 = sin permiso)
  final String? tipo; // type del error 422 (p. ej. "fuera_de_dominio_modelo")
  ErrorApi(this.mensaje, {this.codigo, this.tipo});

  /// El dato está fuera del dominio con el que se entrenó el modelo (edad o altitud).
  bool get fueraDeDominio => tipo == tipoFueraDeDominio;

  @override
  String toString() => mensaje;
}

const String tipoFueraDeDominio = 'fuera_de_dominio_modelo';

const _etiquetas = {
  'codigo': 'código del niño',
  'edad_meses': 'edad (meses)',
  'sexo': 'sexo',
  'altitud': 'altitud (msnm)',
  'cred': 'control CRED',
  'suplementacion': 'suplementación con hierro',
  'grupo': 'grupo',
};

String _campo(Map e) {
  final loc = e['loc'];
  final c = loc is List && loc.isNotEmpty ? loc.last.toString() : '';
  return _etiquetas[c] ?? c;
}

/// Convierte el `detail` de un 422 del backend en un texto para el usuario.
/// - type "fuera_de_dominio_modelo": se muestra el `msg` TAL CUAL (viene redactado para el usuario).
/// - campo faltante: "Falta el dato: ...". - cualquier otro: "El dato ... no es válido".
String mensajeDeValidacion(List detail) {
  final partes = <String>[];
  for (final e in detail) {
    if (e is! Map) continue;
    final tipo = e['type'];
    if (tipo == tipoFueraDeDominio && e['msg'] is String) {
      partes.add(e['msg'] as String);
    } else if (tipo == 'missing') {
      partes.add('Falta el dato: ${_campo(e)}.');
    } else {
      partes.add('El dato "${_campo(e)}" no es válido.');
    }
  }
  return partes.isEmpty ? 'Datos inválidos' : partes.join('\n');
}

/// type del primer error del 422 (para distinguir "fuera de dominio").
String? _tipoDe(List detail) {
  for (final e in detail) {
    if (e is Map && e['type'] == tipoFueraDeDominio) return tipoFueraDeDominio;
  }
  return null;
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
  /// Guarda la valoración; el servidor recalcula el riesgo (no se envía el resultado).
  Future<Valoracion> guardar(DatosNino datos, DateTime fecha);
  Future<List<Valoracion>> listar(Filtro filtro);
  Future<Valoracion> detalle(int id);
  Future<void> eliminar(int id);
  Future<Dashboard> dashboard();
  Future<Reporte> reporte(DateTime desde, DateTime hasta);

  // Niños (RF07-RF11)
  Future<List<Nino>> listarNinos(String busqueda);
  Future<Nino> crearNino(DatosNino datos);
  Future<Nino> actualizarNino(int id, DatosNino datos);
  Future<void> eliminarNino(int id);

  // Usuarios (RF03-RF06)
  Future<List<UsuarioAdmin>> listarUsuarios();
  Future<UsuarioAdmin> crearUsuario(
      String nombre, String rol, String usuario, String clave);
  Future<UsuarioAdmin> actualizarUsuario(int id, String nombre, String rol,
      {String? clave});
  Future<void> eliminarUsuario(int id); // inhabilita
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

  Uri _u(String ruta, [Map<String, String>? q]) {
    try {
      return Uri.parse('${Config.apiUrl}$ruta').replace(queryParameters: q);
    } on UrlInsegura catch (e) {
      throw ErrorApi(e.mensaje); // nunca se envían datos por HTTP en producción
    }
  }

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
    var msg = r.statusCode == 403 ? 'No tienes permiso para esta acción.' : 'Error ${r.statusCode}';
    String? tipo;
    if (cuerpo is Map && cuerpo['detail'] != null) {
      final d = cuerpo['detail'];
      if (d is String) {
        msg = d;
      } else if (d is List) {
        msg = mensajeDeValidacion(d);
        tipo = _tipoDe(d);
      } else {
        msg = 'Datos inválidos';
      }
    }
    throw ErrorApi(msg, codigo: r.statusCode, tipo: tipo);
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
  Future<Valoracion> guardar(DatosNino d, DateTime fecha) async {
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

  // ---- Niños ----
  @override
  Future<List<Nino>> listarNinos(String q) async {
    final j = await _enviar(() => http.get(
        _u('/api/ninos', {if (q.isNotEmpty) 'q': q}),
        headers: _cab));
    return (j as List)
        .map((e) => Nino.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Nino> crearNino(DatosNino d) async {
    final j = await _enviar(() =>
        http.post(_u('/api/ninos'), headers: _cab, body: jsonEncode(d.toJson())));
    return Nino.fromJson(j as Map<String, dynamic>);
  }

  @override
  Future<Nino> actualizarNino(int id, DatosNino d) async {
    final j = await _enviar(() => http.put(_u('/api/ninos/$id'),
        headers: _cab, body: jsonEncode(d.toJson())));
    return Nino.fromJson(j as Map<String, dynamic>);
  }

  @override
  Future<void> eliminarNino(int id) async {
    await _enviar(() => http.delete(_u('/api/ninos/$id'), headers: _cab));
  }

  // ---- Usuarios ----
  @override
  Future<List<UsuarioAdmin>> listarUsuarios() async {
    final j = await _enviar(() => http.get(_u('/api/usuarios'), headers: _cab));
    return (j as List)
        .map((e) => UsuarioAdmin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<UsuarioAdmin> crearUsuario(
      String nombre, String rol, String usuario, String clave) async {
    final j = await _enviar(() => http.post(_u('/api/usuarios'),
        headers: _cab,
        body: jsonEncode({
          'nombre': nombre,
          'rol': rol,
          'usuario': usuario,
          'contrasena': clave,
        })));
    return UsuarioAdmin.fromJson(j as Map<String, dynamic>);
  }

  @override
  Future<UsuarioAdmin> actualizarUsuario(int id, String nombre, String rol,
      {String? clave}) async {
    final j = await _enviar(() => http.put(_u('/api/usuarios/$id'),
        headers: _cab,
        body: jsonEncode({
          'nombre': nombre,
          'rol': rol,
          if (clave != null && clave.isNotEmpty) 'contrasena': clave,
        })));
    return UsuarioAdmin.fromJson(j as Map<String, dynamic>);
  }

  @override
  Future<void> eliminarUsuario(int id) async {
    await _enviar(() => http.delete(_u('/api/usuarios/$id'), headers: _cab));
  }
}
