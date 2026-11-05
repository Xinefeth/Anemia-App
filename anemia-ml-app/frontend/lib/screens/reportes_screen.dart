// Pantalla 6: Reportes (HU09; RF20, RF21). Indicadores PC, TR y TT por grupo.
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/modelos.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});
  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  late DateTimeRange _rango;
  Reporte? _r;
  Object? _error;
  bool _cargando = false;
  int _version = -1;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _rango = DateTimeRange(
        start: DateTime(hoy.year, hoy.month, 1), end: DateTime(hoy.year, hoy.month, hoy.day));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final v = AppScope.of(context).version;
    if (v != _version) {
      _version = v;
      _cargar();
    }
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final r = await AppScope.of(context).api.reporte(_rango.start, _rango.end);
      if (mounted) setState(() { _r = r; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e; });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirPeriodo() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _rango,
      locale: const Locale('es'),
    );
    if (r != null) {
      setState(() => _rango = r);
      _cargar();
    }
  }

  Future<void> _exportar() async {
    final r = _r!;
    final doc = pw.Document();
    String f(double v, String u) => '${v.toStringAsFixed(0)} $u';
    doc.addPage(pw.Page(
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Reporte de valoraciones',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Periodo: ${fmtDia(r.desde)} al ${fmtDia(r.hasta)}'),
        pw.Text('Valoraciones en el periodo: ${r.total}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Indicador', 'Control', 'Experimental'],
          data: [
            ['PC - Clasificaciones correctas', f(r.pc.control, '%'), f(r.pc.experimental, '%')],
            ['TR - Tiempo de respuesta', f(r.tr.control, 's'), f(r.tr.experimental, 's')],
            ['TT - Tasa de tamizaje', f(r.tt.control, '%'), f(r.tt.experimental, '%')],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
          cellPadding: const pw.EdgeInsets.all(8),
        ),
        pw.SizedBox(height: 24),
        pw.Text('Resultado de apoyo: no reemplaza el diagnóstico clínico.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      ]),
    ));
    try {
      await Printing.sharePdf(
          bytes: await doc.save(), filename: 'reporte_${fmtDia(r.desde).replaceAll('/', '-')}.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No se pudo exportar el PDF.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.date_range, color: Paleta.primario),
            title: const Text('Periodo de comparación'),
            subtitle: Text('${fmtDia(_rango.start)} – ${fmtDia(_rango.end)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _elegirPeriodo,
          ),
        ),
        const SizedBox(height: 12),
        if (_cargando) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        if (!_cargando && _error != null && r == null) SizedBox(height: 240, child: EstadoError(_error!, _cargar)),
        if (!_cargando && _error != null && r != null)
          const AvisoSinConexion('No se pudo actualizar; se muestra el último reporte cargado.'),
        if (r != null && !_cargando) ...[
          Text('${r.total} valoraciones en el periodo',
              style: const TextStyle(color: Paleta.suave)),
          const SizedBox(height: 8),
          _TarjetaIndicador('Indicador PC', 'Clasificaciones correctas', r.pc, '%', max: 100),
          const SizedBox(height: 10),
          _TarjetaIndicador('Indicador TR', 'Tiempo de respuesta (menor es mejor)', r.tr, ' s',
              max: [r.tr.control, r.tr.experimental].reduce((a, b) => a > b ? a : b)),
          const SizedBox(height: 10),
          _TarjetaIndicador('Indicador TT', 'Tasa de tamizaje', r.tt, '%', max: 100),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _exportar,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Exportar PDF')),
        ],
      ]),
    );
  }
}

class _TarjetaIndicador extends StatelessWidget {
  final String titulo, detalle, unidad;
  final Indicador ind;
  final double max;
  const _TarjetaIndicador(this.titulo, this.detalle, this.ind, this.unidad, {required this.max});

  Widget _barra(String etiqueta, double v, Color c) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          SizedBox(width: 92, child: Text(etiqueta, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: max <= 0 ? 0 : (v / max).clamp(0, 1),
                minHeight: 12,
                color: c,
                backgroundColor: Paleta.borde,
              ),
            ),
          ),
          SizedBox(
              width: 64,
              child: Text('${v.toStringAsFixed(0)}$unidad',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(detalle, style: const TextStyle(color: Paleta.suave, fontSize: 12)),
            _barra('Control', ind.control, Paleta.suave),
            _barra('Experimental', ind.experimental, Paleta.primario),
          ]),
        ),
      );
}
