// Pantalla 3: Formulario de datos (HU02, HU03, HU04; RF07, RF12).
// Las 5 variables del modelo (edad, sexo, altitud, CRED, suplementación) son obligatorias y
// SIN valor por defecto: el usuario debe elegir. Se validan los mismos rangos que la API.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dominio.dart';
import '../models/modelos.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/campo_opcion.dart';
import '../widgets/comunes.dart';
import '../widgets/validadores.dart';
import 'resultado_screen.dart';

class FormularioScreen extends StatefulWidget {
  const FormularioScreen({super.key});
  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

class _FormularioScreenState extends State<FormularioScreen> {
  final _clave = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _edad = TextEditingController();
  final _altitud = TextEditingController();
  final _scroll = ScrollController();
  String? _sexo; // sin valor por defecto
  bool? _cred; // sin valor por defecto
  bool? _suplementacion; // sin valor por defecto
  String _grupo = 'control';
  bool _cargando = false;
  bool _lento = false; // el servidor tarda: probable arranque en frío
  Timer? _temporizador;
  bool _borradorLeido = false;
  String? _errorServidor; // texto del servidor (p. ej. 422 fuera de dominio), tal cual
  DatosNino? _sinConexion; // datos listos para guardarse en el teléfono

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_borradorLeido) return;
    _borradorLeido = true;
    // Recupera lo escrito si la app se cerró o falló antes de evaluar (RNF09).
    final b = AppScope.of(context).leerBorrador();
    _codigo.text = b['codigo'] ?? '';
    _edad.text = b['edad'] ?? '';
    _altitud.text = b['altitud'] ?? '';
    _sexo = (b['sexo'] ?? '').isEmpty ? null : b['sexo'];
    _cred = _leerBool(b['cred']);
    _suplementacion = _leerBool(b['suplementacion']);
    _grupo = b['grupo'] ?? 'control';
  }

  static bool? _leerBool(String? s) => s == '1' ? true : (s == '0' ? false : null);
  static String _escribirBool(bool? v) => v == null ? '' : (v ? '1' : '0');

  void _guardarBorrador() => AppScope.of(context).guardarBorrador({
        'codigo': _codigo.text,
        'edad': _edad.text,
        'altitud': _altitud.text,
        'sexo': _sexo ?? '',
        'grupo': _grupo,
        'cred': _escribirBool(_cred),
        'suplementacion': _escribirBool(_suplementacion),
      });

  void _limpiar() {
    _codigo.clear();
    _edad.clear();
    _altitud.clear();
    setState(() {
      _sexo = null;
      _cred = null;
      _suplementacion = null;
      _grupo = 'control';
      _errorServidor = null;
      _sinConexion = null;
    });
    AppScope.of(context).borrarBorrador();
  }

  /// Lleva la vista al mensaje (error del servidor o sin conexión) para que no quede fuera de pantalla.
  void _mostrarMensaje() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _evaluar() async {
    setState(() {
      _errorServidor = null;
      _sinConexion = null;
    });
    if (!_clave.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final app = AppScope.of(context);
    final datos = DatosNino(
      codigo: _codigo.text.trim(),
      edadMeses: int.parse(_edad.text.trim()),
      sexo: _sexo!,
      altitud: double.parse(_altitud.text.trim().replaceAll(',', '.')),
      cred: _cred!,
      suplementacion: _suplementacion!,
      grupo: _grupo,
    );
    setState(() => _cargando = true);
    _temporizador = Timer(const Duration(seconds: 6), () {
      if (mounted && _cargando) setState(() => _lento = true);
    });
    try {
      final p = await app.api.predecir(datos);
      if (!mounted) return;
      final nueva = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => ResultadoScreen(datos: datos, prediccion: p)),
      );
      if (nueva == true) _limpiar();
    } on SinConexion {
      // Los datos se conservan en el formulario, en el borrador y pueden guardarse en el teléfono.
      _guardarBorrador();
      if (mounted) {
        setState(() => _sinConexion = datos);
        _mostrarMensaje();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sin conexión. Tus datos se conservaron; puedes guardarlos en el teléfono.')));
      }
    } on SesionExpirada {
      _guardarBorrador(); // la app vuelve sola al login; el borrador se conserva
    } catch (e) {
      _guardarBorrador();
      // Un 422 "fuera_de_dominio_modelo" se muestra tal cual lo redacta el servidor.
      if (mounted) {
        setState(() => _errorServidor = mensajeError(e));
        _mostrarMensaje();
      }
    } finally {
      _temporizador?.cancel();
      if (mounted) {
        setState(() {
          _cargando = false;
          _lento = false;
        });
      }
    }
  }

  Future<void> _guardarEnTelefono() async {
    final d = _sinConexion;
    if (d == null) return;
    final app = AppScope.of(context);
    final msg = ScaffoldMessenger.of(context);
    await app.guardarSinConexion(d);
    if (!mounted) return;
    _limpiar();
    msg.showSnackBar(const SnackBar(
        content: Text('Guardada en el teléfono. Se enviará sola al reconectar y el servidor calculará el riesgo.')));
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    for (final c in [_codigo, _edad, _altitud]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva valoración', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Form(
        key: _clave,
        onChanged: _guardarBorrador,
        child: ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _codigo,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'ID del niño *',
                helperText: 'Usa un código; no registres nombres (privacidad)'),
            validator: vCodigo,
          ),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextFormField(
                controller: _edad,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Edad (meses) *',
                    helperText: '${Dominio.edadMin} a ${Dominio.edadMax}'),
                validator: vEdad,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _altitud,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Altitud (msnm) *', helperText: 'Establecimiento: 0 a 700'),
                validator: vAltitud,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          CampoOpcion<String>(
            etiqueta: 'Sexo',
            opciones: const [('F', 'Femenino'), ('M', 'Masculino')],
            valor: _sexo,
            mensajeFalta: 'Elige el sexo del niño',
            alCambiar: (v) {
              setState(() => _sexo = v);
              _guardarBorrador();
            },
          ),
          const SizedBox(height: 16),
          CampoOpcion<bool>(
            etiqueta: 'Asiste a control CRED',
            opciones: const [(true, 'Sí'), (false, 'No')],
            valor: _cred,
            mensajeFalta: 'Indica si asiste a control CRED',
            alCambiar: (v) {
              setState(() => _cred = v);
              _guardarBorrador();
            },
          ),
          const SizedBox(height: 16),
          CampoOpcion<bool>(
            etiqueta: 'Recibe suplementación con hierro',
            opciones: const [(true, 'Sí'), (false, 'No')],
            valor: _suplementacion,
            mensajeFalta: 'Indica si recibe suplementación con hierro',
            alCambiar: (v) {
              setState(() => _suplementacion = v);
              _guardarBorrador();
            },
          ),
          const Titulo('Grupo de estudio'),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'control', label: Text('Control')),
              ButtonSegment(value: 'experimental', label: Text('Experimental')),
            ],
            selected: {_grupo},
            onSelectionChanged: (s) {
              setState(() => _grupo = s.first);
              _guardarBorrador();
            },
          ),
          const SizedBox(height: 24),
          if (_errorServidor != null) ErrorBanner(_errorServidor!),
          if (_sinConexion != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Paleta.medio.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.cloud_off, size: 18, color: Paleta.medio),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text('Sin conexión con el servidor. Tus datos se conservaron.',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                ]),
                const SizedBox(height: 6),
                const Text(
                    'Puedes guardar esta valoración en el teléfono: se enviará sola al reconectar y el servidor calculará el riesgo.',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  onPressed: _guardarEnTelefono,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Guardar en el teléfono'),
                ),
              ]),
            ),
          ],
          FilledButton(
            onPressed: _cargando ? null : _evaluar,
            child: _cargando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Evaluar riesgo'),
          ),
          if (_lento) ...[
            const SizedBox(height: 10),
            const Text('Despertando el servidor… puede tardar hasta un minuto.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Paleta.suave, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          const Text('* Campos obligatorios',
              textAlign: TextAlign.center, style: TextStyle(color: Paleta.suave, fontSize: 12)),
        ]),
      ),
    );
  }
}
