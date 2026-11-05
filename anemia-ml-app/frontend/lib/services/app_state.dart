// Estado global: sesión, API, caché local y cola de valoraciones pendientes.
// Cubre RNF09: ante pérdida de conexión no se pierden datos.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/modelos.dart';
import 'api.dart';
import 'mock_api.dart';

class AppState extends ChangeNotifier {
  late final Api api;
  SharedPreferences? _prefs;
  String _token = '';
  Usuario? usuario;
  bool listo = false;
  bool sincronizando = false;
  /// Se incrementa cuando cambian los datos del servidor; las pantallas recargan.
  int version = 0;
  List<Valoracion> _pendientes = [];

  AppState({Api? apiPrueba}) {
    api = apiPrueba ??
        (Config.mock
            ? MockApi()
            : HttpApi(token: () => _token, alExpirar: _cerrarLocal));
  }

  void invalidar() {
    version++;
    notifyListeners();
  }

  bool get autenticado => _token.isNotEmpty && usuario != null;
  List<Valoracion> get pendientes => List.unmodifiable(_pendientes);

  Future<void> iniciar() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null; // la app funciona sin almacenamiento local
    }
    _token = _prefs?.getString('token') ?? '';
    final u = _prefs?.getString('usuario');
    if (u != null) usuario = Usuario.fromJson(jsonDecode(u));
    final p = _prefs?.getString('pendientes');
    if (p != null) {
      _pendientes = (jsonDecode(p) as List)
          .map((e) => Valoracion.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    listo = true;
    notifyListeners();
    if (autenticado) sincronizar();
  }

  // ---- Sesión (RF01, RF02) ----
  Future<void> login(String user, String clave) async {
    final r = await api.login(user, clave);
    _token = r.token;
    usuario = r.usuario;
    await _prefs?.setString('token', _token);
    await _prefs?.setString('usuario', jsonEncode(usuario!.toJson()));
    notifyListeners();
    sincronizar();
  }

  void _cerrarLocal() {
    _token = '';
    usuario = null;
    _prefs?.remove('token');
    _prefs?.remove('usuario');
    notifyListeners();
  }

  Future<void> logout() async {
    _cerrarLocal();
    // Los datos en caché del historial se borran al cerrar sesión (RNF06).
    await _prefs?.remove('cache_historial');
    await _prefs?.remove('cache_dashboard');
  }

  // ---- Cola de pendientes ----
  Future<void> _guardarPendientes() => _prefs == null
      ? Future.value()
      : _prefs!.setString(
          'pendientes', jsonEncode(_pendientes.map((v) => v.toJson()).toList()));

  /// Guarda en el servidor; si no hay red, deja la valoración en el teléfono
  /// y devuelve false. Se enviará sola al volver la conexión.
  Future<bool> guardarValoracion(DatosNino d, Prediccion p) async {
    final fecha = DateTime.now();
    try {
      await api.guardar(d, p, fecha);
      invalidar();
      return true;
    } on SinConexion {
      _pendientes.add(Valoracion(
          datos: d,
          riesgo: p.riesgo,
          probabilidad: p.probabilidad,
          fecha: fecha,
          pendiente: true));
      await _guardarPendientes();
      notifyListeners();
      return false;
    }
  }

  Future<void> sincronizar() async {
    if (sincronizando || _pendientes.isEmpty || !autenticado) return;
    sincronizando = true;
    notifyListeners();
    try {
      while (_pendientes.isNotEmpty) {
        final v = _pendientes.first;
        try {
          await api.guardar(
              v.datos,
              Prediccion(riesgo: v.riesgo, probabilidad: v.probabilidad, tiempoMs: 0),
              v.fecha);
        } on ErrorApi {
          // El servidor rechazó los datos: se descarta para no bloquear la cola.
        }
        _pendientes.removeAt(0);
        await _guardarPendientes();
      }
    } on SinConexion {
      // seguimos pendientes; se reintenta luego
    } on SesionExpirada {
      // al volver a iniciar sesión se reintenta
    } finally {
      sincronizando = false;
      version++;
      notifyListeners();
    }
  }

  // ---- Caché de lectura (historial sin conexión) ----
  Future<void> cachearHistorial(List<Valoracion> l) async =>
      _prefs?.setString('cache_historial', jsonEncode(l.map((v) => v.toJson()).toList()));

  List<Valoracion> historialEnCache() {
    final s = _prefs?.getString('cache_historial');
    if (s == null) return [];
    return (jsonDecode(s) as List)
        .map((e) => Valoracion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> cachearDashboard(Dashboard d) async =>
      _prefs?.setString('cache_dashboard', jsonEncode(d.toJson()));

  Dashboard? dashboardEnCache() {
    final s = _prefs?.getString('cache_dashboard');
    return s == null ? null : Dashboard.fromJson(jsonDecode(s));
  }

  // ---- Borrador del formulario (RNF09) ----
  Future<void> guardarBorrador(Map<String, String> campos) async =>
      _prefs?.setString('borrador', jsonEncode(campos));

  Map<String, String> leerBorrador() {
    final s = _prefs?.getString('borrador');
    if (s == null) return {};
    return (jsonDecode(s) as Map).cast<String, String>();
  }

  Future<void> borrarBorrador() async => _prefs?.remove('borrador');
}
