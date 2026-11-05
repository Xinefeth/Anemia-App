import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario.dart';
import 'api_service.dart';
import 'db_service.dart';

/// Sesión del usuario (HU01). Guarda el token localmente para no pedir
/// credenciales en cada apertura; el servidor lo hace vencer a las 12 h.
class AuthService extends ChangeNotifier {
  AuthService._() {
    ApiService.instancia.onSesionVencida = () => cerrarSesion();
  }
  static final instancia = AuthService._();

  static const _kToken = 'token';
  static const _kUsuario = 'usuario';

  Usuario? usuario;
  bool get autenticado => usuario != null;

  /// Restaura la sesión guardada. Si no hay red, se confía en lo guardado.
  Future<void> restaurar() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    final datos = prefs.getString(_kUsuario);
    if (token == null || datos == null) return;
    ApiService.instancia.token = token;
    try {
      usuario = await ApiService.instancia.me();
    } on ApiException catch (e) {
      if (e.sinConexion) {
        usuario = Usuario.fromJson(jsonDecode(datos) as Map<String, dynamic>);
      } else {
        await cerrarSesion();
      }
    }
    notifyListeners();
  }

  Future<void> login(String user, String clave) async {
    final (token, u) = await ApiService.instancia.login(user.trim(), clave);
    ApiService.instancia.token = token;
    usuario = u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUsuario, jsonEncode(u.toJson()));
    notifyListeners();
  }

  Future<void> cerrarSesion() async {
    ApiService.instancia.token = null;
    usuario = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUsuario);
    await DbService.instancia.limpiarCache(); // no dejar datos de pacientes en el equipo
    notifyListeners();
  }
}
