// Dominio de validez del modelo de ML. Debe coincidir con el contrato del backend
// (docs/API_CONTRATO.md, sección "Dominio de validez"): fuera de estos rangos la API
// responde 422 con type "fuera_de_dominio_modelo".
//
// RN01 (menores de 5 años, 0-59 meses) está pendiente de validar con el asesor; mientras
// tanto la edad mínima es 6 meses porque el modelo se entrenó con niños de 6 a 59 meses.
class Dominio {
  static const int edadMin = 6;
  static const int edadMax = 59;
  static const double altitudMin = 0;
  static const double altitudMax = 700; // msnm; solo establecimientos de Trujillo

  static const String textoEdad = 'entre $edadMin y $edadMax meses';
  static const String textoAltitud = 'entre 0 y 700 msnm';
}
