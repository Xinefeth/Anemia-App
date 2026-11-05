// Gestión de usuarios: listar, registrar, modificar y eliminar/inhabilitar (RF03-RF06).
import 'package:flutter/material.dart';
import '../models/modelos.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});
  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  List<UsuarioAdmin>? _lista;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lista == null && _error == null) _cargar();
  }

  Future<void> _cargar() async {
    try {
      final l = await AppScope.of(context).api.listarUsuarios();
      if (mounted) setState(() { _lista = l; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e; _lista = null; });
    }
  }

  Future<void> _abrir([UsuarioAdmin? u]) async {
    final cambio = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => UsuarioFormScreen(usuario: u)));
    if (cambio == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final l = _lista;
    final miId = AppScope.of(context).usuario?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios', style: TextStyle(fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(),
        icon: const Icon(Icons.person_add),
        label: const Text('Registrar usuario'),
      ),
      body: _error != null
          ? (_error is ErrorApi && (_error as ErrorApi).codigo == 403
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.lock_outline, size: 40, color: Paleta.suave),
                      SizedBox(height: 12),
                      Text('Sin permiso: solo médicos y administradores pueden gestionar usuarios.',
                          textAlign: TextAlign.center),
                    ]),
                  ),
                )
              : EstadoError(_error!, _cargar))
          : l == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: l.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final u = l[i];
                    return Card(
                      child: ListTile(
                        onTap: () => _abrir(u),
                        leading: CircleAvatar(
                          backgroundColor: u.activo ? const Color(0xFFE0F2F1) : Paleta.borde,
                          child: Icon(Icons.person,
                              color: u.activo ? Paleta.primario : Paleta.suave),
                        ),
                        title: Text(u.nombre + (u.id == miId ? ' (tú)' : ''),
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: u.activo ? Paleta.tinta : Paleta.suave)),
                        subtitle: Text('@${u.usuario} · ${u.rol}${u.activo ? '' : ' · inhabilitado'}'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
    );
  }
}

class UsuarioFormScreen extends StatefulWidget {
  final UsuarioAdmin? usuario;
  const UsuarioFormScreen({super.key, this.usuario});
  @override
  State<UsuarioFormScreen> createState() => _UsuarioFormScreenState();
}

class _UsuarioFormScreenState extends State<UsuarioFormScreen> {
  final _clave = GlobalKey<FormState>();
  late final TextEditingController _nombre, _usuario, _contrasena;
  late String _rol;
  bool _guardando = false;
  bool _ocultar = true;

  bool get _edicion => widget.usuario != null;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.usuario?.nombre ?? '');
    _usuario = TextEditingController(text: widget.usuario?.usuario ?? '');
    _contrasena = TextEditingController();
    _rol = widget.usuario?.rol ?? 'enfermero';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _usuario.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_clave.currentState!.validate()) return;
    final api = AppScope.of(context).api;
    final msg = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _guardando = true);
    try {
      if (_edicion) {
        await api.actualizarUsuario(widget.usuario!.id, _nombre.text.trim(), _rol,
            clave: _contrasena.text);
      } else {
        await api.crearUsuario(
            _nombre.text.trim(), _rol, _usuario.text.trim(), _contrasena.text);
      }
      nav.pop(true);
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text(mensajeError(e))));
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _inhabilitar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Inhabilitar usuario'),
        content: const Text('El usuario ya no podrá iniciar sesión. Sus valoraciones se conservan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Inhabilitar', style: TextStyle(color: Paleta.alto))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final api = AppScope.of(context).api;
    final msg = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await api.eliminarUsuario(widget.usuario!.id);
      nav.pop(true);
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text(mensajeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final esYo = AppScope.of(context).usuario?.id == widget.usuario?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(_edicion ? 'Editar usuario' : 'Registrar usuario',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          // No se permite inhabilitarse a uno mismo ni a un usuario ya inhabilitado.
          if (_edicion && !esYo && widget.usuario!.activo)
            IconButton(
                tooltip: 'Inhabilitar',
                icon: const Icon(Icons.person_off_outlined),
                onPressed: _inhabilitar),
        ],
      ),
      body: Form(
        key: _clave,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _usuario,
            enabled: !_edicion,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Usuario *'),
            validator: (v) => RegExp(r'^[A-Za-z0-9_.\-]{3,50}$').hasMatch(v?.trim() ?? '')
                ? null
                : 'Entre 3 y 50 caracteres: letras, números, _ . -',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _contrasena,
            obscureText: _ocultar,
            decoration: InputDecoration(
              labelText: _edicion ? 'Nueva contraseña (opcional)' : 'Contraseña *',
              suffixIcon: IconButton(
                icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _ocultar = !_ocultar),
              ),
            ),
            validator: (v) {
              final t = v ?? '';
              if (_edicion && t.isEmpty) return null;
              return t.length < 4 ? 'La contraseña debe tener al menos 4 caracteres' : null;
            },
          ),
          const Titulo('Rol'),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'médico', label: Text('Médico')),
              ButtonSegment(value: 'enfermero', label: Text('Enfermero(a)')),
              ButtonSegment(value: 'administrador', label: Text('Admin.')),
            ],
            selected: {_rol},
            onSelectionChanged: (s) => setState(() => _rol = s.first),
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
