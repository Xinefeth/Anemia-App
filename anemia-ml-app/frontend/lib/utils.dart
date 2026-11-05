/// Utilidades de formato (sin depender de la configuración regional del equipo).
const _meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

String nombreMes(int mes) => _meses[mes - 1];

String _dos(int n) => n.toString().padLeft(2, '0');

/// "05 Nov, 09:12"
String fechaCorta(DateTime f) => '${_dos(f.day)} ${nombreMes(f.month)}, ${_dos(f.hour)}:${_dos(f.minute)}';

/// "Hoy, 09:12" / "Ayer, 16:20" / "05 Nov, 09:12"
String fechaRelativa(DateTime f, {DateTime? ahora}) {
  final hoy = ahora ?? DateTime.now();
  final d0 = DateTime(hoy.year, hoy.month, hoy.day);
  final d1 = DateTime(f.year, f.month, f.day);
  final hora = '${_dos(f.hour)}:${_dos(f.minute)}';
  return switch (d0.difference(d1).inDays) {
    0 => 'Hoy, $hora',
    1 => 'Ayer, $hora',
    _ => fechaCorta(f),
  };
}

/// "05/11/2026"
String fechaDia(DateTime f) => '${_dos(f.day)}/${_dos(f.month)}/${f.year}';

String saludo({DateTime? ahora}) {
  final h = (ahora ?? DateTime.now()).hour;
  return h < 12 ? 'Buenos días' : (h < 19 ? 'Buenas tardes' : 'Buenas noches');
}

String sexoTexto(String s) => s == 'F' ? 'Femenino' : 'Masculino';

/// Convierte "9,5" o "9.5" a número; null si no es válido.
double? parseDecimal(String s) => double.tryParse(s.trim().replaceAll(',', '.'));
