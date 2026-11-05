import 'package:flutter/foundation.dart' show kIsWeb;

// Configuración del entorno. Se cambia al compilar con --dart-define.
//   flutter run --dart-define=API_URL=https://mi-backend.onrender.com
//   flutter run --dart-define=MOCK=true      (sin backend, datos de demostración)
class Config {
  // 10.0.2.2 = el PC anfitrión visto desde el emulador de Android; en web, localhost.
  static const String _apiUrlDefinida = String.fromEnvironment('API_URL');
  static String get apiUrl => _apiUrlDefinida.isNotEmpty
      ? _apiUrlDefinida
      : (kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000');
  static const bool mock = bool.fromEnvironment('MOCK', defaultValue: false);
  // 60 s: el plan gratuito de Render tarda en despertar tras inactividad.
  static const Duration timeout = Duration(seconds: 60);
}
