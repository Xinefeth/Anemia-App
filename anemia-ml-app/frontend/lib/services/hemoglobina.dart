// Hemoglobina ajustada por altitud (OMS 2011) y umbral de anemia en menores de 5 años.
// Es solo un aviso informativo: la app valora riesgo, no diagnostica.

/// Umbral de anemia (g/dL) para niños de 6 a 59 meses, a nivel del mar.
const double umbralAnemia = 11.0;

// Ajuste a restar a la Hb medida, según altitud en metros (OMS 2011).
const List<(double, double)> _tabla = [
  (1000, 0.2),
  (1500, 0.5),
  (2000, 0.8),
  (2500, 1.3),
  (3000, 1.9),
  (3500, 2.7),
  (4000, 3.5),
  (4500, 4.5),
];

/// Ajuste (g/dL) para la altitud dada; interpola entre los puntos de la tabla.
double ajusteAltitud(double msnm) {
  if (msnm < 1000) return 0;
  if (msnm >= _tabla.last.$1) return _tabla.last.$2;
  for (var i = 0; i < _tabla.length - 1; i++) {
    final (a0, v0) = _tabla[i];
    final (a1, v1) = _tabla[i + 1];
    if (msnm >= a0 && msnm <= a1) {
      return v0 + (v1 - v0) * (msnm - a0) / (a1 - a0);
    }
  }
  return 0;
}

double hbAjustada(double hb, double altitud) => hb - ajusteAltitud(altitud);

/// true si la Hb medida, ajustada por altitud, está por debajo del umbral.
bool sugiereAnemia(double? hb, double altitud) =>
    hb != null && hbAjustada(hb, altitud) < umbralAnemia;
