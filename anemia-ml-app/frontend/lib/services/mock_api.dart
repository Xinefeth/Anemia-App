// API simulada para ejecutar la app sin backend (--dart-define=MOCK=true) y
// para las pruebas. NO es el modelo real: clasifica con un umbral de
// hemoglobina solo para poder ver las pantallas.
import 'dart:math';
import '../models/modelos.dart';
import 'api.dart';

class MockApi implements Api {
  final bool simularCaida;
  final List<Valoracion> _datos = [];
  int _sig = 1;
  bool caido = false;

  MockApi({this.simularCaida = false}) {
    final r = Random(7);
    for (var i = 0; i < 12; i++) {
      final hb = 8 + r.nextDouble() * 5;
      final p = _clasificar(hb, 12 + r.nextInt(40));
      _datos.add(Valoracion(
        id: _sig++,
        datos: DatosNino(
          codigo: 'N-${100 + i}',
          edadMeses: 6 + r.nextInt(50),
          sexo: i.isEven ? 'F' : 'M',
          hemoglobina: double.parse(hb.toStringAsFixed(1)),
          altitud: 34,
          grupo: i % 2 == 0 ? 'control' : 'experimental',
        ),
        riesgo: p.riesgo,
        probabilidad: p.probabilidad,
        fecha: DateTime.now().subtract(Duration(days: i, hours: i)),
      ));
    }
  }

  void _revisar() {
    if (caido) throw SinConexion();
  }

  Prediccion _clasificar(double hb, int edad) {
    final riesgo = hb < 10 ? Riesgo.alto : (hb < 11 ? Riesgo.medio : Riesgo.bajo);
    final prob = switch (riesgo) {
      Riesgo.alto => 0.9,
      Riesgo.medio => 0.7,
      Riesgo.bajo => 0.85,
    };
    return Prediccion(
      riesgo: riesgo,
      probabilidad: prob,
      tiempoMs: 42,
      modelo: 'demo (simulado)',
      factores: const [
        Factor('Edad', 0.34),
        Factor('Altitud', 0.27),
        Factor('Suplementación', 0.21),
        Factor('Control CRED', 0.18),
      ],
    );
  }

  @override
  Future<({String token, Usuario usuario})> login(
      String usuario, String clave) async {
    _revisar();
    if (usuario.isEmpty || clave != 'demo') {
      throw ErrorApi('Usuario o contraseña incorrectos');
    }
    return (
      token: 'mock-token',
      usuario: Usuario(id: 1, nombre: 'Dra. Demo', rol: 'médico')
    );
  }

  @override
  Future<Prediccion> predecir(DatosNino d) async {
    _revisar();
    return _clasificar(d.hemoglobina ?? 12, d.edadMeses);
  }

  @override
  Future<Valoracion> guardar(DatosNino d, Prediccion p, DateTime fecha) async {
    _revisar();
    final r = _clasificar(d.hemoglobina ?? 12, d.edadMeses);
    final v = Valoracion(
        id: _sig++,
        datos: d,
        riesgo: r.riesgo,
        probabilidad: r.probabilidad,
        fecha: fecha);
    _datos.insert(0, v);
    return v;
  }

  @override
  Future<List<Valoracion>> listar(Filtro f) async {
    _revisar();
    return _datos.where((v) {
      if (f.riesgo != null && v.riesgo != f.riesgo) return false;
      final q = f.busqueda.toLowerCase();
      if (q.isEmpty) return true;
      return v.datos.codigo.toLowerCase().contains(q) ||
          v.fecha.toIso8601String().startsWith(q);
    }).toList();
  }

  @override
  Future<Valoracion> detalle(int id) async {
    _revisar();
    return _datos.firstWhere((v) => v.id == id);
  }

  @override
  Future<void> eliminar(int id) async {
    _revisar();
    _datos.removeWhere((v) => v.id == id);
  }

