import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/boton_principal.dart';

/// Pantalla 1 · Inicio de sesión (HU01).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  bool _cargando = false;
  bool _ocultar = true;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await AuthService.instancia.login(_usuario.text, _clave.text);
      // La navegación al Dashboard la hace AuthGate al detectar la sesión.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark]),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(26)),
                      child: const Icon(Icons.bloodtype, color: Colors.white, size: 46),
                    ),
                    const SizedBox(height: 18),
                    const Text('AnemIA',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .5)),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        'Valoración del riesgo de anemia infantil con Machine Learning',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(22)),
                      child: Form(
                        key: _form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _usuario,
                              decoration: const InputDecoration(hintText: 'Usuario'),
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.username],
                              validator: (v) => (v ?? '').trim().isEmpty ? 'Ingrese su usuario' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _clave,
                              obscureText: _ocultar,
                              decoration: InputDecoration(
                                hintText: 'Contraseña',
                                suffixIcon: IconButton(
                                  icon: Icon(_ocultar ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _ocultar = !_ocultar),
                                ),
                              ),
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _entrar(),
                              validator: (v) => (v ?? '').isEmpty ? 'Ingrese su contraseña' : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Row(children: [
                                const Icon(Icons.error_outline, size: 16, color: AppColors.riesgoAlto),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            color: AppColors.riesgoAlto, fontSize: 12.5))),
                              ]),
                            ],
                            const SizedBox(height: 16),
                            BotonPrincipal(
                                texto: 'Iniciar sesión', onPressed: _entrar, cargando: _cargando),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('¿Olvidó su contraseña?'),
                                  content: const Text(
                                      'Solicite el restablecimiento al administrador del sistema.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(c), child: const Text('Entendido'))
                                  ],
                                ),
                              ),
                              child: const Text('¿Olvidó su contraseña?',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF9AA7BA))),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
