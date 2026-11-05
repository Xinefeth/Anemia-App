"""
Generador de un dataset SINTÉTICO para poder entrenar y probar el sistema.

IMPORTANTE: estos datos NO son reales. Sirven solo para desarrollo y pruebas.
Para la tesis hay que reemplazarlos por el dataset real (anonimizado) en
data/processed/dataset.csv, con las mismas columnas.

Columnas: edad_meses, hemoglobina, altitud, sexo (M/F), riesgo (Bajo/Medio/Alto)

Regla de etiquetado (referencia OMS/MINSA para 6-59 meses, simplificada):
  hemoglobina ajustada por altitud >= 11.0        -> Bajo
  10.0 <= hemoglobina ajustada < 11.0 (leve)      -> Medio
  hemoglobina ajustada < 10.0 (moderada/grave)    -> Alto
"""
import argparse
import os

import numpy as np
import pandas as pd

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RUTA_SALIDA = os.path.join(RAIZ, "data", "processed", "dataset.csv")


def ajuste_altitud(altitud_m):
    """Ajuste de hemoglobina (g/dL) por altitud; solo aplica desde 1000 msnm."""
    a = np.asarray(altitud_m, dtype=float) * 0.0033
    ajuste = -0.032 * a + 0.022 * a ** 2
    return np.where(np.asarray(altitud_m) >= 1000, ajuste, 0.0)


def generar(n=3000, semilla=42):
    rng = np.random.default_rng(semilla)
    edad = rng.integers(6, 60, n)
    sexo = rng.choice(["M", "F"], n)
    # ~70 % costa (Trujillo ~34 msnm) y ~30 % sierra
    altitud = np.where(rng.random(n) < 0.7,
                       rng.integers(0, 300, n),
                       rng.integers(1500, 4000, n))
    hb_ajustada = rng.normal(11.3, 1.5, n)
    hb_observada = np.clip(hb_ajustada + ajuste_altitud(altitud), 4.0, 18.0)
    # El etiquetado usa la hemoglobina ajustada con un pequeño error de medición
    hb_medida = hb_ajustada + rng.normal(0, 0.2, n)
    riesgo = np.where(hb_medida >= 11.0, "Bajo",
                      np.where(hb_medida >= 10.0, "Medio", "Alto"))
    return pd.DataFrame({
        "edad_meses": edad,
        "hemoglobina": hb_observada.round(1),
        "altitud": altitud,
        "sexo": sexo,
        "riesgo": riesgo,
    })


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    p.add_argument("--n", type=int, default=3000)
    p.add_argument("--salida", default=RUTA_SALIDA)
    args = p.parse_args()
    df = generar(args.n)
    os.makedirs(os.path.dirname(args.salida), exist_ok=True)
    df.to_csv(args.salida, index=False)
    print(f"Dataset sintético guardado en {args.salida}")
    print(df["riesgo"].value_counts())
