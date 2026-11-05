import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/resumen.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils.dart';
import '../widgets/boton_principal.dart';
import '../widgets/estado_error.dart';
import '../widgets/header_gradiente.dart';
import '../widgets/item_valoracion.dart';
import '../widgets/tarjeta.dart';
import 'detalle_screen.dart';

/// Pantalla 2 · Inicio (Dashboard).
class DashboardScreen extends StatefulWidget {
  final VoidCallback onNuevaValoracion;
  final VoidCallback onVerHistorial;
  const DashboardScreen({super.key, required this.onNuevaValoracion, required this.onVerHistorial});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Resumen? _resumen;
  String? _error;
  bool _sinConexion = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    datosCambiaron.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    datosCambiaron.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = _resumen == null);
    try {
      final r = await ApiService.instancia.dashboard();
      if (mounted) setState(() {
        _resumen = r;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _error = e.mensaje;
        _sinConexion = e.sinConexion;
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = AuthService.instancia.usuario;
    return Column(
      children: [
        HeaderGradiente(
          hijo: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(saludo(),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                    Text(u?.nombre ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Cuenta',
                onSelected: (_) => AuthService.instancia.cerrarSesion(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'salir', child: Text('Cerrar sesión')),
                ],
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  child: Text(u?.iniciales ?? '',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _cuerpo()),
      ],
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final r = _resumen;
    if (r == null) {
      return ErrorReintentar(
          mensaje: _error ?? 'No se pudieron cargar los datos', sinConexion: _sinConexion, onReintentar: _cargar);
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) const AvisoCaja('Sin conexión: mostrando los últimos datos cargados', icono: Icons.cloud_off),
          Row(children: [
            _Stat('${r.total}', 'EVALUACIONES'),
            const SizedBox(width: 10),
            _Stat('${r.enRiesgo}', 'EN RIESGO'),
            const SizedBox(width: 10),
            _Stat(r.precision == null ? '—' : '${(r.precision! * 100).round()}%', 'PRECISIÓN'),
          ]),
          const SizedBox(height: 14),
          BotonPrincipal(texto: 'Nueva valoración', icono: Icons.add, onPressed: widget.onNuevaValoracion),
          const SizedBox(height: 16),
          const TituloSeccion('Resumen del mes'),
          Tarjeta(child: SizedBox(height: 130, child: _Grafico(r.meses))),
          TituloSeccion('Valoraciones recientes', accion: 'Ver todas', onAccion: widget.onVerHistorial),
          if (r.recientes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aún no hay valoraciones registradas.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ),
          for (final v in r.recientes)
            ItemValoracion(
              valoracion: v,
              subtitulo: '${fechaRelativa(v.fechaHora)} · ${v.hemoglobina} g/dL',
              onTap: () => Navigator.of(context, rootNavigator: true)
                  .push(MaterialPageRoute(builder: (_) => DetalleScreen(valoracion: v))),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Herramienta de apoyo; no reemplaza el diagnóstico clínico.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String valor;
  final String etiqueta;
  const _Stat(this.valor, this.etiqueta);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.sombra),
          child: Column(children: [
            Text(valor,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
            const SizedBox(height: 2),
            Text(etiqueta,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.muted)),
          ]),
        ),
      );
}

class _Grafico extends StatelessWidget {
  final List<({String mes, int total})> meses;
  const _Grafico(this.meses);

  @override
  Widget build(BuildContext context) {
    final maximo = meses.fold<int>(1, (m, e) => e.total > m ? e.total : m);
    return BarChart(
      BarChartData(
        maxY: maximo * 1.25,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, _, rod, __) => BarTooltipItem(
                '${rod.toY.round()}', const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(nombreMes(int.parse(meses[v.toInt()].mes.substring(5))),
                    style: const TextStyle(fontSize: 10, color: AppColors.muted)),
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < meses.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: meses[i].total.toDouble(),
                width: 28,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppColors.primary, Color(0xFF5FA0EC)]),
              ),
            ]),
        ],
      ),
    );
  }
}
