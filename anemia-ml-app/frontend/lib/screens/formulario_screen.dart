// Pantalla 3: Formulario de datos (HU02, HU03, HU04; RF07, RF12).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/modelos.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
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
  bool _cargando = false;
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
  }

  void _guardarBorrador() => AppScope.of(context).guardarBorrador({
        'codigo': _codigo.text,
        'edad': _edad.text,
        'hb': _hb.text,
        'altitud': _altitud.text,
        'sexo': _sexo,
        'grupo': _grupo,
      });

  void _limpiar() {
    _codigo.clear();
    _edad.clear();
    _hb.clear();
    _altitud.clear();
    setState(() {
      _sexo = 'F';
      _grupo = 'control';
    });
    AppScope.of(context).borrarBorrador();
  }

  // Reglas RN01 (menor de 5 años) y RN02 (hemoglobina en rango clínico).
  String? _vCodigo(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Ingresa el código del niño' : null;

  String? _vNumero(String? v, String campo, double min, double max,
      {String unidad = ''}) {
    if (v == null || v.trim().isEmpty) return 'Ingresa ${campo.toLowerCase()}';
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null) return '$campo no es un número válido';
    if (n < min || n > max) return '$campo debe estar entre $min y $max $unidad'.trim();
    return null;
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
      grupo: _grupo,
    );
    setState(() => _cargando = true);
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
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
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
            validator: _vCodigo,
          ),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextFormField(
                controller: _edad,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Edad (meses) *'),
                validator: (v) => _vNumero(v, 'La edad', 0, 59, unidad: 'meses'),
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
            validator: (v) => _vNumero(v, 'La hemoglobina', 3, 20, unidad: 'g/dL'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _altitud,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Altitud (msnm) *'),
            validator: (v) => _vNumero(v, 'La altitud', 0, 5500, unidad: 'msnm'),
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
          const SizedBox(height: 10),
          const Text('* Campos obligatorios',
              textAlign: TextAlign.center, style: TextStyle(color: Paleta.suave, fontSize: 12)),
        ]),
      ),
    );
  }
}
