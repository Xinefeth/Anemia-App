// Validaciones del cliente (RF12). Usan los MISMOS rangos que la API (models/dominio.dart):
// así se avisa antes de enviar, y el 422 del servidor queda solo como segunda barrera.
import '../models/dominio.dart';

String? vCodigo(String? v) {
  if (v == null || v.trim().isEmpty) return 'Ingresa el código del niño';
  if (!RegExp(r'^[A-Za-z0-9_\-]{1,30}$').hasMatch(v.trim())) {
    return 'Usa solo letras, números, guion y guion bajo (máx. 30)';
  }
  return null;
}

/// Edad en meses cumplidos: entero de 6 a 59 (la API rechaza decimales).
String? vEdad(String? v) {
  if (v == null || v.trim().isEmpty) return 'Ingresa la edad en meses';
  final n = int.tryParse(v.trim());
  if (n == null) return 'La edad debe ser un número entero de meses';
  if (n < Dominio.edadMin || n > Dominio.edadMax) {
    return 'La edad debe estar ${Dominio.textoEdad} (el modelo solo es válido en ese rango)';
  }
  return null;
}

/// Altitud del establecimiento: 0 a 700 msnm (solo Trujillo).
String? vAltitud(String? v) {
  if (v == null || v.trim().isEmpty) return 'Ingresa la altitud';
  final n = double.tryParse(v.trim().replaceAll(',', '.'));
  if (n == null) return 'La altitud no es un número válido';
  if (n < Dominio.altitudMin || n > Dominio.altitudMax) {
    return 'La altitud debe estar ${Dominio.textoAltitud}: el modelo solo es válido para establecimientos de Trujillo';
  }
  return null;
}
