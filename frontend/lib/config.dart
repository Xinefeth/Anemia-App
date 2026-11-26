import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

// Configuración del entorno. Se cambia al compilar con --dart-define.
//   flutter run --dart-define=API_URL=https://mi-backend.onrender.com
//   flutter run --dart-define=MOCK=true      (sin backend, datos de demostración)
//
// PRIVACIDAD (datos de menores): la comunicación es solo por HTTPS. HTTP se acepta
// únicamente en desarrollo y solo hacia la propia máquina (localhost, 127.0.0.1 o
// 10.0.2.2 = el PC visto desde el emulador de Android). En release nunca.
class Config {
  // 10.0.2.2 = el PC anfitrión visto desde el emulador de Android; en web, localhost.
  static const String _apiUrlDefinida = String.fromEnvironment('API_URL');
  static String get apiUrl => validarUrl(
        _apiUrlDefinida.isNotEmpty
            ? _apiUrlDefinida
            : (kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000'),
        release: kReleaseMode,
      );
  static const bool mock = bool.fromEnvironment('MOCK', defaultValue: false);
  // 60 s: el plan gratuito de Render tarda en despertar tras inactividad.
  static const Duration timeout = Duration(seconds: 60);

  static const _hostsLocales = {'localhost', '127.0.0.1', '10.0.2.2'};

  /// Devuelve [url] si es segura; si no, lanza [UrlInsegura].
  static String validarUrl(String url, {required bool release}) {
    final u = Uri.tryParse(url);
    if (u == null || !u.hasScheme || u.host.isEmpty) {
      throw UrlInsegura('La URL de la API no es válida: $url');
    }
    if (u.scheme == 'https') return url;
    if (u.scheme == 'http' && !release && _hostsLocales.contains(u.host)) return url;
    throw UrlInsegura(
        'Por la privacidad de los datos de menores, la API solo puede usarse por HTTPS ($url no es válida).');
  }
}

class UrlInsegura implements Exception {
  final String mensaje;
  UrlInsegura(this.mensaje);
  @override
  String toString() => mensaje;
}
