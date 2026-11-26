// Estado global: sesión, API, caché local y cola de valoraciones pendientes.
// Cubre RNF09: ante pérdida de conexión no se pierden datos (cola en SQLite + reintentos).
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/modelos.dart';
import 'almacen_local.dart';
import 'api.dart';
import 'mock_api.dart';

class AppState extends ChangeNotifier {
  late final Api api;
  SharedPreferences? _prefs;
  AlmacenPendientes? _almacen;
  final Duration? _reintentoCada;
  Timer? _reintento;
  String _token = '';
  Usuario? usuario;
  bool listo = false;
  bool sincronizando = false;
  bool _cerrado = false;
  /// Se incrementa cuando cambian los datos del servidor; las pantallas recargan.
  int version = 0;
  List<PendienteEnvio> _pendientes = [];

  /// [reintentoCada]: cada cuánto reintenta enviar los pendientes mientras haya (null = no
  /// programa reintentos; lo usan las pruebas). [almacen]: dónde se guardan los pendientes.
  AppState({
    Api? apiPrueba,
    AlmacenPendientes? almacen,
    Duration? reintentoCada = const Duration(seconds: 30),
  })  : _almacen = almacen,
        _reintentoCada = reintentoCada {
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
  List<PendienteEnvio> get pendientes => List.unmodifiable(_pendientes);

  /// Pendientes que se enviarán solos (los rechazados por el servidor no cuentan).
  int get porEnviar => _pendientes.where((p) => p.error == null).length;
  int get rechazados => _pendientes.where((p) => p.error != null).length;

  Future<void> iniciar() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null; // la app funciona sin almacenamiento local
    }
    _token = _prefs?.getString('token') ?? '';
    final u = _prefs?.getString('usuario');
    if (u != null) usuario = Usuario.fromJson(jsonDecode(u));
    _almacen ??= await crearAlmacenPorDefecto(_prefs);
    await _migrarColaAntigua();
    _pendientes = await _almacen!.todos();
    listo = true;
    notifyListeners();
    if (autenticado) sincronizar();
  }

  // Versión anterior de la app guardaba la cola en shared_preferences ('pendientes'):
  // se pasa a la cola nueva para no perder valoraciones ya guardadas.
  Future<void> _migrarColaAntigua() async {
    final viejo = _prefs?.getString('pendientes');
    if (viejo == null) return;
    try {
      for (final e in (jsonDecode(viejo) as List)) {
        final v = Valoracion.fromJson(e as Map<String, dynamic>);
        await _almacen!.agregar(PendienteEnvio(
            datos: v.datos, fecha: v.fecha, riesgo: v.riesgo, probabilidad: v.probabilidad));
      }
      await _prefs!.remove('pendientes');
    } catch (_) {
      // formato inesperado: se deja la clave antigua intacta (no se borra nada)
    }
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
    // Los pendientes de envío NO se borran: aún no están en el servidor.
    await _prefs?.remove('cache_historial');
    await _prefs?.remove('cache_dashboard');
  }

  // ---- Cola de pendientes ----
  Future<void> _encolar(PendienteEnvio p) async {
    _pendientes.add(await _almacen!.agregar(p));
    notifyListeners();
    _programarReintento();
  }

  /// Guarda en el servidor; si no hay red, deja la valoración en el teléfono (SQLite)
  /// y devuelve false. Se enviará sola al volver la conexión. El servidor recalcula el riesgo.
  Future<bool> guardarValoracion(DatosNino d, Prediccion p) async {
    final fecha = DateTime.now();
    try {
      await api.guardar(d, fecha);
      invalidar();
      return true;
    } on SinConexion {
      await _encolar(PendienteEnvio(
          datos: d, fecha: fecha, riesgo: p.riesgo, probabilidad: p.probRiesgo));
      return false;
    }
  }

  /// Se evaluó sin conexión (no hay predicción): se guarda el formulario completo en el
  /// teléfono; al reconectar se envía y el servidor calcula el riesgo.
  Future<void> guardarSinConexion(DatosNino d) =>
      _encolar(PendienteEnvio(datos: d, fecha: DateTime.now()));

  /// El usuario decide descartar un pendiente (p. ej. uno que el servidor rechazó).
  Future<void> descartarPendiente(int idLocal) async {
    await _almacen!.eliminar(idLocal);
    _pendientes.removeWhere((p) => p.idLocal == idLocal);
    notifyListeners();
  }

  void _programarReintento() {
    final cada = _reintentoCada;
    if (cada == null || _cerrado || porEnviar == 0) return;
    _reintento?.cancel();
    _reintento = Timer(cada, sincronizar);
  }

  Future<void> sincronizar() async {
    if (sincronizando || porEnviar == 0 || !autenticado) return;
    sincronizando = true;
    notifyListeners();
    try {
      for (final p in List.of(_pendientes)) {
        if (p.error != null || p.idLocal == null) continue;
        try {
          await api.guardar(p.datos, p.fecha);
          await _almacen!.eliminar(p.idLocal!);
          _pendientes.removeWhere((e) => e.idLocal == p.idLocal);
        } on ErrorApi catch (e) {
          // El servidor rechazó los datos: NO se descartan; quedan marcados para que
          // el usuario los vea y decida, y no bloquean al resto de la cola.
          await _almacen!.marcarError(p.idLocal!, e.mensaje);
          final i = _pendientes.indexWhere((x) => x.idLocal == p.idLocal);
          if (i >= 0) _pendientes[i] = _pendientes[i].conError(e.mensaje);
        }
      }
    } on SinConexion {
      // seguimos pendientes; se reintenta luego
    } on SesionExpirada {
      // al volver a iniciar sesión se reintenta
    } finally {
      sincronizando = false;
      version++;
      notifyListeners();
      _programarReintento();
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    _reintento?.cancel();
    _almacen?.cerrar();
    super.dispose();
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
