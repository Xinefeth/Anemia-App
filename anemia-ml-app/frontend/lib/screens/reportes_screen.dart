import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/resumen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../utils.dart';
import '../widgets/boton_principal.dart';
import '../widgets/estado_error.dart';
import '../widgets/header_gradiente.dart';
import '../widgets/tarjeta.dart';

/// Pantalla 6 · Reportes e indicadores PC, TR y TT por grupo (HU09).
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  late DateTimeRange _rango;
  Reporte? _reporte;
  String? _error;
  bool _sinConexion = false;
  bool _cargando = true;
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _rango = DateTimeRange(start: DateTime(hoy.year, hoy.month, 1), end: DateTime(hoy.year, hoy.month, hoy.day));
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await ApiService.instancia.reporte(_rango.start, _rango.end);
      if (mounted) setState(() => _reporte = r);
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _error = e.mensaje;
        _sinConexion = e.sinConexion;
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirRango() async {
    final hoy = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(hoy.year, hoy.month, hoy.day),
      initialDateRange: _rango,
      helpText: 'Periodo del reporte',
      saveText: 'Aplicar',
    );
    if (r != null) {
      setState(() => _rango = r);
      _cargar();
    }
  }

  Future<void> _exportar() async {
    setState(() => _exportando = true);
    try {
      // Se registra el reporte en el servidor y luego se arma el PDF.
      final r = await ApiService.instancia.generarReporte(_rango.start, _rango.end);
      final bytes = await PdfService.reporte(r, generadoPor: AuthService.instancia.usuario?.nombre ?? '');
      await Printing.sharePdf(bytes: bytes, filename: 'reporte_anemia_${r.inicio}_${r.fin}.pdf');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HeaderGradiente(
          titulo: 'Reportes',
          subtitulo: 'Indicadores del estudio',
          trailing: BotonHeader(icono: Icons.date_range, tooltip: 'Cambiar periodo', onTap: _elegirRango),
        ),
        Expanded(child: _contenido()),
      ],
    );
  }

  Widget _contenido() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final r = _reporte;
    if (_error != null || r == null) {
      return ErrorReintentar(
          mensaje: _error ?? 'No se pudo cargar el reporte', sinConexion: _sinConexion, onReintentar: _cargar);
    }
    final maxTt = [r.control.tt ?? 0, r.experimental.tt ?? 0].reduce((a, b) => a > b ? a : b);
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AvisoCaja(
              'Grupo Control vs. Experimental · ${fechaDia(_rango.start)} al ${fechaDia(_rango.end)} · ${r.total} valoraciones',
              icono: Icons.assignment_outlined),
          Tarjeta(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const TituloSeccion('Porcentaje de clasificaciones (PC)'),
              _Barra('Experimental', r.experimental.pc, 100, '%', AppColors.riesgoBajo),
              const SizedBox(height: 10),
              _Barra('Control', r.control.pc, 100, '%', AppColors.muted),
            ]),
          ),
          Tarjeta(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const TituloSeccion('Tiempo de respuesta (TR)'),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
                _Grande(r.experimental.trSegundos, 's', 'Experimental', AppColors.riesgoBajo),
                const Text('vs', style: TextStyle(fontSize: 22, color: AppColors.border)),
                _Grande(r.control.trSegundos, 's', 'Control', AppColors.muted, derecha: true),
              ]),
            ]),
          ),
          Tarjeta(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const TituloSeccion('Tasa de tamizaje (TT)'),
              _Barra('Experimental', r.experimental.tt, maxTt, ' niños/día', AppColors.primary),
              const SizedBox(height: 10),
              _Barra('Control', r.control.tt, maxTt, ' niños/día', AppColors.muted),
            ]),
          ),
          if (r.total == 0)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text('No hay valoraciones en el periodo seleccionado.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ),
          BotonPrincipal(
              texto: 'Exportar reporte (PDF)',
              icono: Icons.download,
              cargando: _exportando,
              onPressed: _exportar),
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  final String etiqueta;
  final double? valor;
  final double maximo;
  final String sufijo;
  final Color color;
  const _Barra(this.etiqueta, this.valor, this.maximo, this.sufijo, this.color);

  @override
  Widget build(BuildContext context) {
    final frac = (valor == null || maximo <= 0) ? 0.0 : (valor! / maximo).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$etiqueta · ${valor == null ? 'Sin datos' : '${valor!.toStringAsFixed(valor! % 1 == 0 ? 0 : 1)}$sufijo'}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
            value: frac, minHeight: 8, color: color, backgroundColor: AppColors.border),
      ),
    ]);
  }
}

class _Grande extends StatelessWidget {
  final double? valor;
  final String unidad;
  final String etiqueta;
  final Color color;
  final bool derecha;
  const _Grande(this.valor, this.unidad, this.etiqueta, this.color, {this.derecha = false});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: derecha ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(valor == null ? '—' : '${valor!.toStringAsFixed(1)}$unidad',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
          Text(etiqueta, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      );
}
