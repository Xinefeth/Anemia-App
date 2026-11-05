// Validaciones compartidas (RF12). Reglas RN01 (menor de 5 años) y RN02 (hemoglobina en rango).
String? vCodigo(String? v) {
  if (v == null || v.trim().isEmpty) return 'Ingresa el código del niño';
  if (!RegExp(r'^[A-Za-z0-9_\-]{1,30}$').hasMatch(v.trim())) {
    return 'Usa solo letras, números, guion y guion bajo (máx. 30)';
  }
  return null;
}

String? vNumero(String? v, String campo, double min, double max,
    {String unidad = ''}) {
  if (v == null || v.trim().isEmpty) return 'Ingresa ${campo.toLowerCase()}';
  final n = double.tryParse(v.replaceAll(',', '.'));
  if (n == null) return '$campo no es un número válido';
  if (n < min || n > max) return '$campo debe estar entre $min y $max $unidad'.trim();
  return null;
}

String? vEdad(String? v) => vNumero(v, 'La edad', 0, 59, unidad: 'meses');
String? vHb(String? v) => vNumero(v, 'La hemoglobina', 3, 20, unidad: 'g/dL');
String? vAltitud(String? v) => vNumero(v, 'La altitud', 0, 5500, unidad: 'msnm');
