// Punto de entrada de la aplicación móvil.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'services/app_state.dart';
import 'theme.dart';
import 'widgets/comunes.dart';

void main() {
  runApp(AnemiaApp(estado: AppState()..iniciar()));
}

class AnemiaApp extends StatelessWidget {
  final AppState estado;
  const AnemiaApp({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      estado: estado,
      child: MaterialApp(
        title: 'Valoración de Anemia',
        theme: construirTema(),
        debugShowCheckedModeBanner: false,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _Raiz(),
      ),
    );
  }
}

class _Raiz extends StatelessWidget {
  const _Raiz();

  @override
  Widget build(BuildContext context) {
    final e = AppScope.of(context);
    if (!e.listo) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return e.autenticado ? const Shell() : const LoginScreen();
  }
}
