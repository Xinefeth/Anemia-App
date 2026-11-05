// Configuración del entorno. Se cambia al compilar con --dart-define.
//   flutter run --dart-define=API_URL=https://mi-backend.onrender.com
//   flutter run --dart-define=MOCK=true      (sin backend, datos de demostración)
class Config {
  // 10.0.2.2 = el PC anfitrión visto desde el emulador de Android.
  static const String apiUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');
  static const bool mock = bool.fromEnvironment('MOCK', defaultValue: false);
  static const Duration timeout = Duration(seconds: 15);
}
