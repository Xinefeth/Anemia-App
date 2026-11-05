// Pantalla 3: Formulario de datos (HU02, HU03, HU04; RF07, RF12).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/modelos.dart';
import '../services/api.dart';
import '../theme.dart';
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
  final _hb = TextEditingController();
  final _altitud = TextEditingController();
  String _sexo = 'F';
  String _grupo = 'control';
  bool _cred = false;
  bool _suplementacion = false;
  bool _cargando = false;
  bool _lento = false; // el servidor tarda: probable arranque en frío
  Timer? _temporizador;
  bool _borradorLeido = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_borradorLeido) return;
    _borradorLeido = true;
    // Recupera lo escrito si la app se cerró o falló antes de evaluar (RNF09).
    final b = AppScope.of(context).leerBorrador();
    _codigo.text = b['codigo'] ?? '';
    _edad.text = b['edad'] ?? '';
    _hb.text = b['hb'] ?? '';
    _altitud.text = b['altitud'] ?? '';
    _sexo = b['sexo'] ?? 'F';
    _grupo = b['grupo'] ?? 'control';
    _cred = b['cred'] == '1';
    _suplementacion = b['suplementacion'] == '1';
  }

  void _guardarBorrador() => AppScope.of(context).guardarBorrador({
        'codigo': _codigo.text,
        'edad': _edad.text,
        'hb': _hb.text,
        'altitud': _altitud.text,
        'sexo': _sexo,
        'grupo': _grupo,
        'cred': _cred ? '1' : '0',
        'suplementacion': _suplementacion ? '1' : '0',
      });

  void _limpiar() {
    _codigo.clear();
    _edad.clear();
    _hb.clear();
    _altitud.clear();
    setState(() {
      _sexo = 'F';
      _grupo = 'control';
      _cred = false;
      _suplementacion = false;
    });
    AppScope.of(context).borrarBorrador();
  }

  Future<void> _evaluar() async {
    if (!_clave.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final app = AppScope.of(context);
    final datos = DatosNino(
      codigo: _codigo.text.trim(),
      edadMeses: int.parse(_edad.text),
      sexo: _sexo,
      hemoglobina: double.parse(_hb.text.replaceAll(',', '.')),
      altitud: double.parse(_altitud.text.replaceAll(',', '.')),
      cred: _cred,
      suplementacion: _suplementacion,
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
    } catch (e) {
      // Los datos se conservan en el formulario y en el borrador.
      _guardarBorrador();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is SinConexion
              ? 'Sin conexión. Tus datos se conservaron; intenta de nuevo.'
              : mensajeError(e)),
        ));
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

  @override
  void dispose() {
    _temporizador?.cancel();
    for (final c in [_codigo, _edad, _hb, _altitud]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva valoración', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Form(
        key: _clave,
        onChanged: _guardarBorrador,
        child: ListView(padding: const EdgeInsets.all(16), children: [
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
                decoration: const InputDecoration(labelText: 'Edad (meses) *'),
                validator: vEdad,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Sexo'),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'F', label: Text('F')),
                    ButtonSegment(value: 'M', label: Text('M')),
                  ],
                  selected: {_sexo},
                  onSelectionChanged: (s) {
                    setState(() => _sexo = s.first);
                    _guardarBorrador();
                  },
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          TextFormField(
            controller: _hb,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Hemoglobina (g/dL) *'),
            validator: vHb,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _altitud,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Altitud (msnm) *'),
            validator: vAltitud,
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Asiste a control CRED'),
            value: _cred,
            onChanged: (v) {
              setState(() => _cred = v);
              _guardarBorrador();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recibe suplementación con hierro'),
            value: _suplementacion,
            onChanged: (v) {
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
