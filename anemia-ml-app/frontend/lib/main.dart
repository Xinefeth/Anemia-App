import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnemiaApp());
}

class AnemiaApp extends StatelessWidget {
  const AnemiaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AnemIA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      );
}

/// Muestra Login o la app según haya sesión; reacciona a cerrar sesión / token vencido.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService.instancia;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    _auth.restaurar().whenComplete(() {
      if (mounted) setState(() => _listo = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_listo) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ListenableBuilder(
      listenable: _auth,
      builder: (_, __) => _auth.autenticado ? const HomeShell() : const LoginScreen(),
    );
  }
}
