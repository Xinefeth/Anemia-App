// API simulada para ejecutar la app sin backend (--dart-define=MOCK=true) y
// para las pruebas. NO es el modelo real: calcula un riesgo inventado a partir de las
// 5 variables solo para poder ver las pantallas. Respeta el contrato del backend
// (campos obligatorios, dominio de validez y errores 422).
import 'dart:math';
import '../models/dominio.dart';
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
      final d = DatosNino(
        codigo: 'N-${100 + i}',
        edadMeses: 6 + r.nextInt(50),
        sexo: i.isEven ? 'F' : 'M',
        altitud: 34,
        cred: r.nextBool(),
        suplementacion: r.nextBool(),
        grupo: i % 2 == 0 ? 'control' : 'experimental',
      );
      final p = _clasificar(d);
      _datos.add(Valoracion(
        id: _sig++,
        datos: d,
        riesgo: p.riesgo,
        probabilidad: p.probRiesgo,
        fecha: DateTime.now().subtract(Duration(days: i, hours: i)),
      ));
    }
  }

  /// Solo pruebas: error que lanzará la próxima llamada a predecir (p. ej. un 422).
  Object? falla;

  /// Solo pruebas: error que lanzará guardar (p. ej. un 422 al sincronizar).
  Object? fallaAlGuardar;

  void _revisar() {
    if (caido) throw SinConexion();
  }

  /// Igual que el backend real: fuera del dominio del modelo responde 422 (fuera_de_dominio_modelo).
  void _validarDominio(DatosNino d) {
    if (d.edadMeses < Dominio.edadMin || d.edadMeses > Dominio.edadMax) {
      throw ErrorApi(
          'edad_meses debe estar entre ${Dominio.edadMin} y ${Dominio.edadMax} meses: el modelo se entrenó con niños de 6 a 59 meses y no es válido fuera de ese rango',
          codigo: 422,
          tipo: tipoFueraDeDominio);
    }
    if (d.altitud < Dominio.altitudMin || d.altitud > Dominio.altitudMax) {
      throw ErrorApi(
          'altitud debe estar entre 0 y 700 msnm: el modelo solo es válido para establecimientos de Trujillo (entrenado con altitudes de 10 a 659 msnm)',
          codigo: 422,
          tipo: tipoFueraDeDominio);
    }
  }

  /// Riesgo inventado (NO clínico): más puntaje sin CRED, en lactantes y a mayor altitud.
  Prediccion _clasificar(DatosNino d) {
    final puntaje = (d.cred ? 0.0 : 1.0) + (d.edadMeses < 24 ? 0.5 : 0.0) +
        (d.suplementacion ? 0.0 : 0.2) + d.altitud / 700;
    final riesgo = puntaje >= 1.5 ? Riesgo.alto : (puntaje >= 0.9 ? Riesgo.medio : Riesgo.bajo);
    final alto = (puntaje / 4).clamp(0.01, 0.35);
    final medio = (puntaje / 8).clamp(0.02, 0.2);
    final probs = {Riesgo.bajo: 1 - alto - medio, Riesgo.medio: medio, Riesgo.alto: alto};
    return Prediccion(
      riesgo: riesgo,
      probabilidad: probs[riesgo]!,
      probabilidades: probs,
      tiempoMs: 42,
      modelo: 'demo (simulado)',
      factores: const [
        Factor('Asiste a control CRED', 0.30),
        Factor('Edad del niño', 0.30),
        Factor('Altitud de residencia', 0.18),
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
    final f = falla;
    if (f != null) {
      falla = null;
      throw f;
    }
    _validarDominio(d);
    return _clasificar(d);
  }

  @override
  Future<Valoracion> guardar(DatosNino d, DateTime fecha) async {
    _revisar();
    final f = fallaAlGuardar;
    if (f != null) throw f;
    _validarDominio(d);
    final r = _clasificar(d);
    final v = Valoracion(
        id: _sig++,
        datos: d,
        riesgo: r.riesgo,
        probabilidad: r.probRiesgo,
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
    return Dashboard(
      total: _datos.length,
      alto: c(Riesgo.alto),
      medio: c(Riesgo.medio),
      bajo: c(Riesgo.bajo),
      hbPromedio: 0, // la app ya no captura hemoglobina
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
          altitud: 34,
          cred: i.isEven,
          suplementacion: true,
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
    _validarDominio(d);
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
    _validarDominio(d);
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
