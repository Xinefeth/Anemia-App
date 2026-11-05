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
    return Prediccion(riesgo: riesgo, probabilidad: prob, tiempoMs: 42);
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
    return _clasificar(d.hemoglobina, d.edadMeses);
  }

  @override
  Future<Valoracion> guardar(DatosNino d, Prediccion p, DateTime fecha) async {
    _revisar();
    final r = _clasificar(d.hemoglobina, d.edadMeses);
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
        : _datos.map((v) => v.datos.hemoglobina).reduce((a, b) => a + b) /
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
    );
  }
}