  @override
  Future<Dashboard> dashboard() async {
    _revisar();
    int c(Riesgo r) => _datos.where((v) => v.riesgo == r).length;
    final hoy = DateTime.now();
    final dias = List.generate(5, (i) {
      final d = hoy.subtract(Duration(days: 4 - i));
      return _datos
          .where((v) =>
              v.fecha.year == d.year &&
              v.fecha.month == d.month &&
              v.fecha.day == d.day)
          .length;
    });
    final hb = _datos.isEmpty
        ? 0.0
        : _datos.map((v) => v.datos.hemoglobina ?? 0).reduce((a, b) => a + b) /
            _datos.length;
    return Dashboard(
      total: _datos.length,
      alto: c(Riesgo.alto),
      medio: c(Riesgo.medio),
      bajo: c(Riesgo.bajo),
      hbPromedio: hb,
      ultimosDias: dias,
      recientes: _datos.take(3).toList(),
    );
  }

  @override
  Future<Reporte> reporte(DateTime desde, DateTime hasta) async {
    _revisar();
    return Reporte(
      desde: desde,
      hasta: hasta,
      total: _datos.length,
      pc: const Indicador(78, 91),
      tr: const Indicador(240, 45),
      tt: const Indicador(55, 82),
      nValoraciones: const Conteo(6, 6),
      nPc: const Conteo(6, 6),
      nTtValorados: const Conteo(6, 6),
      nTtRegistrados: const Conteo(11, 7),
    );
  }

  // ---- Niños ----
  final List<Nino> _ninos = [
    for (var i = 0; i < 6; i++)
      Nino(
        id: i + 1,
        datos: DatosNino(
          codigo: 'N-${100 + i}',
          edadMeses: 10 + i * 7,
          sexo: i.isEven ? 'F' : 'M',
          hemoglobina: 9.5 + i * 0.6,
          altitud: 34,
          grupo: i.isEven ? 'control' : 'experimental',
        ),
      ),
  ];
  int _sigNino = 7;

  @override
  Future<List<Nino>> listarNinos(String q) async {
    _revisar();
    final b = q.toLowerCase();
    return _ninos
        .where((n) => b.isEmpty || n.datos.codigo.toLowerCase().contains(b))
        .toList();
  }

  @override
  Future<Nino> crearNino(DatosNino d) async {
    _revisar();
    if (_ninos.any((n) => n.datos.codigo == d.codigo)) {
      throw ErrorApi('Ya existe un niño con ese código');
    }
    final n = Nino(id: _sigNino++, datos: d);
    _ninos.insert(0, n);
    return n;
  }

  @override
  Future<Nino> actualizarNino(int id, DatosNino d) async {
    _revisar();
    final i = _ninos.indexWhere((n) => n.id == id);
    _ninos[i] = Nino(id: id, datos: d);
    return _ninos[i];
  }

  @override
  Future<void> eliminarNino(int id) async {
    _revisar();
    _ninos.removeWhere((n) => n.id == id);
  }

  // ---- Usuarios ----
  final List<UsuarioAdmin> _usuarios = [
    const UsuarioAdmin(id: 1, nombre: 'Dra. Demo', usuario: 'dra', rol: 'médico'),
    const UsuarioAdmin(id: 2, nombre: 'Luis Enfermero', usuario: 'luis', rol: 'enfermero'),
  ];
  int _sigUsuario = 3;

  @override
  Future<List<UsuarioAdmin>> listarUsuarios() async {
    _revisar();
    return List.of(_usuarios);
  }

  @override
  Future<UsuarioAdmin> crearUsuario(
      String nombre, String rol, String usuario, String clave) async {
    _revisar();
    if (_usuarios.any((u) => u.usuario == usuario)) {
      throw ErrorApi('Ese nombre de usuario ya existe');
    }
    final u = UsuarioAdmin(id: _sigUsuario++, nombre: nombre, usuario: usuario, rol: rol);
    _usuarios.add(u);
    return u;
  }

  @override
  Future<UsuarioAdmin> actualizarUsuario(int id, String nombre, String rol,
      {String? clave}) async {
    _revisar();
    final i = _usuarios.indexWhere((u) => u.id == id);
    final o = _usuarios[i];
    _usuarios[i] = UsuarioAdmin(
        id: id, nombre: nombre, usuario: o.usuario, rol: rol, activo: o.activo);
    return _usuarios[i];
  }

  @override
  Future<void> eliminarUsuario(int id) async {
    _revisar();
    final i = _usuarios.indexWhere((u) => u.id == id);
    final o = _usuarios[i];
    _usuarios[i] = UsuarioAdmin(
        id: id, nombre: o.nombre, usuario: o.usuario, rol: o.rol, activo: false);
  }
}
