// ignore_for_file: prefer_const_constructors
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/resumen.dart';
import '../utils.dart';

/// Genera el PDF del reporte de indicadores (HU09).
/// Se evitan símbolos fuera de Latin-1 porque se usa la fuente estándar del PDF.
class PdfService {
  static String _num(double? v, String sufijo, {int dec = 1}) =>
      v == null ? 'Sin datos' : '${v.toStringAsFixed(dec)}$sufijo';

  static Future<Uint8List> reporte(Reporte r, {required String generadoPor}) async {
    final doc = pw.Document(title: 'Reporte AnemIA');
    final inicio = DateTime.parse(r.inicio);
    final fin = DateTime.parse(r.fin);

    pw.Widget tabla(List<List<String>> filas) => pw.TableHelper.fromTextArray(
          headers: filas.first,
          data: filas.sublist(1),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E6FD9)),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(6),
        );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => [
        pw.Text('AnemIA - Reporte de indicadores',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Periodo: ${fechaDia(inicio)} al ${fechaDia(fin)}'),
        pw.Text('Valoraciones incluidas: ${r.total}'),
        if (r.idReporte != null) pw.Text('Reporte N.o ${r.idReporte}'),
        pw.SizedBox(height: 16),
        pw.Text('Comparacion Grupo Control vs. Experimental',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        tabla([
          ['Indicador', 'Control', 'Experimental'],
          ['Valoraciones', '${r.control.total}', '${r.experimental.total}'],
          ['PC - % clasificaciones correctas', _num(r.control.pc, '%'), _num(r.experimental.pc, '%')],
          ['TR - tiempo de respuesta', _num(r.control.trSegundos, ' s'), _num(r.experimental.trSegundos, ' s')],
          ['TT - ninos tamizados por dia', _num(r.control.tt, ''), _num(r.experimental.tt, '')],
        ]),
        pw.SizedBox(height: 16),
        pw.Text('Distribucion por nivel de riesgo',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        tabla([
          ['Nivel', 'Control', 'Experimental'],
          for (final n in ['Bajo', 'Medio', 'Alto'])
            [n, '${r.control.distribucion[n] ?? 0}', '${r.experimental.distribucion[n] ?? 0}'],
        ]),
        pw.SizedBox(height: 20),
        pw.Text('Generado por: $generadoPor - ${fechaCorta(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text(
            'Herramienta de apoyo; no reemplaza el diagnostico clinico. Los datos corresponden a codigos anonimos.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ],
    ));
    return doc.save();
  }
}
