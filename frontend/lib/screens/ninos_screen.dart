// Gestión de niños: listar, buscar, registrar, modificar y eliminar (RF07-RF11).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/modelos.dart';
import '../theme.dart';
import '../widgets/campo_opcion.dart';
import '../widgets/comunes.dart';
import '../widgets/validadores.dart';

class NinosScreen extends StatefulWidget {
  const NinosScreen({super.key});
  @override
  State<NinosScreen> createState() => _NinosScreenState();
}

class _NinosScreenState extends State<NinosScreen> {
  final _buscar = TextEditingController();
  List<Nino>? _lista;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lista == null && _error == null) _cargar();
  }

  Future<void> _cargar() async {
    try {
      final l = await AppScope.of(context).api.listarNinos(_buscar.text.trim());
      if (mounted) setState(() { _lista = l; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e; _lista = null; });
    }
  }

  Future<void> _abrir([Nino? n]) async {
    final cambio = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => NinoFormScreen(nino: n)));
    if (cambio == true) _cargar();
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = _lista;
    return Scaffold(
      appBar: AppBar(title: const Text('Niños', style: TextStyle(fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(),
        icon: const Icon(Icons.add),
        label: const Text('Registrar niño'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: TextField(
            controller: _buscar,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _cargar(),
            decoration: InputDecoration(
              hintText: 'Buscar por código',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _buscar.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _buscar.clear();
                        _cargar();
                      }),
            ),
          ),
        ),
        Expanded(
          child: _error != null
              ? EstadoError(_error!, _cargar)
              : l == null
                  ? const Center(child: CircularProgressIndicator())
                  : l.isEmpty
                      ? const Center(
                          child: Text('No hay niños que coincidan.',
                              style: TextStyle(color: Paleta.suave)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                          itemCount: l.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final n = l[i];
                            return Card(
                              child: ListTile(
                                onTap: () => _abrir(n),
                                leading: CircleAvatar(
                                    backgroundColor: Paleta.primario.withValues(alpha: 0.12),
                                    child: const Icon(Icons.child_care, color: Paleta.primario)),
                                title: Text(n.datos.codigo,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    '${n.datos.edadMeses} meses · ${n.datos.sexo == 'F' ? 'Niña' : 'Niño'} · '
                                    '${n.datos.altitud.toStringAsFixed(0)} msnm'),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}

/// Alta y edición de un niño. Con [nino] nulo registra uno nuevo.
class NinoFormScreen extends StatefulWidget {
  final Nino? nino;
  const NinoFormScreen({super.key, this.nino});
  @override
  State<NinoFormScreen> createState() => _NinoFormScreenState();
}

class _NinoFormScreenState extends State<NinoFormScreen> {
  final _clave = GlobalKey<FormState>();
  late final TextEditingController _codigo, _edad, _altitud;
  String? _sexo; // sin valor por defecto al registrar
  bool? _cred;
  bool? _suplementacion;
  late String _grupo;
  bool _guardando = false;

  bool get _edicion => widget.nino != null;

  @override
  void initState() {
    super.initState();
    final d = widget.nino?.datos;
    _codigo = TextEditingController(text: d?.codigo ?? '');
    _edad = TextEditingController(text: d?.edadMeses.toString() ?? '');
    _altitud = TextEditingController(text: d?.altitud.toStringAsFixed(0) ?? '');
    _sexo = d?.sexo;
    _grupo = d?.grupo ?? 'control';
    _cred = d?.cred;
    _suplementacion = d?.suplementacion;
  }

  @override
  void dispose() {
    for (final c in [_codigo, _edad, _altitud]) {
      c.dispose();
    }
    super.dispose();
  }

  DatosNino _datos() => DatosNino(
        codigo: _codigo.text.trim(),
        edadMeses: int.parse(_edad.text),
        sexo: _sexo!,
        altitud: double.parse(_altitud.text.replaceAll(',', '.')),
        cred: _cred!,
        suplementacion: _suplementacion!,
        grupo: _grupo,
      );

  Future<void> _guardar() async {
    if (!_clave.currentState!.validate()) return;
    final api = AppScope.of(context).api;
    final msg = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _guardando = true);
    try {
      if (_edicion) {
        await api.actualizarNino(widget.nino!.id, _datos());
      } else {
        await api.crearNino(_datos());
      }
      nav.pop(true);
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text(mensajeError(e))));
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar niño'),
        content: const Text('Se eliminará el niño y también todas sus valoraciones. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Eliminar', style: TextStyle(color: Paleta.alto))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final api = AppScope.of(context).api;
    final app = AppScope.of(context);
    final msg = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await api.eliminarNino(widget.nino!.id);
      app.invalidar();
      nav.pop(true);
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text(mensajeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_edicion ? 'Editar niño' : 'Registrar niño',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_edicion)
            IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: _eliminar),
        ],
      ),
      body: Form(
        key: _clave,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _codigo,
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
                decoration: const InputDecoration(labelText: 'Edad (meses) *', helperText: '6 a 59'),
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
            alCambiar: (v) => setState(() => _sexo = v),
          ),
          const SizedBox(height: 16),
          CampoOpcion<bool>(
            etiqueta: 'Asiste a control CRED',
            opciones: const [(true, 'Sí'), (false, 'No')],
            valor: _cred,
            mensajeFalta: 'Indica si asiste a control CRED',
            alCambiar: (v) => setState(() => _cred = v),
          ),
          const SizedBox(height: 16),
          CampoOpcion<bool>(
            etiqueta: 'Recibe suplementación con hierro',
            opciones: const [(true, 'Sí'), (false, 'No')],
            valor: _suplementacion,
            mensajeFalta: 'Indica si recibe suplementación con hierro',
            alCambiar: (v) => setState(() => _suplementacion = v),
          ),
          const Titulo('Grupo de estudio'),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'control', label: Text('Control')),
              ButtonSegment(value: 'experimental', label: Text('Experimental')),
            ],
            selected: {_grupo},
            onSelectionChanged: (s) => setState(() => _grupo = s.first),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(_edicion ? 'Guardar cambios' : 'Registrar'),
          ),
        ]),
      ),
    );
  }
}
