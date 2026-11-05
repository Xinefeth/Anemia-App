import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nino.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils.dart';
import '../widgets/boton_principal.dart';
import '../widgets/estado_error.dart';
import '../widgets/header_gradiente.dart';
import '../widgets/tarjeta.dart';
import 'resultado_screen.dart';

/// Pantalla 3 · Formulario de datos clínicos (HU02, HU03, HU04).
class FormularioScreen extends StatefulWidget {
  const FormularioScreen({super.key});

  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

class _FormularioScreenState extends State<FormularioScreen> {
  final _form = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _edad = TextEditingController();
  final _hb = TextEditingController();
  final _altitud = TextEditingController();
  String? _sexo; // 'M' | 'F'
  String _grupo = 'experimental';
  bool _errorSexo = false;
  bool _cargando = false;
  String? _errorEnvio;
  bool _sinConexion = false;

  @override
  void dispose() {
    for (final c in [_codigo, _edad, _hb, _altitud]) {
      c.dispose();
    }
    super.dispose();
  }

  // ----- Validaciones (HU03): mismos rangos que el backend -----
  String? _vCodigo(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Obligatorio';
    if (t.length > 20) return 'Máximo 20 caracteres';
    if (!RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(t)) return 'Solo letras, números y guion (sin nombres)';
    return null;
  }

  String? _vEdad(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Ingrese un número entero';
    if (n < 0 || n > 60) return 'Debe estar entre 0 y 60 meses';
    return null;
  }

  String? _vHb(String? v) {
    final n = parseDecimal(v ?? '');
    if (n == null) return 'Ingrese un número (ej. 10.5)';
    if (n < 3 || n > 25) return 'Debe estar entre 3.0 y 25.0 g/dL';
    return null;
  }

  String? _vAltitud(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Ingrese un número entero';
    if (n < 0 || n > 5500) return 'Debe estar entre 0 y 5500 msnm';
    return null;
  }

  void _limpiar() {
    _form.currentState?.reset();
    for (final c in [_codigo, _edad, _hb, _altitud]) {
      c.clear();
    }
    setState(() {
      _sexo = null;
      _grupo = 'experimental';
      _errorSexo = false;
      _errorEnvio = null;
    });
  }

  Future<void> _evaluar() async {
    FocusScope.of(context).unfocus();
    final okCampos = _form.currentState!.validate();
    setState(() => _errorSexo = _sexo == null);
    if (!okCampos || _sexo == null) return; // no se procesa si es inválido

    final datos = DatosNino(
      codigo: _codigo.text.trim(),
      edadMeses: int.parse(_edad.text.trim()),
      sexo: _sexo!,
      hemoglobina: parseDecimal(_hb.text)!,
      altitud: int.parse(_altitud.text.trim()),
      grupo: _grupo,
    );
    setState(() {
      _cargando = true;
      _errorEnvio = null;
    });
    try {
      final resultado = await ApiService.instancia.predecir(datos);
      if (!mounted) return;
      final nueva = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ResultadoScreen(datos: datos, resultado: resultado)),
      );
      if (nueva == true) _limpiar();
    } on ApiException catch (e) {
      // Los datos se conservan en el formulario para reintentar sin volver a escribir.
      if (mounted) setState(() {
        _errorEnvio = e.mensaje;
        _sinConexion = e.sinConexion;
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const HeaderGradiente(titulo: 'Nueva valoración', subtitulo: 'Datos clínicos del niño'),
        Expanded(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Tarjeta(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Campo('ID / Código del niño',
                          child: TextFormField(
                            controller: _codigo,
                            decoration: const InputDecoration(hintText: 'Ej. 1042'),
                            textInputAction: TextInputAction.next,
                            validator: _vCodigo,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]'))],
                          )),
                      _Campo('Edad (meses)',
                          child: TextFormField(
                            controller: _edad,
                            decoration: const InputDecoration(hintText: '0 a 60'),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            validator: _vEdad,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          )),
                      _Campo('Sexo',
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Wrap(spacing: 8, children: [
                              for (final (v, t) in [('M', 'Masculino'), ('F', 'Femenino')])
                                _Chip(t, _sexo == v, () => setState(() {
                                      _sexo = v;
                                      _errorSexo = false;
                                    })),
                            ]),
                            if (_errorSexo)
                              const Padding(
                                padding: EdgeInsets.only(top: 6, left: 4),
                                child: Text('Seleccione el sexo',
                                    style: TextStyle(color: AppColors.riesgoAlto, fontSize: 12)),
                              ),
                          ])),
                      _Campo('Hemoglobina (g/dL)',
                          child: TextFormField(
                            controller: _hb,
                            decoration: const InputDecoration(hintText: 'Ej. 10.5'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.next,
                            validator: _vHb,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          )),
                      _Campo('Altitud de residencia (msnm)',
                          child: TextFormField(
                            controller: _altitud,
                            decoration: const InputDecoration(hintText: 'Ej. 34'),
                            keyboardType: TextInputType.number,
                            validator: _vAltitud,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          )),
                      _Campo('Grupo de estudio',
                          ultimo: true,
                          child: Wrap(spacing: 8, children: [
                            for (final (v, t) in [('control', 'Control'), ('experimental', 'Experimental')])
                              _Chip(t, _grupo == v, () => setState(() => _grupo = v)),
                          ])),
                    ],
                  ),
                ),
                if (_errorEnvio != null)
                  AvisoCaja(
                    _sinConexion
                        ? '$_errorEnvio. Sus datos se conservaron; revise la conexión e intente de nuevo.'
                        : _errorEnvio!,
                    icono: _sinConexion ? Icons.cloud_off : Icons.error_outline,
                    color: AppColors.riesgoAlto,
                    fondo: AppColors.altoBg,
                  ),
                BotonPrincipal(
                    texto: 'Evaluar riesgo', icono: Icons.search, onPressed: _evaluar, cargando: _cargando),
                const SizedBox(height: 12),
                const Text('Herramienta de apoyo; no reemplaza el diagnóstico clínico.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  final String etiqueta;
  final Widget child;
  final bool ultimo;
  const _Campo(this.etiqueta, {required this.child, this.ultimo = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: ultimo ? 0 : 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(etiqueta,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 6),
          child,
        ]),
      );
}

class _Chip extends StatelessWidget {
  final String texto;
  final bool activo;
  final VoidCallback onTap;
  const _Chip(this.texto, this.activo, this.onTap);

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(texto),
        selected: activo,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(color: activo ? AppColors.primary : AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: TextStyle(color: activo ? Colors.white : AppColors.muted, fontSize: 13),
      );
}
